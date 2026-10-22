import Foundation
import SwiftUI

/// SwiftUI Picker 需要的原始值绑定（枚举 ↔ String）
extension VideoParams {
    var videoAspectRaw: String {
        get { videoAspect.rawValue }
        set { videoAspect = VideoAspect(rawValue: newValue) ?? .portrait }
    }
    var videoConcatModeRaw: String {
        get { videoConcatMode.rawValue }
        set { videoConcatMode = VideoConcatMode(rawValue: newValue) ?? .random }
    }
    var videoTransitionModeRaw: String {
        get { videoTransitionMode.rawValue }
        set { videoTransitionMode = VideoTransitionMode(rawValue: newValue) ?? .none }
    }
    var videoClipDurationRaw: String {
        get { String(videoClipDuration) }
        set { videoClipDuration = max(1, Int(newValue) ?? 5) }
    }
    var videoCountRaw: String {
        get { String(videoCount) }
        set { videoCount = max(1, Int(newValue) ?? 1) }
    }
    var fontSizeDouble: Double {
        get { Double(fontSize) }
        set { fontSize = max(1, Int(newValue)) }
    }
    var paragraphNumberRaw: String {
        get { String(paragraphNumber) }
        set { paragraphNumber = max(1, min(10, Int(newValue) ?? 1)) }
    }
}

extension ConfigStore {
    /// 恢复默认字幕设置（对应原版"恢复默认字幕设置"按钮）
    func resetSubtitle() {
        params.subtitleEnabled = SubtitleDefaults.enabled
        params.fontName = SubtitleDefaults.fontName
        params.subtitlePosition = SubtitleDefaults.position
        params.subtitleDisplayMode = SubtitleDefaults.displayMode
        params.subtitleAnimation = SubtitleDefaults.animation
        params.customPosition = SubtitleDefaults.customPosition
        params.textForeColor = SubtitleDefaults.textColor
        params.fontSize = SubtitleDefaults.fontSize
        params.strokeColor = SubtitleDefaults.strokeColor
        params.strokeWidth = SubtitleDefaults.strokeWidth
        params.subtitleBackgroundEnabled = SubtitleDefaults.backgroundEnabled
        params.subtitleBackgroundColor = SubtitleDefaults.backgroundColor
        params.roundedSubtitleBackground = SubtitleDefaults.roundedBackground
    }
}
