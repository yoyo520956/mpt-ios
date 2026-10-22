import Foundation

// 原版 app/models/schema.py 1:1 移植（枚举值、默认值、字段名全部对齐）

enum VideoConcatMode: String, Codable, CaseIterable { case random, sequential }
enum VideoTransitionMode: String, Codable, CaseIterable {
    case none, shuffle, fadeIn = "FadeIn", fadeOut = "FadeOut"
    case slideIn = "SlideIn", slideOut = "SlideOut", zoomIn = "ZoomIn", zoomOut = "ZoomOut"
}
enum VideoAspect: String, Codable, CaseIterable {
    case landscape = "16:9", portrait = "9:16", square = "1:1"
    var resolution: (Int, Int) {
        switch self {
        case .landscape: return (1920, 1080)
        case .portrait: return (1080, 1920)
        case .square: return (1080, 1080)
        }
    }
}
enum VideoFitMode: String, Codable, CaseIterable { case cover, contain }
enum ImageMotion: String, Codable, CaseIterable { case static, zoom }
enum SubtitleDisplayMode: String, Codable, CaseIterable { case sentence, wordByWord = "word_by_word" }
enum SubtitleAnimation: String, Codable, CaseIterable { case none, popSpring = "pop_spring" }

struct MaterialInfo: Codable, Identifiable, Hashable {
    var provider: String = "pexels"
    var url: String = ""
    var duration: Int = 0
    var id: String { provider + "|" + url }
}

/// 1:1 对应原版 VideoParams
struct VideoParams: Codable, Equatable {
    var videoSubject: String = ""
    var videoScript: String = ""
    var videoTerms: String = ""
    var videoAspect: VideoAspect = .portrait
    var videoFitMode: VideoFitMode = .cover
    var imageMotion: ImageMotion = .zoom
    var videoConcatMode: VideoConcatMode = .random
    var videoTransitionMode: VideoTransitionMode = .none
    var videoClipDuration: Int = 5
    var videoClipSpeed: Double = 1.0
    var matchMaterialsToScript: Bool = false
    var videoCount: Int = 1

    var videoSource: String = "pexels"
    var videoMaterials: [MaterialInfo] = []

    var customAudioFile: String = ""
    var videoLanguage: String = ""

    var voiceName: String = ""
    var voiceVolume: Double = 1.0
    var voiceRate: Double = 1.0
    var bgmType: String = "random"
    var bgmFile: String = ""
    var bgmVolume: Double = 0.2
    var videoMusicPrompt: String = ""
    var soniloBgmPrompt: String = ""

    var subtitleEnabled: Bool = true
    var subtitlePosition: String = "bottom"
    var subtitleDisplayMode: SubtitleDisplayMode = .sentence
    var subtitleAnimation: SubtitleAnimation = .none
    var customPosition: Double = 70.0
    var fontName: String = "STHeitiMedium.ttc"
    var textForeColor: String = "#FFFFFF"
    var textBackgroundColor: Bool = false
    var roundedSubtitleBackground: Bool = false

    var fontSize: Int = 60
    var strokeColor: String = "#000000"
    var strokeWidth: Double = 1.5
    var nThreads: Int = 2
    var paragraphNumber: Int = 1
    var videoScriptPrompt: String = ""
    var customSystemPrompt: String = ""
    // P1 界面所需（与原版 UI 选项 1:1）
    var videoCodec: String = "default"
    var voiceMode: String = "tts"
    var voiceProvider: String = "azure-tts-v1"
    var subtitleBackgroundEnabled: Bool = false
    var subtitleBackgroundColor: String = "#000000"

    enum CodingKeys: String, CodingKey {
        case videoSubject = "video_subject"
        case videoScript = "video_script"
        case videoTerms = "video_terms"
        case videoAspect = "video_aspect"
        case videoFitMode = "video_fit_mode"
        case imageMotion = "image_motion"
        case videoConcatMode = "video_concat_mode"
        case videoTransitionMode = "video_transition_mode"
        case videoClipDuration = "video_clip_duration"
        case videoClipSpeed = "video_clip_speed"
        case matchMaterialsToScript = "match_materials_to_script"
        case videoCount = "video_count"
        case videoSource = "video_source"
        case videoMaterials = "video_materials"
        case customAudioFile = "custom_audio_file"
        case videoLanguage = "video_language"
        case voiceName = "voice_name"
        case voiceVolume = "voice_volume"
        case voiceRate = "voice_rate"
        case bgmType = "bgm_type"
        case bgmFile = "bgm_file"
        case bgmVolume = "bgm_volume"
        case videoMusicPrompt = "video_music_prompt"
        case soniloBgmPrompt = "sonilo_bgm_prompt"
        case subtitleEnabled = "subtitle_enabled"
        case subtitlePosition = "subtitle_position"
        case subtitleDisplayMode = "subtitle_display_mode"
        case subtitleAnimation = "subtitle_animation"
        case customPosition = "custom_position"
        case fontName = "font_name"
        case textForeColor = "text_fore_color"
        case textBackgroundColor = "text_background_color"
        case roundedSubtitleBackground = "rounded_subtitle_background"
        case fontSize = "font_size"
        case strokeColor = "stroke_color"
        case strokeWidth = "stroke_width"
        case nThreads = "n_threads"
        case paragraphNumber = "paragraph_number"
        case videoScriptPrompt = "video_script_prompt"
        case customSystemPrompt = "custom_system_prompt"
    }
}

/// 原版 DEFAULT_SUBTITLE_SETTINGS（webui/Main.py）
struct SubtitleDefaults {
    static let enabled = true
    static let fontName = "MicrosoftYaHeiBold.ttc"
    static let position = "bottom"
    static let displayMode: SubtitleDisplayMode = .sentence
    static let animation: SubtitleAnimation = .none
    static let customPosition: Double = 70.0
    static let textColor = "#FFFFFF"
    static let fontSize = 60
    static let strokeColor = "#000000"
    static let strokeWidth: Double = 1.5
    static let backgroundEnabled = false
    static let backgroundColor = "#000000"
    static let roundedBackground = false
}
