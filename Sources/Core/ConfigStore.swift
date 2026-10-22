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
        ("llm_api_key", "LLM API Key", "LLM"),
        ("pexels_api_key", "Pexels API Key", "Material"),
        ("pixabay_api_key", "Pixabay API Key", "Material"),
        ("coverr_api_key", "Coverr API Key", "Material"),
        ("metaso_api_key", "Metaso API Key", "Video Gen"),
        ("muapi_api_key", "MuAPI API Key", "Video Gen"),
        ("ofox_api_key", "OFox API Key", "Video Gen"),
        ("seedance_api_key", "Volcano Engine Seedance API Key", "Video Gen"),
        ("elevenlabs_api_key", "ElevenLabs API Key", "Voice"),
        ("sonilo_api_key", "Sonilo API Key", "Voice"),
        ("siliconflow_api_key", "SiliconFlow API Key", "Voice"),
        ("twelvelabs_api_key", "TwelveLabs API Key", "Video Gen"),
        ("upload_post_api_key", "Upload Post API Key", "Publish")
    ]

    func key(_ id: String) -> String { KeychainStore.get(id) }
    func setKey(_ id: String, _ value: String) { KeychainStore.set(value, for: id) }
    func hasKey(_ id: String) -> Bool { !key(id).isEmpty }

    /// 需要 Key 才能工作的能力
    func readyForLLM() -> Bool { hasKey("llm_api_key") && !llmBaseURL.isEmpty }
}
