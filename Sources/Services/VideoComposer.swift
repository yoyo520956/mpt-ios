import Foundation
import AVFoundation
import CoreImage
import UIKit
import SwiftUI

/// AVFoundation 合成器：片段拼接 + 转场 + 字幕烧录 + BGM 混音 + 导出（对应原版 video_composer.py / concat.py）
/// 说明：videoTracks / audioMix / instructions / filters 等新 SDK 只走协议，这里统一用 KVC 读写保证编译兼容。
final class VideoComposer {
    struct Result {
        let url: URL
        var note: String = ""
    }

    private static let ts: Int32 = 600
    private static var zero: CMTime { CMTime(value: 0, timescale: ts) }
    private static func t(_ s: Double) -> CMTime { CMTime(value: Int32(s * Double(ts)), timescale: ts) }
    private static func range(_ a: CMTime, _ b: CMTime) -> CMTimeRange { CMTimeRange(start: a, end: b) }

    func compose(clips: [URL], subtitles: [String], narration: URL?, bgm: URL?,
                 params: VideoParams, outURL: URL, onProgress: @escaping (Double) -> Void) async -> Result {
        let z = VideoComposer.zero
        let (W, H) = params.videoAspect.resolution
        let outW = Double(W), outH = Double(H)
        let cover = params.videoFitMode == .cover
        let comp = AVMutableComposition()

        var instrs: [AVMutableVideoCompositionInstruction] = []
        var cursor: Double = 0

        for (i, url) in clips.enumerated() {
            let asset = AVURLAsset(url: url)
            guard let src = asset.tracks(withMediaType: AVMediaType.video).first else { continue }
            let n = src.duration.seconds
            let dur = min(max(n - 0.4, 0.8), Double(params.videoClipDuration))
            guard dur > 0 else { continue }

            guard let ot = comp.addMutableTrack(withMediaType: AVMediaType.video, from: asset, at: z),
                  try? ot.insertTimeRange(VideoComposer.range(z, dur), into: ot, at: z) != nil else { continue }

            let size = src.naturalSize
            let s = cover
                ? max(outW / size.width, outH / size.height)
                : min(outW / size.width, outH / size.height)
            let scale = (cover ? 1.1 : 1.0) * s

            let li = AVVideoCompositionLayerInstruction(assetTrack: ot)
            switch params.videoTransitionMode {
            case .slideIn:
                li.setTransform(CGAffineTransform(translationX: -size.width * scale, y: 0), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor + 0.6))
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor + dur))
            case .slideOut:
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(translationX: size.width * scale, y: 0), at: VideoComposer.t(cursor + dur))
            case .zoomIn:
                li.setTransform(CGAffineTransform(scaleX: scale * 0.8, y: scale * 0.8), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor + dur))
            case .zoomOut:
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(scaleX: scale * 0.8, y: scale * 0.8), at: VideoComposer.t(cursor + dur))
            case .fadeIn, .shuffle:
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor + dur))
            case .fadeOut:
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor))
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor + dur))
            case .none:
                li.setTransform(CGAffineTransform(scaleX: scale, y: scale), at: VideoComposer.t(cursor))
            }

            var filters: [CIFilter] = []
            if params.subtitleEnabled, i < subtitles.count, !subtitles[i].isEmpty {
                if let img = VideoComposer.subtitlePNG(text: subtitles[i],
                                                       width: W, height: H,
                                                       fontSize: params.fontSize,
                                                       color: VideoComposer.hexColor(params.textForeColor, .white),
                                                       strokeColor: VideoComposer.hexColor(params.strokeColor, .black),
                                                       strokeWidth: params.strokeWidth,
                                                       bgEnabled: params.textBackgroundColor,
                                                       bgColor: VideoComposer.hexColor(params.subtitleBackgroundColor, .black),
                                                       rounded: params.roundedSubtitleBackground,
                                                       position: params.subtitlePosition,
                                                       customPos: params.customPosition) {
                    let cf = CIFilter(name: "CIComposite")!
                    cf.setValue("videoLayer", forKey: kCIInputImageKey)
                    cf.setValue(img, forKey: "inCompositeImage")
                    cf.setValue(VideoComposer.range(VideoComposer.t(cursor), VideoComposer.t(cursor + dur)),
                                forKey: "inputTime")
                    filters.append(cf)
                }
            }

            let instr = AVMutableVideoCompositionInstruction()
            instr.setValue(VideoComposer.range(VideoComposer.t(cursor), VideoComposer.t(cursor + dur)),
                           forKey: "timeRange")
            instr.setValue([li] as NSArray, forKey: "videoLayerInstructions")
            if !filters.isEmpty { instr.setValue(filters as NSArray, forKey: "filters") }
            instrs.append(instr)

            cursor += dur
            onProgress(Double(i + 1) / Double(max(clips.count, 1)) * 0.4)
        }

        var audioInputs: [AVMutableAudioMixInputTrack] = []
        let total = cursor
        if let narration {
            let na = AVURLAsset(url: narration)
            if let ns = na.tracks(withMediaType: AVMediaType.audio).first,
               let nTr = comp.addMutableTrack(withMediaType: AVMediaType.audio, from: na, at: z),
               ns.duration.seconds > 0 {
                let len = min(ns.duration, VideoComposer.t(total))
                if (try? nTr.insertTimeRange(VideoComposer.range(z, len), into: nTr, at: z)) != nil {
                    let inp = AVMutableAudioMixInputTrack(track: nTr)
                    inp.volume = Float(max(params.voiceVolume, 0))
                    audioInputs.append(inp)
                }
            }
        }
        if let bgm {
            let ba = AVURLAsset(url: bgm)
            if let bs = ba.tracks(withMediaType: AVMediaType.audio).first,
               let bTr = comp.addMutableTrack(withMediaType: AVMediaType.audio, from: ba, at: z),
               bs.duration.seconds > 0, total > 0 {
                var off = z
                let seg = bs.duration.seconds
                while off.seconds < total {
                    let d = min(seg, total - off.seconds)
                    if (try? bTr.insertTimeRange(VideoComposer.range(off, VideoComposer.t(d)), into: bTr, at: off)) == nil {
                        break
                    }
                    off = VideoComposer.t(off.seconds + d)
                }
                let inp = AVMutableAudioMixInputTrack(track: bTr)
                inp.volume = Float(min(max(params.bgmVolume, 0), 1))
                audioInputs.append(inp)
            }
        }

        var note = ""
        if audioInputs.isEmpty { note = "无音轨" }

        let vc = AVMutableVideoComposition()
        vc.setValue(instrs as NSArray, forKey: "instructions")
        vc.setValue(CGSize(width: W, height: H), forKey: "renderSize")
        vc.setValue(CMTime(value: 1, timescale: 30), forKey: "frameDuration")
        vc.setValue(NSNumber(value: !audioInputs.isEmpty), forKey: "hasAudio")
        let mix = AVMutableAudioMix()
        mix.setValue(audioInputs as NSArray, forKey: "inputs")
        comp.setValue(mix, forKey: "audioMix")

        var result = Result(url: outURL)
        if instrs.isEmpty {
            result.note = "素材不可用"
            return result
        }

        do {
            let session = try AVAssetExportSession(asset: comp, outputFileType: AVFileType.mp4)
            session.videoComposition = vc
            session.outputURL = outURL
            session.outputPreset = AVAssetExportPresetHighestQuality
            session.outputSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: W,
                AVVideoHeightKey: H,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000],
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
            if FileManager.default.fileExists(atPath: outURL.path) {
                try? FileManager.default.removeItem(at: outURL)
            }
            let done = await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                session.startExportingAsynchronously(withProgressHandler: { p in
                    onProgress(0.4 + min(p, 1.0) * 0.55)
                }, completionHandler: { _ in
                    cont.resume()
                })
            }
            _ = done
            let sz = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
            if FileManager.default.fileExists(atPath: outURL.path), sz > 100 {
                result.note = "已导出 \(Int(cursor))s · \(instrs.count) 片段"
                if !note.isEmpty { result.note += " · " + note }
            } else {
                result.note = "导出失败：\(session.error?.localizedDescription ?? "无输出")"
            }
        } catch {
            result.note = "合成失败：\(error.localizedDescription)"
        }
        onProgress(1.0)
        return result
    }
}


