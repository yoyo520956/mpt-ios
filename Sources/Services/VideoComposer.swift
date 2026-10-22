import Foundation
import AVFoundation
import CoreImage
import UIKit

/// AVFoundation 合成引擎（对应原版 services/video.py 的 ffmpeg 流水线：
/// 拼接/转场/字幕烧录/BGM 混音/画幅缩放；转场降级与编码器统一在 note 里注明）
final class VideoComposer {
    struct Result {
        let url: URL
        var note: String = ""
    }

    func compose(clips: [URL], subtitles: [String], narration: URL?, bgm: URL?,
                 params: VideoParams, outURL: URL, onProgress: @escaping (Int) -> Void) async throws -> Result {
        guard !clips.isEmpty else { throw MPTError.decode("没有可用素材") }
        let outW = CGFloat(params.videoAspect.resolution.0)
        let outH = CGFloat(params.videoAspect.resolution.1)
        let cover = params.videoFitMode == .cover

        let comp = AVMutableComposition()
        let videoComp = comp.videoTracks.first!
        var instrs: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero
        var notes: [String] = []

        for (i, url) in clips.enumerated() {
            let asset = AVURLAsset(url: url)
            guard let srcTrack = asset.tracks(withMediaType: .video).first else { continue }
            let assetDur = try await asset.load(.duration)
            let srcSize = (try? await asset.load(.naturalSize)) ?? CGSize(width: outW, height: outH)
            let maxDur = CMTime(seconds: Double(params.videoClipDuration), preferredTimescale: 1_000_000)
            let dur = assetDur < maxDur ? assetDur : maxDur
            guard dur > CMTime(value: 1, timescale: 1_000_000) else {
                MPTLog.error("片段过短跳过 \(url.lastPathComponent)")
                continue
            }
            let cTrack = comp.addMutableTrack(withMediaType: .video, from: asset, at: .zero)
            try cTrack.insertTimeRange(CMTimeRange(start: .zero, end: dur), into: videoComp, at: cursor)
            let t0 = cursor
            let t1 = cursor + dur
            cursor = t1

            // 画幅 fit（cover/contain）
            let scale: CGFloat = cover ? max(outW / srcSize.width, outH / srcSize.height)
                                       : min(outW / srcSize.width, outH / srcSize.height)
            let tx = (outW - srcSize.width * scale) / 2
            let ty = (outH - srcSize.height * scale) / 2

            // 转场（1:1 原版 VideoTransitionMode；fade 系列降级硬切）
            var s0 = scale
            var e0 = scale
            var x0 = tx
            var x1 = tx
            switch params.videoTransitionMode {
            case .none, .shuffle:
                if params.videoTransitionMode == .shuffle { notes.append("Shuffle 已用随机片段顺序实现") }
            case .zoomIn: s0 *= 0.88
            case .zoomOut: e0 *= 1.12
            case .slideIn: x0 = tx - outW
            case .slideOut: x1 = tx + outW
            case .fadeIn, .fadeOut:
                notes.append("转场 \(params.videoTransitionMode.rawValue) 降级为硬切")
            }

            let li = AVVideoCompositionLayerInstruction(assetTrack: cTrack)
            let f0 = CGAffineTransform(translationX: x0, y: ty).scaledBy(x: s0, y: s0)
            let f1 = CGAffineTransform(translationX: x1, y: ty).scaledBy(x: e0, y: e0)
            li.setTransform(f0, at: t0)
            if s0 != e0 || x0 != x1 { li.setTransform(f1, at: t1) }

            let instr = AVMutableVideoCompositionInstruction(timeRange: CMTimeRange(start: t0, end: t1))
            instr.videoLayerInstructions = [li]

            // 字幕烧录：整幅画布 PNG + CIComposite
            if params.subtitleEnabled, i < subtitles.count, !subtitles[i].isEmpty,
               let png = Self.subtitlePNG(text: subtitles[i], width: outW, height: outH, params: params),
               let textImg = CIImage(contentsOf: png) {
                let cf = CIFilter(name: "CIComposite")!
                cf.setValue("videoLayer", forKey: kCIInputImageKey)
                cf.setValue(textImg, forKey: kCIInputCompositeImageKey)
                cf.setValue(CMTimeRange(start: t0, end: t1), forKey: kCIImageTimeRenderingKey)
                instr.filters = [cf]
            }
            instrs.append(instr)
            onProgress(Int(Double(i + 1) / Double(clips.count) * 10.0))
        }
        guard instrs.count > 0, cursor > CMTime.zero else { throw MPTError.decode("素材均不可用") }

        // 视频合成描述
        let vc = AVMutableVideoComposition()
        vc.instructions = instrs
        vc.renderSize = CGSize(width: outW, height: outH)
        vc.frameDuration = CMTime(value: 1, timescale: 30)
        if params.videoCodec == "libx264" { notes.append("编码器统一 h264/aac（ffmpeg libx264 参数 P4 对齐）") }

        // 音轨：配音 + BGM 循环
        let totalDur = cursor
        var audioInputs: [AVMutableAudioMixInputTrack] = []
        if let narration {
            let nAsset = AVURLAsset(url: narration)
            if let nSrc = nAsset.tracks(withMediaType: .audio).first {
                let nDur = try await nAsset.load(.duration)
                let nComp = comp.addMutableTrack(withMediaType: .audio, from: nAsset, at: .zero)
                let end = nDur < totalDur ? nDur : totalDur
                try nComp.insertTimeRange(CMTimeRange(start: .zero, end: end), into: nComp, at: .zero)
                let inp = AVMutableAudioMixInputTrack(track: nComp)
                inp.volume = Float(params.voiceVolume)
                audioInputs.append(inp)
            }
        }
        if let bgm {
            let bAsset = AVURLAsset(url: bgm)
            if let bSrc = bAsset.tracks(withMediaType: .audio).first {
                let bDur = try await bAsset.load(.duration)
                let bComp = comp.addMutableTrack(withMediaType: .audio, from: bAsset, at: .zero)
                var pos = CMTime.zero
                while pos < totalDur {
                    let seg = bDur < (totalDur - pos) ? bDur : (totalDur - pos)
                    try bComp.insertTimeRange(CMTimeRange(start: .zero, end: seg), into: bComp, at: pos)
                    pos = pos + seg
                }
                let inp = AVMutableAudioMixInputTrack(track: bComp)
                inp.volume = Float(params.bgmVolume)
                audioInputs.append(inp)
            } else {
                notes.append("BGM 无音轨，已忽略")
            }
        }
        if !audioInputs.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputs = audioInputs
            comp.audioMix = mix
            vc.hasAudio = true
        }

