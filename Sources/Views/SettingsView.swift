import SwiftUI

/// 设置页：内置 Agnes 2.0 API 已预填 + 文本/图片/视频三个模型选择
struct SettingsView: View {
    @EnvironmentObject private var config: ConfigStore
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationView {
            Form {
                // ---- Agnes 2.0 默认配置区 ----
                Section("Agnes 2.0（默认已填好）") {
                    VStack(alignment: .leading, spacing: MPTStyle.s2) {
                        Text("Base URL")
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                        Text(config.llmBaseURL.isEmpty ? ConfigStore.defaultLLMBaseURL : config.llmBaseURL)
                            .font(MPTStyle.body())
                            .foregroundColor(config.llmBaseURL.isEmpty ? MPTStyle.brand : MPTStyle.textPrimary)
                        Text("API Key（默认已内置，可改）")
                            .font(MPTStyle.caption())
                            .foregroundColor(MPTStyle.textSecondary)
                        SecureField("内置 Key", text: binding(for: "llm_api_key"))
                            .textContentType(.password)
                    }
                }

                // ---- 模型三件套 ----
                Section("模型（文本 / 图片 / 视频 AI 生成）") {
                    Picker("文本模型", selection: $config.llmModel) {
                        ForEach(ConfigStore.textModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Picker("图片模型", selection: $config.llmImageModel) {
                        ForEach(ConfigStore.imageModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Picker("视频模型（P3 AI 文生视频）", selection: $config.llmVideoModel) {
                        ForEach(ConfigStore.videoModels, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                    Text("文本模型用于：文案 + 关键词生成。\n图片/视频模型在 P3 接入 AI 素材时生效。")
                        .font(MPTStyle.caption())
                        .foregroundColor(MPTStyle.textSecondary)
                }

                // ---- 其余 Key（材料 / 配音 / 发布）----
                ForEach(groupNames, id: \.self) { group in
                    Section(group) {
                        ForEach(items(in: group)) { item in
                            SecureField(item.label, text: binding(for: item.id))
                                .autocapitalization(.none)
                                .textContentType(.password)
                        }
                    }
                }

                Section("诊断日志") {
                    Picker("日志级别", selection: $config.logLevel) {
                        ForEach(["DEBUG", "INFO", "WARNING", "ERROR"], id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    MPTAccentButton(title: "保存并关闭", icon: "checkmark") { dismiss() }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                for item in ConfigStore.keyItems { values[item.id] = config.key(item.id) }
            }
        }
    }

    private var groupNames: [String] {
        var seen: [String] = []
        for item in ConfigStore.keyItems where !seen.contains(item.group) { seen.append(item.group) }
        return seen
    }

    private func items(in group: String) -> [KeyItem] {
        ConfigStore.keyItems.filter { $0.group == group }
    }

    private func binding(for id: String) -> Binding<String> {
        Binding(
            get: { values[id] ?? config.key(id) },
            set: { values[id] = $0; config.setKey(id, $0) }
        )
    }
}
