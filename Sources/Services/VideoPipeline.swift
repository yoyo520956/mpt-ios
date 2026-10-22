import Foundation

/// P2 核心流水线：文案 → 关键词 → 素材检索 → 下载 → 配音 → BGM → AVFoundation 合成 → MP4
/// （对应原版 webui/Main.py "生成视频" 的 services/video.py 全流程）
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
            throw MPTError.notSupported("请先填写视频主题")
        }
        let fm = FileManager.default
        let root = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MPT", isDirectory: true)
        let work = root.appendingPathComponent("work-\(UUID().uuidString.prefix(8))", isDirectory: true)
        let outDir = root.appendingPathComponent("outputs", isDirectory: true)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        try? fm.createDirectory(at: outDir, withIntermediateDirectories: true)
        func prog(_ m: String, _ pct: Int) { onProgress?(m, pct) }

        // 1. 文案
        var script = p.videoScript.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes: [String] = []
        if script.isEmpty {
            prog("生成文案…", 5)
            script = try await LLMService.shared.generateScript(
                subject: p.videoSubject, language: p.videoLanguage,
                paragraphNumber: p.paragraphNumber,
                scriptPrompt: p.videoScriptPrompt,
                systemPrompt: p.customSystemPrompt, config: config)
        } else {
            prog("使用已有文案", 10)
        }
        let sentences = splitSentences(script)
        guard !sentences.isEmpty else { throw MPTError.decode("文案没有可用句子") }

        // 2. 关键词
        var keywords = dedupeStrings(p.videoTerms)
        if keywords.isEmpty {
            prog("生成关键词…", 15)
            if config.readyForLLM() {
                if let raw = try? await LLMService.shared.generateTerms(
                    subject: p.videoSubject, script: script, amount: 5, config: config) {
                    keywords = dedupeStrings(raw)
                }
            }
            if keywords.isEmpty { keywords = [p.videoSubject]; notes.append("关键词不可用，用主题检索") }
        }
        prog("检索素材…", 25)

        // 3. 素材检索 + 下载
        let svc = MaterialService.shared
        var pool: [MaterialInfo] = []
        for kw in keywords {
            pool.append(contentsOf: await svc.searchWithFallback(keyword: kw, prefer: p.videoSource, config: config))
        }
        pool = dedupeMaterials(pool)
        guard !pool.isEmpty else {
            throw MPTError.network("素材检索为空：Pexels 需 PEXELS_API_KEY（设置页 Material 组），Coverr 免 Key 可兜底")
        }
        let shuffle = p.videoConcatMode == .random || p.videoTransitionMode == .shuffle
        let count = max(3, min(8, sentences.count))
        let picked: [MaterialInfo] = shuffle
            ? Array(pool.shuffled().prefix(count))
            : Array(pool.prefix(count))
        var files: [URL] = []
        for (i, m) in picked.enumerated() {
            prog("下载素材 \(i + 1)/\(picked.count)…", 30 + Int(Double(i) / Double(picked.count) * 30))
            do {
                files.append(try await svc.download(m, to: work))
            } catch {
                notes.append("素材 \(i + 1) 下载失败跳过")
            }
        }
        guard !files.isEmpty else { throw MPTError.network("素材下载全部失败") }

        // 4. 配音
        prog("生成配音…", 65)
        var narration: URL?
        switch p.voiceMode {
        case "none":
            notes.append("配音关闭")
        case "upload":
            if !p.customAudioFile.isEmpty { narration = URL(fileURLWithPath: p.customAudioFile) }
            if narration == nil { notes.append("未提供音频文件，无配音") }
        default:
            let r = await TTSService.shared.synthesize(text: script, params: p, config: config, dir: work)
            narration = r.url
            if r.note.contains("静音") { notes.append(r.note) }
        }

        // 5. BGM
        var bgm: URL?
        switch p.bgmType {
        case "none": break
        case "custom":
            if !p.bgmFile.isEmpty { bgm = URL(fileURLWithPath: p.bgmFile) }
            if bgm == nil { notes.append("未提供 BGM 文件，无背景音乐") }
        default:
            if let f = bundleBGM() { bgm = f } else { notes.append("包内未找到 BGM") }
        }

        // 6. 字幕分配 + 合成
        let subs: [String]
        if p.matchMaterialsToScript {
            subs = files.indices.map { sentences[$0 % sentences.count] }
        } else {
            let mixed = sentences.shuffled()
            subs = files.indices.map { mixed[$0 % mixed.count] }
        }
        prog("合成视频…", 80)
        let tf = DateFormatter()
        tf.dateFormat = "yyyyMMdd-HHmm"
        let safe = String(p.videoSubject.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0.properties.isIdeographic }.prefix(12))
        let outURL = outDir.appendingPathComponent("MPT-\(tf.string(from: Date()))-\(safe.isEmpty ? "video" : safe).mp4")
        let composer = VideoComposer()
        let res = await composer.compose(clips: files, subtitles: subs, narration: narration, bgm: bgm,
                                             params: p, outURL: outURL,
                                             onProgress: { pct in
            prog("合成视频… \(pct)%", 80 + pct / 5)
        })
        try? fm.removeItem(at: work)

        var out = Output(url: outURL, script: script)
        if !res.note.isEmpty { notes.append(res.note) }
        out.note = notes.joined(separator: "；")
        MPTLog.info("流水线完成：\(out.url.path)（notes: \(out.note)）")
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