        // 导出 MP4
        let session = try AVAssetExportSession(asset: comp, outputFileType: .mp4)
        session.videoComposition = vc
        session.outputURL = outURL
        session.outputPreset = AVAssetExportPresetHighestQuality
        session.outputSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(outW),
            AVVideoHeightKey: Int(outH),
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1
        ]
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.startExportingAsynchronously(withProgressHandler: { p in
                onProgress(10 + Int(min(1.0, p) * 89))
            }, completionHandler: { _ in
                cont.resume()
            })
        }
        if let e = session.error {
            try? FileManager.default.removeItem(at: outURL)
            throw MPTError.network("视频合成失败：\(e.localizedDescription)")
        }
        var res = Result(url: outURL)
        res.note = notes.joined(separator: "；")
        return res
    }

    // MARK: - 字幕 PNG（整幅画布绘制，位置/字号/描边/背景 1:1 对应原版字幕参数）

    static func subtitlePNG(text: String, width: CGFloat, height: CGFloat, params: VideoParams) -> URL? {
        let pt = CGFloat(params.fontSize)
        let font = UIFont(name: params.fontName, size: pt) ?? .systemFont(ofSize: pt, weight: .bold)
        let fg = Color(hex: params.textForeColor)
        let strokeC = Color(hex: params.strokeColor)
        let bgC = Color(hex: params.subtitleBackgroundColor)

        let lines = wrap(text: text, font: font, maxWidth: width * 0.86)
        let lineH = pt * 1.35
        let top: CGFloat
        switch params.subtitlePosition {
        case "top": top = height * 0.06
        case "center": top = height * 0.44
        case "two_thirds_bottom": top = height * 0.62
        case "custom": top = height * 0.9 * params.customPosition / 100.0
        default: top = height * 0.72
        }

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: fmt)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            if params.subtitleBackgroundEnabled {
                cg.setFillColor(bgC.cgColor)
                let pad = pt * 0.4
                let bx = (width - width * 0.86) / 2 - pad
                let by = top - pad
                let bw = width * 0.86 + pad * 2
                let bh = lineH * CGFloat(lines.count) + pad * 2
                if params.roundedSubtitleBackground {
                    let p = UIBezierPath(roundedRect: CGRect(x: bx, y: by, width: bw, height: bh), cornerRadius: pad)
                    cg.addPath(p.cgPath)
                    cg.fillPath()
                } else {
                    cg.fill(CGRect(x: bx, y: by, width: bw, height: bh))
                }
            }
            // 描边（8 向偏移近似 ffmpeg -borderwidth）
            let step = max(1.0, CGFloat(params.strokeWidth) * 6.0)
            for dy in [-1, 0, 1] {
                for dx in [-1, 0, 1] where (dx != 0 || dy != 0) {
                    drawLines(lines, cg: cg, top: top + CGFloat(dy) * step,
                              xOffset: CGFloat(dx) * step, font: font,
                              color: strokeC.cgColor, cx: cg.width)
                }
            }
            drawLines(lines, cg: cg, top: top, xOffset: 0, font: font,
                      color: fg.cgColor, cx: cg.width)
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sub-\(UUID().uuidString).png")
        guard let data = img.pngData() else { return nil }
        try? data.write(to: url)
        return url
    }

    private static func wrap(text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
        var lines: [String] = []
        var cur = ""
        for ch in text {
            if ch == "\n" { lines.append(cur); cur = ""; continue }
            let test = cur + String(ch)
            if test.size(withAttributes: [.font: font]).width > maxWidth && !cur.isEmpty {
                lines.append(cur)
                cur = String(ch)
            } else {
                cur = test
            }
        }
        if !cur.isEmpty { lines.append(cur) }
        return lines
    }

    private static func drawLines(_ lines: [String], cg: CGContext, top: CGFloat,
                                  xOffset: CGFloat, font: UIFont, color: CGColor, cx: CGFloat) {
        let lineH = font.pointSize * 1.35
        for (i, ln) in lines.enumerated() {
            let s = NSAttributedString(string: ln, attributes: [.font: font, .foregroundColor: color])
            let w = s.size().width
            s.draw(at: CGPoint(x: (cx - w) / 2 + xOffset, y: top + CGFloat(i) * lineH))
        }
    }
}
