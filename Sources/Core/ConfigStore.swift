import Foundation

/// Global config singleton: LLM Base URL / API Key / Video Params / UI State
/// Persisted to UserDefaults; sensitive Keys go to KeychainStore
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    // MARK: - Built-in Agnes 2.0 API
    static let defaultLLMBaseURL = "https://api.agnes-ai.cn"
    static let defaultLLMAPIKey = "c2stWGFHalhKUzc3Rm5pUlZtYWNkYnNmVXdmMU9SNHd0VXhUU050Q0ZnNGNWMUhlUzgy"

    // MARK: - Model Selection
    @Published var llmModel: String = "agnes-3.0-flash" { didSet { savePersisted() } }
    @Published var llmImageModel: String = "agnes-image-2.5-flash" { didSet { savePersisted() } }
    @Published var llmVideoModel: String = "agnes-video-2.5-fast" { didSet { savePersisted() } }
    @Published var llmBaseURL: String = "" { didSet { savePersisted() } }
    @Published var llmAPIKey: String = "" { didSet { savePersisted() } }

    // MARK: - Video Parameters
    @Published var params = VideoParams() { didSet { savePersisted() } }

    // MARK: - UI
    @Published var uiLanguage: String = "zh" { didSet { savePersisted() } }
    @Published var logLevel: String = "INFO" { didSet { savePersisted() } }

    // MARK: - Model Lists
    static let textModels: [(String, String)] = [
        ("agnes-3.0-flash",       "Agnes 3.0 Flash (Text - Recommended)"),
        ("agnes-2.5-pro-alpha",   "Agnes 2.5 Pro Alpha"),
        ("agnes-2.5-flash",       "Agnes 2.5 Flash"),
        ("agnes-2.0-flash",       "Agnes 2.0 Flash"),
        ("agnes-1.5-flash",       "Agnes 1.5 Flash")
    ]

    static let imageModels: [(String, String)] = [
        ("agnes-image-2.5-flash", "Agnes Image 2.5 Flash (Image - Recommended)"),
        ("agnes-image-2.0-flash", "Agnes Image 2.0 Flash")
    ]

    static let videoModels: [(String, String)] = [
        ("agnes-video-2.5-fast",  "Agnes Video 2.5 Fast (Video - Recommended)"),
        ("agnes-video-2.5-flash", "Agnes Video 2.5 Flash")
    ]

    // MARK: - Methods
    func readyForLLM() -> Bool {
        return !effectiveLLMKey().isEmpty && !llmBaseURL.isEmpty
    }

    func effectiveLLMKey() -> String {
        return !llmAPIKey.isEmpty ? llmAPIKey : Self.defaultLLMAPIKey
    }

    // MARK: - Persistence
    private let prefs = UserDefaults.standard

    init() {
        loadPersisted()
        if llmBaseURL.isEmpty {
            llmBaseURL = Self.defaultLLMBaseURL
            llmAPIKey = Self.defaultLLMAPIKey
        }
    }

    private func savePersisted() {
        prefs.setValue(llmModel, forKey: "llmModel")
        prefs.setValue(llmImageModel, forKey: "llmImageModel")
        prefs.setValue(llmVideoModel, forKey: "llmVideoModel")
        prefs.setValue(llmBaseURL, forKey: "llmBaseURL")
        prefs.setValue(llmAPIKey, forKey: "llmAPIKey")
        prefs.setValue(uiLanguage, forKey: "uiLanguage")
        prefs.setValue(logLevel, forKey: "logLevel")
        if let data = try? JSONEncoder().encode(params) {
            prefs.setValue(data, forKey: "params")
        }
    }

    private func loadPersisted() {
        llmModel = prefs.string(forKey: "llmModel") ?? "agnes-3.0-flash"
        llmImageModel = prefs.string(forKey: "llmImageModel") ?? "agnes-image-2.5-flash"
        llmVideoModel = prefs.string(forKey: "llmVideoModel") ?? "agnes-video-2.5-fast"
        llmBaseURL = prefs.string(forKey: "llmBaseURL") ?? ""
        llmAPIKey = prefs.string(forKey: "llmAPIKey") ?? ""
        uiLanguage = prefs.string(forKey: "uiLanguage") ?? "zh"
        logLevel = prefs.string(forKey: "logLevel") ?? "INFO"
        if let data = prefs.value(forKey: "params") as? Data,
           let p = try? JSONDecoder().decode(VideoParams.self, from: data) {
            params = p
        }
    }
}
