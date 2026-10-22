import Foundation

/// P3 Pipeline: Traditional materials + AI Image (Ken Burns) + AI Video generation
/// Novel mode: auto-segment paste text -> generate per segment -> auto-synthesize
final class VideoPipeline {
    var onProgress: ((String, Int) -> Void)?

    struct Output {
        let url: URL
        var script: String? = nil
        var note: String = ""
        var isNovelMode: Bool = false
    }

    enum InputType {
        case subject(String)
        case novel(String)
        case customScript(String)
    }

    func run(config: ConfigStore, input: InputType) async throws -> Output {
        let p = config.params
        guard !p.videoSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MPTError.notSupported("Please fill video topic or paste novel content")
        }
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MPT", isDirectory: true)
        let work = root.appendingPathComponent("work-\(UUID().uuidString.prefix(8))", isDirectory: true)
        let outDir = root.appendingPathComponent("outputs", isDirectory: true)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        func prog(_ m: String, _ pct: Int) { onProgress?(m, pct) }

        // 1. Script
        var script = ""
        var isNovel = false
        switch input {
        case .subject(let s):
            script = p.videoScript.trimmingCharacters(in: .whitespacesAndNewlines)
            if script.isEmpty {
                prog("Generating script...", 5)
                script = try await LLMService.shared.generateScript(
                    subject: s, language: p.videoLanguage,
                    paragraphNumber: p.paragraphNumber,
                    scriptPrompt: p.videoScriptPrompt,
                    systemPrompt: p.customSystemPrompt, config: config)
            }
        case .novel(let novelText):
            isNovel = true
            script = novelText
        case .customScript(let s):
            script = s
        }
        guard !script.isEmpty else { throw MPTError.decode("No script obtained") }

        let sentences = splitSentences(script)
        guard !sentences.isEmpty else { throw MPTError.decode("Script has no usable sentences") }

        // 2. Material generation (hybrid)
        var files: [URL] = []
        var notes: [String] = []
        let useAI = config.params.videoSource == "ai-gen" || isNovel

        if useAI && config.readyForLLM() {
            prog("AI generating...", 30)
            let aiFiles = try await generateAIContent(sentences: sentences, config: config, work: work)
            files = aiFiles
            notes.append("Using AI-generated content")
        } else {
            prog("Searching materials...", 20)
            var keywords = dedupeStrings(p.videoTerms)
            if keywords.isEmpty {
                if config.readyForLLM() {
                    if let raw = try? await LLMService.shared.generateTerms(
                        subject: p.videoSubject, script: script, amount: 5, config: config) {
                        keywords = dedupeStrings(raw)
                    }
                }
                if keywords.isEmpty { keywords = [p.videoSubject] }
            }
            let svc = MaterialService.shared
            var pool: [MaterialInfo] = []
            for kw in keywords {
                pool.append(contentsOf: await svc.searchWithFallback(keyword: kw, prefer: p.videoSource, config: config))
            }
            pool = dedupeMaterials(pool)
            guard !pool.isEmpty else { throw MPTError.network("No materials found") }

            let count = min(sentences.count, 8)
            let shuffle = p.videoConcatMode == .random || p.videoTransitionMode == .shuffle
            let picked: [MaterialInfo] = shuffle
                ? Array(pool.shuffled().prefix(count))
                : Array(pool.prefix(count))
            for (i, m) in picked.enumerated() {
                prog("Downloading \(i+1)/\(picked.count)...", 35 + Int(Double(i)/Double(picked.count)*15))
                do {
                    files.append(try await svc.download(m, to: work))
                } catch {
                    notes.append("Material \(i+1) failed")
                }
            }
        }

        if files.isEmpty { throw MPTError.network("All material generation/download failed") }

        // 3. Voice
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

        // 4. BGM
        var bgm: URL?
        switch p.bgmType {
        case "none": break
        case "custom":
            if !p.bgmFile.isEmpty { bgm = URL(fileURLWithPath: p.bgmFile) }
        default:
            if let f = bundleBGM() { bgm = f }
        }

        // 5. Subtitles
        let subs: [String]
        if p.matchMaterialsToScript {
            subs = files.indices.map { sentences[$0 % sentences.count] }
        } else {
            let mixed = sentences.shuffled()
            subs = files.indices.map { mixed[$0 % mixed.count] }
        }

        // 6. Composite
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

        var out = Output(url: outURL, script: script, note: notes.joined(separator: ";"), isNovelMode: isNovel)
        if !res.note.isEmpty { out.note += (out.note.isEmpty ? "" : ";") + res.note }
        MPTLog.info("Pipeline complete: \(out.url.path)")
        return out
    }

    private func generateAIContent(sentences: [String], config: ConfigStore, work: URL) async throws -> [URL] {
        var files: [URL] = []
        let count = sentences.count
        for (i, sentence) in sentences.enumerated() {
            prog("AI segment \(i+1)/\(count)...", 30 + Int(Double(i)/Double(count)*25))
            let prompt = buildVideoPrompt(sentence: sentence, index: i, total: count)
            do {
                let vidURL = try await AIGenService.shared.generateVideo(prompt: prompt, duration: 4, config: config)
                let localURL = work.appendingPathComponent("ai-video-\(i).mp4")
                if let data = try? Data(contentsOf: vidURL) {
                    try data.write(to: localURL)
                    files.append(localURL)
                }
            } catch {
                do {
                    let imgURLs = try await AIGenService.shared.generateImages(prompt: prompt, count: 3, config: config)
                    for (j, imgURL) in imgURLs.enumerated() where j < 3 {
                        let localURL = work.appendingPathComponent("ai-img-\(i)-\(j).jpg")
                        if let data = try? Data(contentsOf: imgURL) {
                            try data.write(to: localURL)
                            files.append(localURL)
                        }
                    }
                } catch {
                    MPTLog.warning("Segment \(i) AI failed: \(error.localizedDescription)")
                }
            }
        }
        return files
    }

    private func buildVideoPrompt(sentence: String, index: Int, total: Int) -> String {
        let prefix = AIGenService.novelToVideoPrefix
        let sceneNum = index + 1
        let cinematic = AIGenService.cinematicKeywords.randomElement() ?? "cinematic lighting"
        return "\(prefix)\n\n[Scene \(sceneNum)/\(total)]\nOriginal: \(sentence)\n\nGenerate video prompt:"
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
