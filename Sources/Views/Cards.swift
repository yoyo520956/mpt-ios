import SwiftUI

struct ScriptCard: View {
    @EnvironmentObject private var config: ConfigStore
    @State private var showAdvanced = false
    @State private var busy = false
    @State private var isNovelMode = false
    @State private var novelText = ""

    var body: some View {
        MPTCard(title: "Script Settings") {
            HStack {
                Button(isNovelMode ? "Script Mode" : "Novel Mode") {
                    withAnimation { isNovelMode.toggle() }
                }
                .buttonStyle(.bordered)
                .tint(isNovelMode ? MPTStyle.brand : MPTStyle.secondary)

                Spacer()

                if isNovelMode {
                    Text("Paste novel, auto-segment generate")
                        .font(MPTStyle.caption())
                        .foregroundColor(MPTStyle.textSecondary)
                }
            }

            if isNovelMode {
                MPTMultilineField(title: "Paste Novel Text (auto-segment)",
                                  text: $novelText,
                                  placeholder: "Paste your novel content here... Supports auto-segment, character consistency, professional prompts")
                    .frame(height: 120)
                Text("Will auto-segment and generate video with professional prompt templates")
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
            } else {
                MPTTextField(title: "Video Topic (AI will generate script)",
                             placeholder: "e.g., How AI is changing daily life",
                             text: $config.params.videoSubject)
                MPTSelectRow(title: "Script Language",
                             options: MPTConst.scriptLanguages,
                             selection: $config.params.videoLanguage)
                DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: MPTStyle.s2) {
                        MPTSelectRow(title: "Paragraphs",
                                     options: [("1", "1"), ("2", "2"), ("3", "3"), ("4", "4"), ("5", "5")],
                                     selection: $config.params.paragraphNumberRaw)
                        MPTMultilineField(title: "Custom System Prompt", text: $config.params.customSystemPrompt)
                        MPTMultilineField(title: "Video Script Prompt", text: $config.params.videoScriptPrompt)
                    }
                    .padding(.top, MPTStyle.s2)
                }
                .font(MPTStyle.body())

                MPTAccentButton(title: "Generate Script & Keywords", icon: "sparkles") {
                    Task { await generateScript() }
                }
                MPTMultilineField(title: "Video Script (optional)", text: $config.params.videoScript)
            }
        }
    }

    private func generateScript() async {
        busy = true
        defer { busy = false }
        do {
            let s = try await LLMService.shared.generateScript(
                subject: config.params.videoSubject, language: config.params.videoLanguage,
                paragraphNumber: config.params.paragraphNumber,
                scriptPrompt: config.params.videoScriptPrompt,
                systemPrompt: config.params.customSystemPrompt, config: config)
            config.params.videoScript = s
        } catch {
            MPTLog.error("Script generation failed: \(error.localizedDescription)")
        }
    }
}

struct VideoCard: View {
    @EnvironmentObject private var config: ConfigStore

    var body: some View {
        MPTCard(title: "Video Settings") {
            MPTSelectRow(title: "Aspect Ratio",
                         options: [
                             ("9:16", "9:16 Vertical (Recommended)"),
                             ("16:9", "16:9 Landscape"),
                             ("1:1", "1:1 Square")
                         ],
                         selection: $config.params.videoAspectRaw)

            MPTSelectRow(title: "Transition Mode",
                         options: [
                             ("none", "None (Hard Cut)"),
                             ("zoomIn", "Zoom In"),
                             ("zoomOut", "Zoom Out"),
                             ("slideIn", "Slide In"),
                             ("slideOut", "Slide Out")
                         ],
                         selection: $config.params.videoTransitionModeRaw)

            MPTCheckRow(title: "Enable Subtitles", isOn: $config.params.subtitleEnabled)
            MPTSliderRow(title: "Subtitle Position", range: 30...90, step: 5,
                         value: $config.params.customPosition,
                         valueText: "\(Int(config.params.customPosition))% from top")
        }
    }
}

// MARK: - Helper Components
struct MPTCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s3) {
            Text(title)
                .font(MPTStyle.title(16))
                .foregroundColor(MPTStyle.textPrimary)
            content
        }
        .padding(MPTStyle.s3)
        .background(MPTStyle.cardBackground)
        .cornerRadius(MPTStyle.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: MPTStyle.radiusMedium)
                .stroke(MPTStyle.divider, lineWidth: 1)
        )
    }
}

struct MPTTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            Text(title)
                .font(MPTStyle.caption())
                .foregroundColor(MPTStyle.textSecondary)
            TextField(placeholder, text: $text)
                .padding(MPTStyle.s3)
                .background(MPTStyle.controlBackground)
                .cornerRadius(MPTStyle.radiusSmall)
        }
    }
}

struct MPTSelectRow: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            Text(title)
                .font(MPTStyle.caption())
                .foregroundColor(MPTStyle.textSecondary)
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { opt in
                    Text(opt.1).tag(opt.0)
                }
            }
            .pickerStyle(.menu)
            .tint(MPTStyle.textPrimary)
        }
    }
}

struct MPTCheckRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(MPTStyle.body())
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct MPTSliderRow: View {
    let title: String
    let range: ClosedRange<Double>
    let step: Double
    @Binding var value: Double
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            HStack {
                Text(title)
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
                Spacer()
                Text(valueText)
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct MPTMultilineField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var height: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            Text(title)
                .font(MPTStyle.caption())
                .foregroundColor(MPTStyle.textSecondary)
            TextEditor(text: $text)
                .font(MPTStyle.body())
                .frame(height: height)
                .padding(MPTStyle.s2)
                .background(MPTStyle.controlBackground)
                .cornerRadius(MPTStyle.radiusSmall)
            if !placeholder.isEmpty {
                Text(placeholder)
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textTertiary)
            }
        }
    }
}

struct MPTAccentButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MPTStyle.s2) {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MPTStyle.s3)
            .foregroundColor(.white)
            .background(MPTStyle.primary)
            .cornerRadius(MPTStyle.radiusSmall)
        }
        .buttonStyle(.plain)
    }
}
