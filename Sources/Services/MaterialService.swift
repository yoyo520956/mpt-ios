import Foundation

/// 素材检索与下载（对应原版 app/services/material.py；P2 实现 pexels/pixabay/coverr 真实检索，
/// AI 素材源 wavespeed/seedance/ofox/metaso/muapi/loomloom 为 P3）
final class MaterialService {
    static let shared = MaterialService()

    struct PexelsVideo: Decodable {
        struct Item: Decodable {
            struct Src: Decodable {
                let sd: String?
                let hd: String?
                let uhd: String?
            }
            let id: Int
            let duration: Double
            let video: Src
        }
        let videos: [Item]
    }

    enum Provider {
        case pexels, pixabay, coverr
        static let all: [Provider] = [.pexels, .pixabay, .coverr]
        var id: String {
            switch self {
            case .pexels: return "pexels"
            case .pixabay: return "pixabay"
            case .coverr: return "coverr"
            }
        }
    }

    /// 单源检索
    func search(_ provider: Provider, keyword: String, config: ConfigStore) async throws -> [MaterialInfo] {
        switch provider {
        case .pexels: return try await pexels(keyword: keyword, config: config)
        case .pixabay: return try await pixabay(keyword: keyword, config: config)
        case .coverr: return try await coverr(keyword: keyword, config: config)
        }
    }

    /// 降级链：偏好源在前，失败/空结果自动换下一家（原版 fallback 语义）
    func searchWithFallback(keyword: String, prefer: String, config: ConfigStore) async -> [MaterialInfo] {
        var chain = Provider.all
        if let idx = Provider.all.firstIndex(where: { $0.id == prefer }),
           MPTConst.stockVideoSources.contains(prefer) {
            chain = Array(chain[idx...]) + Array(chain[..<idx])
        }
        var failed: [String] = []
        for p in chain {
            do {
                let items = try await search(p, keyword: keyword, config: config)
                if !items.isEmpty {
                    if !failed.isEmpty { MPTLog.info("素材源降级：\(failed.joined(separator: " | "))") }
                    return items
                }
                failed.append("\(p.id)：空结果")
            } catch {
                failed.append("\(p.id)：\(error.localizedDescription)")
            }
        }
        MPTLog.error("素材源全部失败：\(failed.joined(separator: " | "))")
        return []
    }

    func pexels(keyword: String, config: ConfigStore) async throws -> [MaterialInfo] {
        guard !config.key("pexels_api_key").isEmpty else { throw MPTError.missingKey("pexels_api_key") }
        var comps = URLComponents(string: "https://api.pexels.com/videos/search")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "per_page", value: "8")
        ]
        var req = URLRequest(url: comps.url!, timeoutInterval: 30)
        req.setValue(config.key("pexels_api_key"), forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard ok(resp) else { throw MPTError.badResponse(status(resp)) }
        guard let out = try? JSONDecoder().decode(PexelsVideo.self, from: data) else {
            throw MPTError.decode("pexels 响应解析失败")
        }
        var items: [MaterialInfo] = []
        for v in out.videos {
            let url = v.video.hd ?? v.video.sd ?? v.video.uhd ?? ""
            if !url.isEmpty { items.append(MaterialInfo(provider: "pexels", url: url, duration: Int(v.duration))) }
        }
        return items
    }

    func pixabay(keyword: String, config: ConfigStore) async throws -> [MaterialInfo] {
        guard !config.key("pixabay_api_key").isEmpty else { throw MPTError.missingKey("pixabay_api_key") }
        var comps = URLComponents(string: "https://pixabay.com/api/videos/")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: config.key("pixabay_api_key")),
            URLQueryItem(name: "q", value: keyword),
            URLQueryItem(name: "per_page", value: "8")
        ]
        let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: comps.url!, timeoutInterval: 30))
        guard ok(resp) else { throw MPTError.badResponse(status(resp)) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hits = root["hits"] as? [[String: Any]] else { return [] }
        var items: [MaterialInfo] = []
        for hit in hits {
            let video = hit["video"] as? [String: Any] ?? [:]
            let url = (video["large"] as? String) ?? (video["medium"] as? String) ?? (video["small"] as? String) ?? ""
            guard !url.isEmpty else { continue }
            items.append(MaterialInfo(provider: "pixabay", url: url, duration: Int((hit["duration"] as? NSNumber)?.doubleValue ?? 0)))
        }
        return items
    }

    /// Coverr 公开检索（免 Key 兜底源）
    func coverr(keyword: String, config: ConfigStore) async throws -> [MaterialInfo] {
        var comps = URLComponents(string: "https://coverr.co/content/videos")!
        comps.queryItems = [
            URLQueryItem(name: "query", value: keyword),
            URLQueryItem(name: "limit", value: "8")
        ]
        let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: comps.url!, timeoutInterval: 30))
        guard ok(resp) else { throw MPTError.badResponse(status(resp)) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items0 = root["items"] as? [[String: Any]] else { return [] }
        var items: [MaterialInfo] = []
        for it in items0 {
            let media = it["media"] as? [String: Any] ?? [:]
            let hd = media["hd"] as? [String: Any] ?? [:]
            var url = (hd["url"] as? String) ?? ""
            if url.isEmpty { url = (it["mediaUrl"] as? String) ?? "" }
            if url.isEmpty { url = (it["url"] as? String) ?? "" }
            if !url.isEmpty { items.append(MaterialInfo(provider: "coverr", url: url, duration: 0)) }
        }
        return items
    }

    /// 素材下载（原段落取前 videoClipDuration 秒由合成器裁剪）
    func download(_ info: MaterialInfo, to dir: URL) async throws -> URL {
        guard let url = URL(string: info.url) else { throw MPTError.network("素材链接非法") }
        let (data, resp) = try await URLSession.shared.data(
            for: URLRequest(url: url, timeoutInterval: 120))
        guard ok(resp) else { throw MPTError.badResponse(status(resp)) }
        let out = dir.appendingPathComponent("clip-\(UUID().uuidString.prefix(6)).mp4")
        try data.write(to: out)
        MPTLog.info("素材下载完成 \(out.lastPathComponent) \(data.count / 1024)KB")
        return out
    }

    private func ok(_ r: URLResponse) -> Bool { (200..<300).contains(status(r)) }
    private func status(_ r: URLResponse) -> Int { (r as? HTTPURLResponse)?.statusCode ?? -1 }
}
