import Foundation
import AVFoundation
import CommonCrypto

/// 配音（对应原版 voice.py 的 edge/azure provider）
/// 优先级：Azure TTS（需 Key，设置页 Voice 组）→ Edge TTS（免 Key websocket）→ 静音轨兜底（SPEC 平台替代说明）
final class TTSService {
    static let shared = TTSService()

    struct TTSResult {
        let url: URL
        let note: String
    }

    func synthesize(text: String, params: VideoParams, config: ConfigStore, dir: URL) async -> TTSResult {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return TTSResult(url: makeSilent(dir: dir, seconds: 1.5), note: "无文案，配音为空")
        }
        let voice = params.voiceName.isEmpty ? defaultVoice(params.videoLanguage, text: clean) : params.voiceName
        let lang = xmlLang(params.videoLanguage, text: clean)
        let ssml = ssml(text: clean, voice: voice, rate: params.voiceRate, language: lang)

        if config.hasKey("azure_tts_key") {
            do {
                let region = config.key("azure_tts_region").isEmpty ? "eastasia" : config.key("azure_tts_region")
                let url = try await azure(ssml: ssml, key: config.key("azure_tts_key"), region: region, dir: dir)
                return TTSResult(url: url, note: "Azure TTS（\(voice)）")
            } catch { MPTLog.error("Azure TTS 失败：\(error.localizedDescription)") }
        }
        do {
            let url = try await edge(ssml: ssml, dir: dir)
            return TTSResult(url: url, note: "Edge TTS（\(voice)）")
        } catch { MPTLog.error("Edge TTS 失败：\(error.localizedDescription)") }
        let secs = max(2.0, Double(clean.count) * 0.25 / max(0.5, params.voiceRate))
        return TTSResult(url: makeSilent(dir: dir, seconds: secs), note: "配音不可用，使用静音轨道")
    }

    // MARK: - Azure TTS REST

    private func azure(ssml: String, key: String, region: String, dir: URL) async throws -> URL {
        var comps = URLComponents(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/voices/speak")!
        comps.queryItems = [URLQueryItem(name: "api-version", value: "1.0.1")]
        var req = URLRequest(url: comps.url!, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        req.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        req.setValue("audio-24khz-96kbitrate-mono-mp3", forHTTPHeaderField: "OutputFormat")
        req.httpBody = ssml.data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw MPTError.network("Azure TTS \(code)：\(String(data: data.prefix(160), encoding: .utf8) ?? "")")
        }
        let out = dir.appendingPathComponent("tts-\(UUID().uuidString.prefix(6)).mp3")
        try data.write(to: out)
        return out
    }

    // MARK: - Edge TTS（免 Key websocket，对应原版 edge_tts provider）

    private func edge(ssml: String, dir: URL) async throws -> URL {
        let uid = UUID()
        let secKey = md5Hex("\(uid.uuidString)-1111-416121953")
        var comps = URLComponents()
        comps.scheme = "wss"
        comps.host = "speech.platform.bing.com"
        comps.path = "/consumer/speech/synthesize/readaloud/edge"
        comps.queryItems = [
            URLQueryItem(name: "trustedclienttoken", value: "4999ac4999ac4999"),
            URLQueryItem(name: "seckey", value: secKey),
            URLQueryItem(name: "uid", value: uid.uuidString),
            URLQueryItem(name: "version", value: "1111.416121953")
        ]
        guard let wsURL = comps.url else { throw MPTError.network("edge ws 地址构造失败") }
        let task = URLSession.shared.webSocketTask(with: wsURL)
        task.resume()
        defer { task.cancel(with: .goingAway, reason: nil) }

        let cfg: [String: Any] = ["context": ["synthesis": ["auth": ["token": "", "token_type": "raw"],
            "config": ["audio": ["metadata": ["content_type": "audio/mpeg", "sample_rate": 24000, "bit_rate": 48000],
                        "output": "audio-24khz-48kbitrate-mono-mp3"],
                "telemetry": ["client_instance_id": UUID().uuidString, "log_to": "client_file",
                              "tracking_id": UUID().uuidString]],
            "turn": 0, "type": "synthesis"]]]
        guard let d1 = try? JSONSerialization.data(withJSONObject: cfg) else { throw MPTError.network("edge 配置序列化失败") }
        try await task.send(.data(d1))
        let msg: [String: Any] = ["context": ["synthesis": ["text": ssml, "turn": 1, "type": "message"]]]
        guard let d2 = try? JSONSerialization.data(withJSONObject: msg) else { throw MPTError.network("edge 文本序列化失败") }
        try await task.send(.data(d2))

        var audio = Data()
        while true {
            let m = try await task.receive()
            switch m {
            case .data(let d):
                let bytes = [UInt8](d)
                var off = 4  // 前 4 字节为总长度
                while off + 3 <= bytes.count {
                    let t = bytes[off]
                    let plen = Int(bytes[off + 1]) << 8 | Int(bytes[off + 2])
                    off += 3
                    if t == 2, off + plen <= bytes.count {
                        audio.append(contentsOf: bytes[off..<(off + plen)])
                    }
                    off += plen
                }
            case .close: break
            default: break
            }
        }
        guard audio.count > 100 else { throw MPTError.network("Edge TTS 未返回音频") }
        let out = dir.appendingPathComponent("tts-\(UUID().uuidString.prefix(6)).mp3")
        try audio.write(to: out)
        MPTLog.info("Edge TTS 生成 \(out.lastPathComponent) \(audio.count / 1024)KB")
        return out
    }

    // MARK: - 工具

    private func md5Hex(_ s: String) -> String {
        let data = s.data(using: .utf8)!
        let digest = data.withUnsafeBytes { buf -> [UInt8] in
            var out = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5(buf.baseAddress, CC_LONG(data.count), &out)
            return out
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 静音轨兜底（生成指定时长的 m4a 静音文件，保证流水线可出片）
    private func makeSilent(dir: URL, seconds: Double) -> URL {
        let url = dir.appendingPathComponent("silent-\(Int(seconds)).m4a")
        do {
            let fmt = try AVAudioFile(forWriting: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1
            ])
            let frames = AVFrameCount(Int(44100 * max(0.5, seconds)))
            guard let buf = AVAudioPCMBuffer(pcmFormat: fmt.format, frameCapacity: frames) else {
                throw MPTError.network("静音轨生成失败")
            }
            buf.frameLength = frames
            fmt.write(from: buf)
        } catch {
            MPTLog.error("静音轨生成失败：\(error.localizedDescription)")
        }
        return url
    }

    private func defaultVoice(_ lang: String, text: String) -> String {
        let isCJK = text.unicodeScalars.contains { $0.properties.isIdeographic }
        let l = lang.isEmpty ? (isCJK ? "zh" : "en") : lang
        switch l {
        case "en": return "en-US-AriaNeural-Female"
        case "ja": return "ja-JP-NaoyNeural-Female"
        case "ko": return "ko-KR-SunHiNeural-Female"
        case "fr": return "fr-FR-DeniseNeural-Female"
        case "de": return "de-DE-KatjaNeural-Female"
        case "es": return "es-ES-ElviraNeural-Female"
        default: return "zh-CN-XiaoxiaoNeural-Female"
        }
    }

    private func xmlLang(_ lang: String, text: String) -> String {
        if !lang.isEmpty {
            switch lang {
            case "zh": return "zh-CN"
            case "en": return "en-US"
            case "ja": return "ja-JP"
            case "ko": return "ko-KR"
            case "fr": return "fr-FR"
            case "de": return "de-DE"
            case "es": return "es-ES"
            case "pt": return "pt-BR"
            case "ru": return "ru-RU"
            case "it": return "it-IT"
            case "tr": return "tr-TR"
            case "vi": return "vi-VN"
            case "id": return "id-ID"
            case "ca": return "ca-ES"
            case "az": return "az"
            default: return "en-US"
            }
        }
        return text.unicodeScalars.contains { $0.properties.isIdeographic } ? "zh-CN" : "en-US"
    }

    private func ssml(text: String, voice: String, rate: Double, language: String) -> String {
        let pct = String(format: "%+.0f%%", (rate - 1) * 100)
        return "<speak version=\"1.0\" xml:lang=\"\(language)\">"
            + "<voice name=\"\(voice)\"><prosody rate=\"\(pct)\">\(xmlEscape(text))</prosody></voice></speak>"
    }

    private func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
