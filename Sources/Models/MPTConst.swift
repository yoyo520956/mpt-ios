import Foundation

enum MPTConst {
    /// 原版版本号（app/__init__.py: __version__ = "1.3.9"）
    static let originalVersion = "1.3.9"

    // 任务状态（原版 app/models/const.py）
    static let taskFailed = -1
    static let taskComplete = 1
    static let taskProcessing = 4

    // 视频来源（原版 webui/Main.py video_source_labels）
    static let videoSources: [(String, String)] = [
        ("pexels", "Pexels"),
        ("pixabay", "Pixabay"),
        ("coverr", "Coverr"),
        ("wavespeed", "WaveSpeed AI Video"),
        ("volcengine_seedance", "Volcano Engine Seedance"),
        ("ofox", "OFox AI Video"),
        ("metaso_minimax", "Metaso MiniMax H3"),
        ("muapi", "MuAPI AI Video"),
        ("loomloom", "Shengsuan Cloud AI Video"),
        ("openai_image", "OpenAI Compatible Text-to-Image"),
        ("local", "Local file")
    ]
    static let stockVideoSources = ["pexels", "pixabay", "coverr"]
    static let aiVideoSources = ["wavespeed", "volcengine_seedance", "ofox", "metaso_minimax", "muapi", "loomloom"]
    static let aiImageSources = ["openai_image"]
    static let localSources = ["local"]

    // 视频拼接模式
    static let concatModes: [(String, String)] = [("sequential", "Sequential"), ("random", "Random")]

    // 视频转场模式（app/models/schema.py VideoTransitionMode）
    static let transitionModes: [(String, String)] = [
        ("none", "None"), ("shuffle", "Shuffle"), ("fade_in", "FadeIn"), ("fade_out", "FadeOut"),
        ("slide_in", "SlideIn"), ("slide_out", "SlideOut"), ("zoom_in", "ZoomIn"), ("zoom_out", "ZoomOut")
    ]

    // 配音方式（webui/Main.py 音频设置）
    static let voiceModes: [(String, String)] = [
        ("tts", "Auto Voice"), ("upload", "Upload Audio"), ("none", "No Voice")
    ]

    // 配音服务
    static let voiceProviders: [(String, String)] = [
        ("azure-tts-v1", "Azure TTS V1 (Edge TTS)"),
        ("elevenlabs", "ElevenLabs"),
        ("sonilo", "Sonilo"),
        ("loomloom", "Shengsuan Cloud"),
        ("ofox", "OFox"),
        ("siliconflow", "SiliconFlow"),
        ("minimax", "MiniMax")
    ]

    // 背景音乐来源
    static let bgmTypes: [(String, String)] = [
        ("random", "Random BGM"), ("custom", "Custom BGM"), ("none", "No BGM")
    ]

    // 字幕字体（resource/fonts）
    static let fontNames = [
        "MicrosoftYaHeiBold.ttc", "MicrosoftYaHeiNormal.ttc",
        "STHeitiLight.ttc", "STHeitiMedium.ttc",
        "Charm-Bold.ttf", "Charm-Regular.ttf",
        "BeVietnamPro-Bold.ttf", "BeVietnamPro-Medium.ttf", "UTM Kabel KT.ttf"
    ]

    // 脚本语言
    static let scriptLanguages: [(String, String)] = [
        ("", "Auto Detect"), ("zh", "Chinese"), ("en", "English"), ("ja", "Japanese"),
        ("ko", "Korean"), ("fr", "French"), ("de", "German"), ("es", "Spanish"),
        ("pt", "Portuguese"), ("ru", "Russian"), ("it", "Italian"), ("tr", "Turkish"),
        ("vi", "Vietnamese"), ("id", "Indonesian"), ("ca", "Catalan"), ("az", "Azerbaijani")
    ]

    // 界面语言（原版 webui/i18n 14 语言 + 自动检测）
    static let uiLanguages: [(String, String)] = [
        ("zh", "简体中文"), ("en", "English"), ("de", "Deutsch"), ("es", "Español"),
        ("fr", "Français"), ("it", "Italiano"), ("pt", "Português"), ("ru", "Русский"),
        ("tr", "Türkçe"), ("vi", "Tiếng Việt"), ("id", "Bahasa Indonesia"),
        ("ko", "한국어"), ("ca", "Català"), ("az", "Azərbaycan")
    ]
}
