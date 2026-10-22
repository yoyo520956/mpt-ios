import Foundation

enum MPTError: LocalizedError {
    case missingKey(String)
    case badResponse(Int)
    case network(String)
    case decode(String)
    case notSupported(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let k): return "缺少 API Key：\(k)"
        case .badResponse(let code): return "服务返回错误码 \(code)"
        case .network(let m): return "网络错误：\(m)"
        case .decode(let m): return "数据解析失败：\(m)"
        case .notSupported(let m): return "暂不支持：\(m)"
        }
    }
}
