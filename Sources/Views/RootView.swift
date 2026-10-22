import SwiftUI

/// Simplified main interface: Top bar -> Script/Video cards -> Generate button
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
                        Text(isGenerating ? "Generating..." : "Generate Video")
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

    private func generate() async {
        let subject = config.params.videoSubject.trimmingCharacters(in: .whitespaces)
        let novelText = (config as? NovelConfigStore)?.novelText ?? ""
        guard !subject.isEmpty || !novelText.isEmpty else { step = "Please fill topic or paste novel"; return }
        isGenerating = true
        step = "Preparing..."
        let pipe = VideoPipeline()
        let input: VideoPipeline.InputType
        if !novelText.isEmpty {
            input = .novel(novelText)
        } else {
            input = .subject(subject)
        }
        pipe.onProgress = { msg, pct in
            DispatchQueue.main.async {
                step = msg
            }
        }
        do {
            let out = try await pipe.run(config: config, input: input)
            tasks.create(subject: out.script ?? subject, outputPath: out.url.path, note: out.note)
            step = "Done: " + out.url.lastPathComponent
        } catch {
            MPTLog.error("Generation failed: \(error.localizedDescription)")
            step = "Failed: " + error.localizedDescription
        }
        isGenerating = false
    }
}

/// Top bar (MoneyPrinterTurbo v1.3.9 mobile compact)
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
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
        }
        .foregroundColor(MPTStyle.textPrimary)
        .padding(.horizontal, MPTStyle.s4)
        .padding(.vertical, MPTStyle.s2)
        .background(MPTStyle.pageBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(MPTStyle.divider), alignment: .bottom)
    }
}
