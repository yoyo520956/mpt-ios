import Foundation

/// Azure TTS 音色表（1:1 使用原版 app/services/data/azure_voices.json，331 条）
final class VoiceService {
    static let shared = VoiceService()
    private var cached: [(String, String)] = []

    func azureVoices() async -> [(String, String)] {
        if !cached.isEmpty { return cached }
        guard let url = Bundle.main.url(forResource: "azure_voices", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONDecoder().decode([AzureVoice].self, from: data) else {
            return [("zh-CN-XiaoxiaoNeural-Female", "zh-CN-Xiaoxiao-女性")]
        }
        let list = arr.map { ($0.name, "\($0.name)-\(genderText($0.gender))") }
        cached = list
        return list
    }

    private func genderText(_ g: String) -> String {
        g.lowercased().contains("female") ? "女性" : "男性"
    }

    struct AzureVoice: Decodable {
        let name: String
        let gender: String
    }
}
