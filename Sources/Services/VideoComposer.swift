import Foundation
import CoreImage
import UIKit
import SwiftUI

/// 合成调度（Swift 薄封装）：
/// - 字幕 PNG 由 Swift/UIKit 绘制（整幅透明画布，位置/字号/描边/背景 1:1 对应原版参数）
/// - 拼接 / 转场 / 字幕烧录 / BGM 混音 / 画幅 / 导出 由 ObjC 桥完成（Sources/Bridge/MPTComposer.m）
final class VideoComposer {
    struct Result {
        let url: URL
        var note: String = ""
    }

    func compose(clips: [URL], subtitles: [String], narration: URL?, bgm: URL?,
                 params: VideoParams, outURL: URL, onProgress: @escaping (Double) -> Void) async -> Result {
        let (W, H) = params.videoAspect.resolution
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mpt_subs", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        var images: [Any] = []
        for (i, _) in clips.enumerated() {
            let text = i < subtitles.count ? subtitles[i] : ""
            var item: Any = NSNull()
            if params.subtitleEnabled, !text.isEmpty,
               let url = Self.subtitlePNGURL(text: text, width: W, height: H,
                                             fontSize: params.fontSize,
                                             color: Self.hexColor(params.textForeColor, .white),
                                             strokeColor: Self.hexColor(params.strokeColor, .black),
                                             strokeWidth: params.strokeWidth,
                                             bgEnabled: params.textBackgroundColor,
                                             bgColor: Self.hexColor(params.subtitleBackgroundColor, .black),
                                             rounded: params.roundedSubtitleBackground,
                                             position: params.subtitlePosition,
                                             customPos: params.customPosition,
                                             dir: tmpDir) {
                item = url
            }
            images.append(item)
        }

        let config: [String: Any] = [
            "width": W,
            "height": H,
            "clipDuration": params.videoClipDuration,
            "fitCover": params.videoFitMode == .cover,
            "transition": params.videoTransitionMode.rawValue,
            "voiceVolume": params.voiceVolume,
            "bgmVolume": params.bgmVolume
        ]

        let err: Error? = await withCheckedContinuation { (cont: CheckedContinuation<Error?, Never>) in
            MPTComposer.composeClips(clips, subtitles: images, narration: narration, bgm: bgm,
                                     config: config, outURL: outURL,
                                     progress: { p in onProgress(min(max(p, 0), 1)) },
                                     completion: { e in cont.resume(returning: e) })
        }

        var res = Result(url: outURL)
        if let err {
            try? FileManager.default.removeItem(at: outURL)
            res.note = "合成失败：" + err.localizedDescription
        } else {
            res.note = "已导出"
        }
        onProgress(1.0)
        return res
    }

    // MARK: - 颜色 / 字幕绘制

    static func hexColor(_ s: String, _ fallback: UIColor) -> UIColor {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard t.hasPrefix("#") else { return fallback }
        t.removeFirst()
        if t.count == 3 { t = t.map { "\($0)\($0)" }.joined() }
        guard t.count == 6, let v = UInt64(t, 16) else { return fallback }
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255.0,
                       green: CGFloat((v >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(v & 0xFF) / 255.0, alpha: 1)
    }

    static func subtitlePNGURL(text: String, width: Int, height: Int, fontSize: Int,
                               color: UIColor, strokeColor: UIColor, strokeWidth: Double,
                               bgEnabled: Bool, bgColor: UIColor, rounded: Bool,
                               position: String, customPos: Double, dir: URL) -> URL? {
        let size = CGSize(width: width, height: height)
        let pt = CGFloat(max(fontSize, 12))
        let font = UIFont(name: "Charm-Bold", size: pt)
            ?? UIFont(name: "Charm-Regular", size: pt)
            ?? UIFont.systemFont(ofSize: pt, weight: .bold)
        let maxW = CGFloat(width) * 0.9
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
        let top: CGFloat
        switch position {
        case "top": top = CGFloat(height) * 0.08
        case "two_thirds_bottom": top = CGFloat(height) * 0.42
        case "custom": top = CGFloat(height) * 0.05
            + CGFloat(height) * 0.9 * CGFloat(min(max(customPos, 0), 100) / 100.0)
        default: top = CGFloat(height) * 0.84 - blockH
        }

        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let g = ctx.cgContext
            g.clear(CGRect(origin: .zero, size: size))
            for (i, ln) in lines.enumerated() {
                let y = top + CGFloat(i) * lh
                if bgEnabled {
                    let tw = CGFloat((ln as NSString).size(withAttributes: [.font: font]).width)
                    let pad: CGFloat = 14
                    let box = CGRect(x: (CGFloat(width) - tw) / 2 - pad, y: y - pad * 0.6,
                                     width: tw + pad * 2, height: pt + pad * 1.2)
                    g.setFillColor(bgColor.withAlphaComponent(0.72).cgColor)
                    if rounded {
                        g.addPath(UIBezierPath(roundedRect: box, cornerRadius: 10).cgPath)
                        g.fillPath()
                    } else {
                        g.fill(box)
                    }
                }
                let w = CGFloat((ln as NSString).size(withAttributes: [.font: font]).width)
                let cx = (CGFloat(width) - w) / 2
                let sw = CGFloat(max(strokeWidth, 0))
                if sw > 0 {
                    let attrs: [NSAttributedString.Key: Any] = [.font: font,
                                                                .strokeWidth: -sw * 2,
                                                                .strokeColor: strokeColor]
                    (ln as NSString).draw(at: CGPoint(x: cx, y: y), withAttributes: attrs)
                }
                (ln as NSString).draw(at: CGPoint(x: cx, y: y),
                                      withAttributes: [.font: font, .foregroundColor: color])
            }
        }
        guard let d = img.pngData() else { return nil }
        let url = dir.appendingPathComponent("sub-\(UUID().uuidString.prefix(8)).png")
        try? d.write(to: url)
        return url
    }
}

// MARK: - 静音音频（手写 WAV，避免依赖 AVAudioFile）

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
