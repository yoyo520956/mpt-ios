import SwiftUI

/// 设置页（1:1 原版 API Key 分组 + 预设 + 诊断日志）
struct SettingsView: View {
    @EnvironmentObject private var config: ConfigStore
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationView {
            Form {
                Section("LLM") {
                    TextField("Base URL", text: $config.llmBaseURL)
                        .autocapitalization(.none)
                    TextField("模型", text: $config.llmModel)
                        .autocapitalization(.none)
                }
                ForEach(groupNames, id: \.self) { group in
                    Section(group) {
                        ForEach(items(in: group)) { item in
                            SecureField(item.label, text: binding(for: item.id))
                                .autocapitalization(.none)
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
