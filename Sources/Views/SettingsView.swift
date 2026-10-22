import SwiftUI

/// Simplified Settings: Agnes 2.0 config + Model Selection only
struct SettingsView: View {
    @EnvironmentObject private var config: ConfigStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Agnes 2.0 Config") {
                    VStack(alignment: .leading, spacing: MPTStyle.s2) {
                        Text("Base URL")
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                        Text(config.llmBaseURL.isEmpty ? ConfigStore.defaultLLMBaseURL : config.llmBaseURL)
                            .font(MPTStyle.body())
                            .foregroundColor(config.llmBaseURL.isEmpty ? MPTStyle.brand : MPTStyle.textPrimary)

                        Text("API Key (built-in, editable)")
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                        SecureField("Built-in Key", text: $config.llmAPIKey)
                            .textContentType(.password)
                    }
                }

                Section("AI Model Selection") {
                    Picker("Text Model", selection: $config.llmModel) {
                        ForEach(ConfigStore.textModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Picker("Image Model", selection: $config.llmImageModel) {
                        ForEach(ConfigStore.imageModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Picker("Video Model", selection: $config.llmVideoModel) {
                        ForEach(ConfigStore.videoModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Text("Text=Script Generation\nImage=AI Image Gen\nVideo=AI Video Gen")
                        .font(MPTStyle.caption())
                        .foregroundColor(MPTStyle.textSecondary)
                }

                Section("Novel to Video") {
                    Text("Paste novel text for auto-segmented video generation.\nEach segment uses professional prompt templates with Ken Burns effects.")
                        .font(MPTStyle.caption())
                        .foregroundColor(MPTStyle.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: \.cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