// MARK: - 字幕绘制 / 颜色

extension VideoComposer {
    static func hexColor(_ s: String, _ fallback: UIColor) -> UIColor {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard t.hasPrefix("#") else { return fallback }
        t.removeFirst()
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        guard t.count == 6, let v = UInt64(t,16) else { return fallback }
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255.0,
                       green: CGFloat((v >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(v & 0xFF) / 255.0, alpha: 1)
    }

    /// 生成整幅透明画布字幕 PNG（对应原版 draw_subtitle 的 drawtext 参数）
    static func subtitlePNG(text: String, width: Int, height: Int, fontSize: Int,
                            color: UIColor, strokeColor: UIColor, strokeWidth: Double,
                            bgEnabled: Bool, bgColor: UIColor, rounded: Bool,
                            position: String, customPos: Double) -> CIImage? {
        let size = CGSize(width: width, height: height)
        let pt = CGFloat(max(fontSize, 12))
        let font = UIFont(name: "Charm-Bold", size: pt)
            ?? UIFont(name: "Charm-Regular", size: pt)
            ?? UIFont(name: "STHeiti", size: pt)
            ?? UIFont.systemFont(ofSize: pt, weight: .bold)
        let maxW = width * 0.9
        let paras = text.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var lines: [String] = []
        for para in paras {
            if para.isEmpty { lines.append(""); continue }
            var cur = ""
            for ch in para {
                let cand = cur + ch
                if CGFloat((cand as NSString).size(withAttributes: [.font: font]).width) > maxW, !cur.isEmpty {
                    lines.append(cur); cur = String(ch)
                } else { cur = cand }
            }
            lines.append(cur)
        }
        let lh = pt * 1.4
        let blockH = lh * CGFloat(max(lines.count, 1))
        let yTop: CGFloat
        switch position {
        case "top": yTop = height * 0.08
        case "two_thirds_bottom": yTop = height * 0.42
        case "custom": yTop = height * 0.05 + (height * 0.9) * (min(max(customPos, 0), 100) / 100.0)
        default: yTop = height * 0.84 - blockH
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            g.setFillColor(UIColor.clear.cgColor)
            g.fill(CGRect(origin: .zero, size: size))
            for (i, ln) in lines.enumerated() {
                let y = yTop + CGFloat(i) * lh
                if bgEnabled {
                    let attr: [NSAttributedString.Key: Any] = [.font: font]
                    let tw = CGFloat((ln as NSString).size(withAttributes: attr).width)
                    let pad: CGFloat = 14
                    let box = CGRect(x: (CGFloat(width) - tw) / 2 - pad, y: y - pad * 0.6,
                                     width: tw + pad * 2, height: pt + pad * 1.2)
                    g.setFillColor(bgColor.withAlphaComponent(0.72).cgColor)
                    if rounded {
                        let p = UIBezierPath(roundedRect: box, cornerRadius: 10)
                        g.addPath(p.cgPath); g.fillPath()
                    } else { g.fill(box) }
                }
                let a: [NSAttributedString.Key: Any] = [.font: font]
                let w = CGFloat((ln as NSString).size(withAttributes: a).width)
                let cx = (CGFloat(width) - w) / 2
                let sw = CGFloat(max(strokeWidth, 0))
                if sw > 0 {
                    let swF: [NSAttributedString.Key: Any] = [.font: font, .strokeWidth: -sw * 2, .strokeColor: strokeColor]
                    (ln as NSString).draw(at: CGPoint(x: cx, y: y), withAttributes: swF)
                }
                (ln as NSString).draw(at: CGPoint(x: cx, y: y), withAttributes: [.font: font, .foregroundColor: color])
            }
        }
        guard let d = img.pngData() else { return nil }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mpt_sub_\(UUID().uuidString).png")
        try? d.write(to: tmp)
        return try? CIImage(contentsOf: tmp)
    }
}

// MARK: - 静音音频（手写 WAV，避免依赖 AVAudioFile / AVFrameCount）

enum MPTAudioUtil {
    static func silentWAV(dir: URL, seconds: Double, rate: Int = 44100) -> URL {
        let url = dir.appendingPathComponent("mpt_silent_\(Int(seconds)).wav")
        let n = Int(max(0.2, seconds) * Double(rate))
        var w = Data()
        func u16(_ v: UInt16) { var b = v.littleEndian; withUnsafeMutableBytes(of: &b) { w.append(contentsOf: $0) } }
        func u32(_ v: UInt32) { var b = v.littleEndian; withUnsafeMutableBytes(of: &b) { w.append(contentsOf: $0) } }
        w.append(contentsOf: Array("RIFF".utf8))
        u32(UInt32(36 + n * 2))
        w.append(contentsOf: Array("WAVE".utf8))
        w.append(contentsOf: Array("fmt ".utf8))
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        w.append(contentsOf: Array("data".utf8))
        u32(UInt32(n * 2))
        w.append(Data(count: n * 2))
        try? w.write(to: url)
        return url
    }
}
