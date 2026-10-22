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

    @Published var params = VideoParams()
    @Published var uiLanguage: String = "zh"
    @Published var llmBaseURL: String = ""
    @Published var llmModel: String = ""
    @Published var logLevel: String = "INFO"

    // Key 列表（1:1 原版设置页 API Key 组）
    static let keyItems: [KeyItem] = [
        KeyItem(id: "llm_api_key", label: "LLM API Key", group: "LLM"),
        KeyItem(id: "pexels_api_key", label: "Pexels API Key", group: "Material"),
        KeyItem(id: "pixabay_api_key", label: "Pixabay API Key", group: "Material"),
        KeyItem(id: "coverr_api_key", label: "Coverr API Key", group: "Material"),
        KeyItem(id: "metaso_api_key", label: "Metaso API Key", group: "Video Gen"),
        KeyItem(id: "muapi_api_key", label: "MuAPI API Key", group: "Video Gen"),
        KeyItem(id: "ofox_api_key", label: "OFox API Key", group: "Video Gen"),
        KeyItem(id: "seedance_api_key", label: "Volcano Engine Seedance API Key", group: "Video Gen"),
        KeyItem(id: "elevenlabs_api_key", label: "ElevenLabs API Key", group: "Voice"),
        KeyItem(id: "sonilo_api_key", label: "Sonilo API Key", group: "Voice"),
        KeyItem(id: "siliconflow_api_key", label: "SiliconFlow API Key", group: "Voice"),
        KeyItem(id: "twelvelabs_api_key", label: "TwelveLabs API Key", group: "Video Gen"),
        KeyItem(id: "upload_post_api_key", label: "Upload Post API Key", group: "Publish")
    ]

    func key(_ id: String) -> String { KeychainStore.get(id) }
    func setKey(_ id: String, _ value: String) { KeychainStore.set(value, for: id) }
    func hasKey(_ id: String) -> Bool { !key(id).isEmpty }

    /// 需要 Key 才能工作的能力
    func readyForLLM() -> Bool { hasKey("llm_api_key") && !llmBaseURL.isEmpty }
}
