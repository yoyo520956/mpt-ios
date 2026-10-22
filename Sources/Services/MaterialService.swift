import Foundation

/// 素材检索（对应原版 app/services/material.py；本期实现 Pexels + Pixabay 真实检索）
final class MaterialService {
    static let shared = MaterialService()

    struct PexelsVideo: Decodable {
        struct Item: Decodable {
            struct Src: Decodable {
                let medium: String
                let original: String
            }
            let id: Int
            let duration: Double
            let image: String
            let video: Src
        }
        let videos: [Item]
    }

    /// Pexels 检索
    func searchPexels(keyword: String, apiKey: String, page: Int = 1) async throws -> [MaterialInfo] {
        guard !apiKey.isEmpty else { throw MPTError.missingKey("pexels_api_key") }
        var comps = URLComponents(string: "https://api.pexels.com/videos/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "per_page", value: "10"),
            URLQueryItem(name: "page", value: String(page))
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(apiKey, forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MPTError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let out = try JSONDecoder().decode(PexelsVideo.self, from: data)
        return out.videos.map {
            MaterialInfo(provider: "pexels", url: $0.video.original, duration: Int($0.duration))
        }
    }

    /// Pixabay 检索
    func searchPixabay(keyword: String, apiKey: String) async throws -> [MaterialInfo] {
        guard !apiKey.isEmpty else { throw MPTError.missingKey("pixabay_api_key") }
        var comps = URLComponents(string: "https://pixabay.com/api/videos/")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "per_page", value: "10")
        ]
        let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: comps.url!))
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MPTError.badResponse((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = root["hits"] as? [[String: Any]] else { return [] }
        return hits.compactMap { hit in
            guard let variants = hit["video"] as? [String: Any] else { return nil }
            let url = (variants["large"] as? String) ?? (variants["medium"] as? String) ?? ""
            guard !url.isEmpty else { return nil }
            return MaterialInfo(provider: "pixabay", url: url, duration: Int((hit["duration"] as? Double) ?? 0))
        }
    }
}
