import SwiftUI

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

                        Text("API Key (built-in)")
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                        SecureField("Built-in Key", text: $config.llmAPIKey)
                            .textContentType(.password)
                    }
                }

                Section("Model Selection") {
                    Picker("Text Model", selection: $config.llmModel) {
                        ForEach(ConfigStore.textModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
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
