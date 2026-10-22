import SwiftUI

/// 主界面：1:1 还原原版 Streamlit 布局
/// 顶部品牌栏 → 四列设置卡片（文案/视频/音频/字幕）→ 底部通栏"生成视频"
struct RootView: View {
    @EnvironmentObject private var config: ConfigStore
    @EnvironmentObject private var tasks: TaskManager
    @State private var showSettings = false
    @State private var showTasks = false
    @State private var isGenerating = false
    @State private var toast: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TopBar(showSettings: $showSettings, showTasks: $showTasks)
            ScrollView {
                VStack(spacing: MPTStyle.s4) {
                    HStack(alignment: .top, spacing: MPTStyle.s4) {
                        ScriptCard()
                        VideoCard()
                        AudioCard()
                        SubtitleCard()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(MPTStyle.s4)
            }
            .background(MPTStyle.pageBackground)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: MPTStyle.s2) {
                if !toast.isEmpty {
                    Text(toast)
                        .font(MPTStyle.caption())
                        .foregroundColor(MPTStyle.textSecondary)
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

    /// P1：生成链路占位（真实出片在 P2 核心流水线）
    private func generate() async {
        guard !config.params.videoSubject.isEmpty else {
            toast = "请先填写视频主题"
            return
        }
        isGenerating = true
        toast = ""
        let task = tasks.create(subject: config.params.videoSubject)
        do {
            let script = try await LLMService.shared.generateScript(
                subject: config.params.videoSubject,
                language: config.params.videoLanguage,
                paragraphNumber: config.params.paragraphNumber,
                scriptPrompt: config.params.videoScriptPrompt,
                systemPrompt: config.params.customSystemPrompt,
                config: config)
            config.params.videoScript = script
            tasks.update(task.id, state: MPTConst.taskComplete, progress: 100)
            toast = "文案已生成（P2 接入合成流水线）"
        } catch {
            MPTLog.error("生成失败：\(error.localizedDescription)")
            tasks.update(task.id, state: MPTConst.taskFailed, progress: 0, error: error.localizedDescription)
            toast = error.localizedDescription
        }
        isGenerating = false
    }
}

/// 顶部品牌栏（MoneyPrinterTurbo v1.3.9 · 任务管理 · ⚙设置 · 语言）
struct TopBar: View {
    @EnvironmentObject private var config: ConfigStore
    @Binding var showSettings: Bool
    @Binding var showTasks: Bool

    var body: some View {
        HStack(spacing: MPTStyle.s3) {
            HStack(spacing: MPTStyle.s2) {
                Text("MoneyPrinterTurbo")
                    .font(MPTStyle.title(17))
                    .foregroundColor(MPTStyle.textPrimary)
                Text("v\(MPTConst.originalVersion)")
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
                    .padding(.horizontal, MPTStyle.s2)
                    .padding(.vertical, 2)
                    .background(MPTStyle.controlBackground)
                    .clipShape(Capsule())
            }
            Spacer()
            Menu {
                Button("任务管理") { showTasks = true }
            } label: {
                Label("任务管理", systemImage: "list.bullet")
                    .font(MPTStyle.body())
                    .foregroundColor(MPTStyle.textPrimary)
            }
            Button { showSettings = true } label: {
                Label("设置", systemImage: "gearshape")
                    .font(MPTStyle.body())
                    .foregroundColor(MPTStyle.textPrimary)
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
                    Text(MPTConst.uiLanguages.first(where: { $0.0 == config.uiLanguage })?.1 ?? "简体中文")
                        .font(MPTStyle.body())
                    Image(systemName: "chevron.down").font(.caption)
                }
                .foregroundColor(MPTStyle.textPrimary)
            }
        }
        .padding(.horizontal, MPTStyle.s4)
        .padding(.vertical, MPTStyle.s3)
        .background(MPTStyle.pageBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(MPTStyle.divider), alignment: .bottom)
    }
}
