import Foundation
import SwiftUI

/// 全局配置（对应原版 app/config/config.py 的 app/llm/ui/ui 分区）
struct KeyItem: Identifiable {
    let id: String
    let label: String
    let group: String
}

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var params = VideoParams() { didSet { savePersisted() } }
    @Published var uiLanguage: String = "zh" { didSet { savePersisted() } }
    @Published var llmBaseURL: String = "" { didSet { savePersisted() } }
    @Published var llmModel: String = "" { didSet { savePersisted() } }
    @Published var llmImageModel: String = "" { didSet { savePersisted() } }
    @Published var llmVideoModel: String = "agnes-video-2.5-fast" { didSet { savePersisted() } }
    @Published var logLevel: String = "INFO"

    // 内置 Agnes 2.0 API（默认填好，用户仍可覆盖）
    /// 硬编码 Base URL 与 API Key；Keychain 层仍保留以便用户自己改写
    static let defaultLLMBaseURL = "https://api.agnes-ai.cn"
    static let defaultLLMAPIKey = "c2stWGFHalhKUzc3Rm5pUlZtYWNkYnNmVXdmMU9SNHd0VXhUU050Q0ZnNGNWMUhlUzgy"

    // 模型默认值
    static let defaultTextModel   = "agnes-3.0-flash"
    static let defaultImageModel  = "agnes-image-2.5-flash"
    static let defaultVideoModel  = "agnes-video-2.5-fast"

    // 文本模型选项（展示给用户选）
    static let textModels: [(String, String)] = [
        ("agnes-3.0-flash",       "Agnes 3.0 Flash（文本·推荐）"),
        ("agnes-2.5-pro-alpha",   "Agnes 2.5 Pro Alpha"),
        ("agnes-2.5-flash",       "Agnes 2.5 Flash"),
        ("agnes-2.0-flash",       "Agnes 2.0 Flash"),
        ("agnes-1.5-flash",       "Agnes 1.5 Flash")
    ]
    // 图片模型选项
    static let imageModels: [(String, String)] = [
        ("agnes-image-2.5-flash",  "Agnes Image 2.5 Flash（图片·推荐）"),
        ("agnes-image-2.0-flash",  "Agnes Image 2.0 Flash"),
    ]
    // 视频模型选项（P3：AI 文生视频）
    static let videoModels: [(String, String)] = [
        ("agnes-video-2.5-fast",    "Agnes Video 2.5 Fast（视频·推荐）"),
        ("agnes-video-2.5-flash",   "Agnes Video 2.5 Flash"),
    ]

    /// 当前生效的 LLM provider（文本）
    func provider() -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(name: llmModel.isEmpty ? Self.defaultTextModel : llmModel,
                                  baseURL: llmBaseURL.isEmpty ? Self.defaultLLMBaseURL : llmBaseURL,
                                  apiKey: hasKey("llm_api_key") ? key("llm_api_key") : Self.defaultLLMAPIKey,
                                  model: llmModel.isEmpty ? Self.defaultTextModel : llmModel)
    }

    /// 有效 LLM key（优先用户已填的 key）
    func effectiveLLMKey() -> String {
        if hasKey("llm_api_key") && !key("llm_api_key").isEmpty { return key("llm_api_key") }
        return Self.defaultLLMAPIKey
    }

    /// 全部 API Key 列表
    static let keyItems: [KeyItem] = [
        KeyItem(id: "llm_api_key", label: "LLM API Key（默认内置 Agnes 2.0）", group: "LLM"),
        KeyItem(id: "pexels_api_key", label: "Pexels API Key（可不填，用 Coverr 兜底）", group: "素材"),
        KeyItem(id: "pixabay_api_key", label: "Pixabay API Key（可不填，用 Coverr 兜底）", group: "素材"),
        KeyItem(id: "coverr_api_key", label: "Coverr API Key（可留空）", group: "素材"),
        KeyItem(id: "metaso_api_key", label: "Metaso API Key", group: "视频生成"),
        KeyItem(id: "muapi_api_key", label: "MuAPI API Key", group: "视频生成"),
        KeyItem(id: "ofox_api_key", label: "OFox API Key", group: "视频生成"),
        KeyItem(id: "seedance_api_key", label: "Volcano Engine Seedance API Key", group: "视频生成"),
        KeyItem(id: "elevenlabs_api_key", label: "ElevenLabs API Key", group: "配音"),
        KeyItem(id: "sonilo_api_key", label: "Sonilo API Key", group: "配音"),
        KeyItem(id: "siliconflow_api_key", label: "SiliconFlow API Key", group: "配音"),
        KeyItem(id: "twelvelabs_api_key", label: "TwelveLabs API Key", group: "视频生成"),
        KeyItem(id: "upload_post_api_key", label: "Upload Post API Key", group: "发布"),
        KeyItem(id: "azure_tts_key", label: "Azure TTS API Key（可选）", group: "配音"),
        KeyItem(id: "azure_tts_region", label: "Azure TTS Region（默认 eastasia）", group: "配音")
    ]

    func key(_ id: String) -> String { KeychainStore.get(id) }
    func setKey(_ id: String, _ value: String) { KeychainStore.set(value, for: id) }
    func hasKey(_ id: String) -> Bool { !key(id).isEmpty }

    func readyForLLM() -> Bool {
        !effectiveLLMKey().isEmpty && !llmBaseURL.isEmpty
    }

    // MARK: - 持久化（Base URL / 模型 / 参数 / 界面语言；API Key 走 Keychain）

    private static let persistKey = "mpt.config.v1"

    private struct Persisted: Codable {
        var params: VideoParams
        var uiLanguage: String
        var llmBaseURL: String
        var llmModel: String
        var llmImageModel: String
        var llmVideoModel: String
    }

    private init() { loadPersisted() }

    func loadPersisted() {
        guard let d = UserDefaults.standard.data(forKey: Self.persistKey),
              let p = try? JSONDecoder().decode(Persisted.self, from: d) else { return }
        params = p.params
        uiLanguage = p.uiLanguage
        llmBaseURL = p.llmBaseURL
        llmModel = p.llmModel
        llmImageModel = p.llmImageModel
        llmVideoModel = p.llmVideoModel
    }

    private func savePersisted() {
        let p = Persisted(params: params, uiLanguage: uiLanguage,
                          llmBaseURL: llmBaseURL, llmModel: llmModel,
                          llmImageModel: llmImageModel, llmVideoModel: llmVideoModel)
        if let d = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(d, forKey: Self.persistKey)
        }
    }
}
