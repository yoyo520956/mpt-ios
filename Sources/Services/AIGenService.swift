import Foundation

/// AI Content Generation: Image (Ken Burns) + Video with professional prompt templates
/// P3 features
final class AIGenService {
    static let shared = AIGenService()

    // Professional prompt prefix for novel-to-video
    static let novelToVideoPrefix = """
You are a professional AI video director. Transform literary text into high-quality visual narratives following these principles:

[Character Consistency]
- Lock appearance (age/hair/clothing/temperament) on first description
- Use pronouns + identity tags in subsequent scenes
- Only change clothing when plot explicitly states

[Cinematography Rules]
- Each scene: shot size (close/mid/wide) + angle (high/eye/low) + camera movement (push/pull/pan/track/follow)
- Dynamic: "camera follows... moving", "slow push in/out", "pan to reveal..."
- Static: "locked position", "slow push for atmosphere"

[Lighting & Atmosphere]
- Time: "soft morning light", "golden hour backlight", "cold moonlight"
- Weather: "misty rain", "sun through clouds", "fog rolling in"
- Mood: Joyful=warm/high saturation; Suspense=low sat/high contrast/shadows

[Output Format]
Generate independent video prompts for each scene (50-80 words), including:
1. Scene description (environment + lighting)
2. Character action and expression
3. Camera movement
4. Atmosphere keywords
"""

    static let cinematicKeywords = [
        "cinematic lighting", "film grain", "depth of field", "color graded",
        "shoot on ARRI Alexa", "anamorphic lens", "dramatic shadows",
        "rule of thirds composition", "leading lines", "golden hour"
    ]

    func extractCharacters(from text: String) -> [String] {
        // Simplified: return empty for now, can be enhanced with NLP
        return []
    }

    // Generate images (returns URLs)
    func generateImages(prompt: String, count: Int, config: ConfigStore) async throws -> [URL] {
        guard config.readyForLLM() else { throw MPTError.missingKey("llm_api_key") }
        let model = config.llmImageModel.isEmpty ? "agnes-image-2.5-flash" : config.llmImageModel
        let url = URL(string: "\(config.llmBaseURL)/images/generations")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(config.effectiveLLMKey())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["model": model, "prompt": prompt, "n": count, "size": "1024x1024"]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MPTError.badResponse(resp as? HTTPURLResponse?.statusCode ?? -1)
        }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let data_arr = root?["data"] as? [[String: Any]] else { throw MPTError.decode("No image data") }
        return data_arr.compactMap { $0["url"] as? String }.compactMap { URL(string: $0) }
    }

    // Generate video (returns URL)
    func generateVideo(prompt: String, duration: Double, config: ConfigStore) async throws -> URL {
        guard config.readyForLLM() else { throw MPTError.missingKey("llm_api_key") }
        let model = config.llmVideoModel.isEmpty ? "agnes-video-2.5-fast" : config.llmVideoModel
        let url = URL(string: "\(config.llmBaseURL)/video/generations")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(config.effectiveLLMKey())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["model": model, "prompt": prompt, "duration": duration, "aspect_ratio": "9:16"]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MPTError.badResponse(resp as? HTTPURLResponse?.statusCode ?? -1)
        }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let videoUrl = root?["video_url"] as? String, let u = URL(string: videoUrl) else {
            throw MPTError.decode("No video URL")
        }
        return u
    }
}
