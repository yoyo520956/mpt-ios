import Foundation
import CommonCrypto

/// 配音服务：Azure TTS（需 Key）→ Edge TTS（免 Key）→ 静音兜底。对应原版 app/services/voice.py
final class TTSService {
    static let shared = TTSService()

    struct Result {
        let url: URL
        var note: String = ""
    }

    func synthesize(text: String, params: VideoParams, config: ConfigStore, dir: URL) async -> Result {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return Result(url: MPTAudioUtil.silentWAV(dir: dir, seconds: 1), note: "无配音文本")
        }
        let lang = params.videoLanguage.isEmpty ? detectLang(clean) : params.videoLanguage
        let voice = params.voiceName.isEmpty ? Self.zhVoice : params.voiceName
        let rate = params.voiceRate
        if config.hasKey("azure_tts_key"),
           let u = await azure(text: clean, voice: voice, lang: lang, rate: rate, dir: dir, config: config) {
            return Result(url: u, note: "Azure TTS")
        }
        if let u = await edge(text: clean, voice: voice, lang: lang, rate: rate, dir: dir) {
            return Result(url: u, note: "Edge TTS")
        }
        let secs = max(2, Double(clean.count) * 0.35 / max(rate, 0.3))
        return Result(url: MPTAudioUtil.silentWAV(dir: dir, seconds: secs),
                      note: "配音降级静音（Edge/Azure 均失败）")
    }

    static let zhVoice = "zh-CN-XiaoxiaoNeural-Female"

    private func detectLang(_ t: String) -> String {
        for ch in t { if ch.isASCII == false { return "zh-CN" } }
        return "en-US"
    }

    private func estimateSeconds(_ t: String, _ rate: Double) -> Double {
        max(2, Double(t.count) * 0.35 / max(rate, 0.3))
    }

    // MARK: - Azure

    private func azure(text: String, voice: String, lang: String, rate: Double,
                       dir: URL, config: ConfigStore) async -> URL? {
        do {
            let key = config.key("azure_tts_key")
            let region = config.key("azure_tts_region").isEmpty ? "eastasia" : config.key("azure_tts_region")
            guard let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/voices/speak?api-version=1.0.1") else { return nil }
            let pct = Int(((rate - 1.0) * 100).rounded())
            let ssml = """
            <speak version="1.0" xml:lang="\(lang)"><voice name="\(voice)">\
            <prosody rate="\(pct > 0 ? "+" : "")\(pct)%">\
            \(escape(text))</prosody></voice></speak>
            """
            var req = URLRequest(url: url, timeoutInterval: 90)
            req.httpMethod = "POST"
            req.setValue(key, forHTTPHeaderField: "X-Api-Key")
            req.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
            req.setValue("audio-24khz-96kbitrate-mono-mp3", forHTTPHeaderField: "OutputFormat")
            req.httpBody = ssml.data(using: .utf8)
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            guard (200..<300).contains(code) else {
                MPTLog.error("Azure TTS \(code) \(String(data: data.prefix(200), encoding: .utf8) ?? "")")
                return nil
            }
            guard data.count > 1000 else { return nil }
            let out = dir.appendingPathComponent("mpt_tts_azure.mp3")
            try data.write(to: out)
            return out
        } catch {
            MPTLog.error("Azure TTS \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Edge

    private func edge(text: String, voice: String, lang: String, rate: Double, dir: URL) async -> URL? {
        do {
            let uid = UUID().uuidString
            let secKey = md5Hex("\(uid)-1111-416121953")
            let token = "4999ac4999ac4999"
            guard var comps = URLComponents(string: "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge") else { return nil }
            comps.queryItems = [
                URLQueryItem(name: "trustedclienttoken", value: token),
                URLQueryItem(name: "seckey", value: secKey),
                URLQueryItem(name: "uid", value: uid),
                URLQueryItem(name: "version", value: "1111.416121953")
            ]
            guard let wsURL = comps.url else { return nil }
            let ws = URLSession.shared.webSocketTask(with: wsURL)
            ws.resume()
            defer { ws.cancel(with: .goingAway, reason: nil) }

            let pct = Int(((rate - 1.0) * 100).rounded())
            let ssml = """
            <speak version="1.0" xml:lang="\(lang)"><voice name="\(voice)">\
            <prosody rate="\(pct > 0 ? "+" : "")\(pct)%">\
            \(escape(text))</prosody></voice></speak>
            """
            let cfg: [String: Any] = [
                "context": [
                    "synthesis": [
                        "auth": ["token": "", "token_type": "raw"],
                        "config": [
                            "audio": ["metadata": ["content_type": "audio/mpeg", "sample_rate": 24000, "bit_rate": 48000],
                                      "output": "audio-24khz-48kbitrate-mono-mp3"],
                            "telemetry": ["client_instance_id": uuid(), "log_to": "client_file", "tracking_id": uuid()]
                        ],
                        "turn": 0, "type": "synthesis"
                    ]
                ]
            ]
            let msg: [String: Any] = [
                "context": ["synthesis": ["text": ssml, "turn": 1, "type": "message"]]
            ]
            for obj in [cfg, msg] {
                let d = try JSONSerialization.data(withJSONObject: obj)
                try await ws.send(.data(d))
            }
            var audio = Data()
            for _ in 0..<400 {
                let m = try await ws.receive()
                guard case .data(let d) = m else { break }
                let b = [UInt8](d)
                if b.count > 4 {
                    let type = b[4]
                    if type == 2 {
                        audio.append(d)
                    } else if type == 1 {
                        continue
                    }
                }
            }
            guard audio.count > 1000 else {
                MPTLog.error("Edge TTS 无音频 \(audio.count)B")
                return nil
            }
            let out = dir.appendingPathComponent("mpt_tts_edge.mp3")
            try audio.write(to: out)
            return out
        } catch {
            MPTLog.error("Edge TTS \(error.localizedDescription)")
            return nil
        }
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func uuid() -> String { UUID().uuidString }

    private func md5Hex(_ s: String) -> String {
        let d = s.data(using: .utf8)!
        var out = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        d.withUnsafeBytes { _ = CC_MD5($0.baseAddress, d.count, &out) }
        return out.map { String(format: "%02x", $0) }.joined()
    }
}
