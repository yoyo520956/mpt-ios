import Foundation

/// P2 Core Pipeline: Script -> Keywords -> Materials -> Voice -> BGM -> Composite
final class VideoPipeline {
    var onProgress: ((String, Int) -> Void)?

    struct Output {
        let url: URL
        var script: String? = nil
        var note: String = ""
    }

    func run(config: ConfigStore) async throws -> Output {
        let p = config.params
        guard !p.videoSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MPTError.notSupported("Please fill video topic")
        }
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MPT", isDirectory: true)
        let work = root.appendingPathComponent("work-" + UUID().uuidString.prefix(8), isDirectory: true)
        let outDir = root.appendingPathComponent("outputs", isDirectory: true)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        func prog(_ m: String, _ pct: Int) { onProgress?(m, pct) }

        // 1. Script
        var script = p.videoScript.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes: [String] = []
        if script.isEmpty {
            prog("Generating script...", 5)
            script = try await LLMService.shared.generateScript(
                subject: p.videoSubject, language: p.videoLanguage,
                paragraphNumber: p.paragraphNumber,
                scriptPrompt: p.videoScriptPrompt,
                systemPrompt: p.customSystemPrompt, config: config)
        } else {
            prog("Using existing script", 10)
        }
        let sentences = splitSentences(script)
        guard !sentences.isEmpty else { throw MPTError.decode("Script has no usable sentences") }

        // 2. Keywords
        var keywords = dedupeStrings(p.videoTerms)
        if keywords.isEmpty {
            prog("Generating keywords...", 15)
            if config.readyForLLM() {
                if let raw = try? await LLMService.shared.generateTerms(
                    subject: p.videoSubject, script: script, amount: 5, config: config) {
                    keywords = dedupeStrings(raw)
                }
            }
            if keywords.isEmpty { keywords = [p.videoSubject]; notes.append("Keywords unavailable, using topic") }
        }
        prog("Searching materials...", 25)

        // 3. Materials
        let svc = MaterialService.shared
        var pool: [MaterialInfo] = []
        for kw in keywords {
            pool.append(contentsOf: await svc.searchWithFallback(keyword: kw, prefer: p.videoSource, config: config))
        }
        pool = dedupeMaterials(pool)
        guard !pool.isEmpty else {
            throw MPTError.network("No materials found: Pexels needs PEXELS_API_KEY")
        }
        let shuffle = p.videoConcatMode == .random || p.videoTransitionMode == .shuffle
        let count = max(3, min(8, sentences.count))
        let picked: [MaterialInfo] = shuffle
            ? Array(pool.shuffled().prefix(count))
            : Array(pool.prefix(count))
        var files: [URL] = []
        for (i, m) in picked.enumerated() {
            prog("Downloading \(i+1)/\(picked.count)...", 30 + Int(Double(i)/Double(picked.count)*25))
            do {
                files.append(try await svc.download(m, to: work))
            } catch {
                notes.append("Material \(i+1) failed")
            }
        }
        guard !files.isEmpty else { throw MPTError.network("All downloads failed") }

        // 4. Voice
        prog("Generating voice...", 60)
        var narration: URL?
        switch p.voiceMode {
        case "none": notes.append("Voice disabled")
        case "upload":
            if !p.customAudioFile.isEmpty { narration = URL(fileURLWithPath: p.customAudioFile) }
        default:
            let r = await TTSService.shared.synthesize(text: script, params: p, config: config, dir: work)
            narration = r.url
            if r.note.contains("silent") { notes.append(r.note) }
        }

        // 5. BGM
        var bgm: URL?
        switch p.bgmType {
        case "none": break
        case "custom":
            if !p.bgmFile.isEmpty { bgm = URL(fileURLWithPath: p.bgmFile) }
        default:
            if let f = bundleBGM() { bgm = f }
        }

        // 6. Subtitles
        let subs: [String]
        if p.matchMaterialsToScript {
            subs = files.indices.map { sentences[$0 % sentences.count] }
        } else {
            let mixed = sentences.shuffled()
            subs = files.indices.map { mixed[$0 % mixed.count] }
        }

        // 7. Composite
        prog("Compositing...", 75)
        let tf = DateFormatter()
        tf.dateFormat = "yyyyMMdd-HHmm"
        let safe = String(p.videoSubject.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0.properties.isIdeographic }.prefix(12))
        let outURL = outDir.appendingPathComponent("MPT-\(tf.string(from: Date()))-\(safe.isEmpty ? "video" : safe).mp4")
        let composer = VideoComposer()
        let res = await composer.compose(clips: files, subtitles: subs, narration: narration, bgm: bgm,
                                         params: p, outURL: outURL,
                                         onProgress: { pct in
            prog("Compositing... \(Int(pct*100))%", 75 + Int(pct*20))
        })
        try? fm.removeItem(at: work)

        var out = Output(url: outURL, script: script)
        if !res.note.isEmpty { notes.append(res.note) }
        out.note = notes.joined(separator: ";")
        MPTLog.info("Pipeline complete: \(out.url.path)")
        return out
    }

    private func splitSentences(_ s: String) -> [String] {
        let parts = s.components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n"))
        var out = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count >= 4 }
        if out.count > 20 { out = Array(out.prefix(20)) }
        return out
    }

    private func dedupeStrings(_ s: String) -> [String] {
        let terms = s.components(separatedBy: CharacterSet(charactersIn: ",，;；\n"))
        var seen = Set<String>()
        var out: [String] = []
        for t in terms.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) where !t.isEmpty {
            if seen.insert(t).inserted { out.append(t) }
            if out.count >= 6 { break }
        }
        return out
    }

    private func dedupeMaterials(_ items: [MaterialInfo]) -> [MaterialInfo] {
        var seen = Set<String>()
        return items.filter { m in seen.insert(m.id).inserted }
    }

    private func bundleBGM() -> URL? {
        var candidates = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []
        if candidates.isEmpty {
            candidates = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "BGM") ?? []
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.randomElement()
    }
}
