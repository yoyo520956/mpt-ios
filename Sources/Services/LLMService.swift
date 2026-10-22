import Foundation

/// LLM 协议（对应原版 app/models/llm_provider.py 的 provider 抽象）
protocol LLMProvider {
    var name: String { get }
    func complete(prompt: String, system: String?) async throws -> String
}

/// OpenAI 兼容实现（覆盖 GPT / DeepSeek / Agnes / 通义 / Kimi 等，原版同样走 OpenAI 兼容端点）
struct OpenAICompatibleProvider: LLMProvider {
    let name: String
    let baseURL: String
    let apiKey: String
    let model: String

    func complete(prompt: String, system: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw MPTError.missingKey("llm_api_key") }
        let url = baseURL.hasSuffix("/v1") ? baseURL + "/chat/completions" : baseURL + "/v1/chat/completions"
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var messages: [[String: String]] = []
        if let system, !system.isEmpty { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": prompt])
        let body: [String: Any] = ["model": model, "messages": messages, "stream": false]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw MPTError.network("无响应") }
        guard (200..<300).contains(http.statusCode) else { throw MPTError.badResponse(http.statusCode) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let msg = choices.first?["message"] as? [String: Any],
              let text = msg["content"] as? String else { throw MPTError.decode("未取到 content") }
        return text
    }
}

/// 业务服务：脚本 / 关键词生成（对应原版 app/services/llm.py）
final class LLMService {
    static let shared = LLMService()

    /// 取当前配置的有效 provider（走 ConfigStore 内置默认值）
    func provider(_ config: ConfigStore) -> OpenAICompatibleProvider {
        config.provider()
    }

    /// 生成视频文案
    func generateScript(subject: String, language: String, paragraphNumber: Int,
                        scriptPrompt: String, systemPrompt: String,
                        config: ConfigStore) async throws -> String {
        let p = provider(config)
        var prompt = "请根据主题创作一份短视频文案。主题：\(subject)。段落数：\(paragraphNumber)。"
        if !language.isEmpty { prompt += "文案语言：\(language)。" }
        if !scriptPrompt.isEmpty { prompt += "额外要求：\(scriptPrompt)" }
        let sys = systemPrompt.isEmpty
            ? "你是一名专业的短视频文案编剧，输出纯文案正文，不要解释。"
            : systemPrompt
        return try await p.complete(prompt: prompt, system: sys)
    }

    /// 生成视频关键词（英文）
    func generateTerms(subject: String, script: String, amount: Int,
                       config: ConfigStore) async throws -> String {
        let p = provider(config)
        let prompt = """
        根据主题与文案生成用于检索素材的英文关键词，逗号分隔，最多 \(amount) 个。
        主题：\(subject)
        文案：\(script)
        """
        return try await p.complete(prompt: prompt,
                                    system: "你只输出英文关键词，逗号分隔，不要任何解释。")
    }
}
