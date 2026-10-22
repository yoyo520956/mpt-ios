import SwiftUI

/// 主界面（移动端竖版布局）：顶部品牌栏 → 四张卡片纵向堆叠（文案/视频/音频/字幕）→ 底部通栏"生成视频"
struct RootView: View {
    @EnvironmentObject private var config: ConfigStore
    @EnvironmentObject private var tasks: TaskManager
    @State private var showSettings = false
    @State private var showTasks = false
    @State private var isGenerating = false
    @State private var step: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showSettings: $showSettings, showTasks: $showTasks)
            ScrollView {
                VStack(spacing: MPTStyle.s4) {
                    ScriptCard()
                    VideoCard()
                    AudioCard()
                    SubtitleCard()
                }
                .padding(MPTStyle.s4)
            }
            .background(MPTStyle.pageBackground)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: MPTStyle.s2) {
                if !step.isEmpty {
                    HStack(spacing: MPTStyle.s2) {
                        if isGenerating { ProgressView().tint(MPTStyle.textSecondary) }
                        Text(step)
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: MPTStyle.s2) {
                        if isGenerating { ProgressView().tint(.white) }
                        Text(isGenerating ? "生成中…" : "生成视频")
                            .font(MPTStyle.title(16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MPTStyle.s3)
                    .foregroundColor(.white)
                    .background(MPTStyle.primary)
                    .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusSmall))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            .padding(.horizontal, MPTStyle.s4)
            .padding(.bottom, MPTStyle.s2)
            .background(MPTStyle.pageBackground)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showTasks) { TasksView() }
    }

    /// P2 全流水线：文案 → 关键词 → 素材检索/下载 → 配音 → BGM → AVFoundation 合成 → MP4
    private func generate() async {
        let subject = config.params.videoSubject.trimmingCharacters(in: .whitespaces)
        guard !subject.isEmpty else { step = "请先填写视频主题"; return }
        isGenerating = true
        step = "准备中…"
        let task = tasks.create(subject: subject)
        let pipe = VideoPipeline()
        pipe.onProgress = { msg, pct in
            DispatchQueue.main.async {
                step = msg
                tasks.update(task.id, progress: pct)
            }
        }
        do {
            let out = try await pipe.run(config: config)
            if let s = out.script { config.params.videoScript = s }
            tasks.update(task.id, state: MPTConst.taskComplete, progress: 100,
                         outputPath: out.url.path, note: out.note)
            step = "完成 · " + out.url.lastPathComponent
        } catch {
            MPTLog.error("生成失败：\(error.localizedDescription)")
            tasks.update(task.id, state: MPTConst.taskFailed, error: error.localizedDescription)
            step = "失败：" + error.localizedDescription
        }
        isGenerating = false
    }
}

/// 顶部品牌栏（MoneyPrinterTurbo v1.3.9 · 移动紧凑版：单行不换行 + 图标菜单）
struct TopBar: View {
    @EnvironmentObject private var config: ConfigStore
    @Binding var showSettings: Bool
    @Binding var showTasks: Bool

    var body: some View {
        HStack(spacing: MPTStyle.s3) {
            HStack(spacing: MPTStyle.s2) {
                Text("MoneyPrinterTurbo")
                    .font(MPTStyle.title(14))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(MPTStyle.textPrimary)
                Text("v\(MPTConst.originalVersion)")
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
                    .padding(.horizontal, MPTStyle.s2)
                    .padding(.vertical, 1)
                    .background(MPTStyle.controlBackground)
                    .clipShape(Capsule())
            }
            Spacer(minLength: MPTStyle.s2)
            Menu {
                Button("任务管理") { showTasks = true }
            } label: {
                Image(systemName: "list.bullet.rectangle")
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            Menu {
                ForEach(MPTConst.uiLanguages.indices, id: \.self) { i in
                    let lang = MPTConst.uiLanguages[i]
                    Button {
                        config.uiLanguage = lang.0
                    } label: {
                        if config.uiLanguage == lang.0 {
                            Label(lang.1, systemImage: "checkmark")
                        } else {
                            Text(lang.1)
                        }
                    }
                }
            } label: {
                HStack(spacing: MPTStyle.s1) {
                    Text(shortLang())
                        .font(MPTStyle.caption())
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }
        }
        .foregroundColor(MPTStyle.textPrimary)
        .padding(.horizontal, MPTStyle.s4)
        .padding(.vertical, MPTStyle.s2)
        .background(MPTStyle.pageBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(MPTStyle.divider), alignment: .bottom)
    }

    private func shortLang() -> String {
        let m = ["zh": "中文", "en": "EN", "de": "DE", "es": "ES", "fr": "FR", "it": "IT",
                 "pt": "PT", "ru": "RU", "tr": "TR", "vi": "VI", "id": "ID",
                 "ko": "KO", "ca": "CA", "az": "AZ"]
        return m[config.uiLanguage] ?? "中文"
    }
}
