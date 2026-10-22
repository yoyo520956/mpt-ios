import SwiftUI

/// 原版 WebUI 视觉 token（1:1 取自 webui/styles.css + docs/webui.jpg 实测配色）
enum MPTStyle {
    // 主色
    static let primary = Color(hex: "#FF4B4B")       // 生成视频按钮 / 强调红
    static let brand = Color(hex: "#0068C9")          // styles.css 主色
    static let danger = Color(hex: "#D94848")         // styles.css 危险色
    static let accent = Color(hex: "#FF6B6B")         // styles.css 次强调

    // 表面
    static let pageBackground = Color(hex: "#FFFFFF")
    static let cardBackground = Color(hex: "#F9FAFB")
    static let controlBackground = Color(hex: "#F3F4F6")
    static let selectedBackground = Color(hex: "#FFE0E0")
    static let border = Color(hex: "#E5E7EB")
    static let divider = Color(hex: "#D8D8D8")

    // 文字
    static let textPrimary = Color(hex: "#111827")
    static let textSecondary = Color(hex: "#6B7280")
    static let textTertiary = Color(hex: "#9CA3AF")

    // 圆角（iOS 圆角阶梯）
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16

    // 间距（4pt 网格）
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s8: CGFloat = 32

    // 字号
    static func title(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .bold) }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .regular) }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
            a = 1
        } else {
            r = Double((v & 0xFF000000) >> 24) / 255
            g = Double((v & 0x00FF0000) >> 16) / 255
            b = Double((v & 0x0000FF00) >> 8) / 255
            a = Double(v & 0x000000FF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
