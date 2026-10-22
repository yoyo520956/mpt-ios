import Foundation

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    static let defaultLLMBaseURL = "https://api.agnes-ai.cn"
    static let defaultLLMAPIKey = "c2stWGFHalhKUzc3Rm5pUlZtYWNkYnNmVXdmMU9SNHd0VXhUU050Q0ZnNGNWMUhlUzgy"

    @Published var llmModel: String = "agnes-3.0-flash" { didSet { savePersisted() } }
    @Published var llmBaseURL: String = "" { didSet { savePersisted() } }
    @Published var llmAPIKey: String = "" { didSet { savePersisted() } }
    @Published var params = VideoParams() { didSet { savePersisted() } }
    @Published var uiLanguage: String = "zh" { didSet { savePersisted() } }
    @Published var logLevel: String = "INFO" { didSet { savePersisted() } }

    static let textModels: [(String, String)] = [
        ("agnes-3.0-flash", "Agnes 3.0 Flash (Recommended)"),
        ("agnes-2.5-flash", "Agnes 2.5 Flash"),
        ("agnes-2.0-flash", "Agnes 2.0 Flash")
    ]

    func readyForLLM() -> Bool {
        return !effectiveLLMKey().isEmpty && !llmBaseURL.isEmpty
    }

    func effectiveLLMKey() -> String {
        return !llmAPIKey.isEmpty ? llmAPIKey : Self.defaultLLMAPIKey
    }

    func key(_ id: String) -> String {
        return KeychainStore.shared.getString(forKey: id) ?? ""
    }

    func hasKey(_ id: String) -> Bool {
        return KeychainStore.shared.getString(forKey: id) != nil
    }

    func setKey(_ id: String, _ value: String) {
        KeychainStore.shared.setString(value, forKey: id)
    }

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
