import SwiftUI

/// 任务管理（对应原版任务列表）
struct TasksView: View {
    @EnvironmentObject private var tasks: TaskManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                if tasks.tasks.isEmpty {
                    Text("暂无任务").font(MPTStyle.body()).foregroundColor(MPTStyle.textSecondary)
                }
                ForEach(tasks.tasks) { t in
                    VStack(alignment: .leading, spacing: MPTStyle.s1) {
                        HStack {
                            Text(t.subject).font(MPTStyle.title(14)).lineLimit(1)
                            Spacer()
                            Text(stateText(t.state))
                                .font(MPTStyle.caption())
                                .foregroundColor(stateColor(t.state))
                        }
                        if t.state == MPTConst.taskProcessing {
                            ProgressView(value: Double(t.progress), total: 100)
                                .tint(MPTStyle.brand)
                        }
                        if !t.error.isEmpty {
                            Text(t.error).font(MPTStyle.caption()).foregroundColor(MPTStyle.danger)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { tasks.remove(t.id) } label: { Label("删除", systemImage: "trash") }
                    }
                }
            }
            .navigationTitle("任务管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func stateText(_ s: Int) -> String {
        switch s {
        case MPTConst.taskComplete: return "完成"
        case MPTConst.taskFailed: return "失败"
        case MPTConst.taskProcessing: return "处理中"
        default: return "排队中"
        }
    }

    private func stateColor(_ s: Int) -> Color {
        switch s {
        case MPTConst.taskComplete: return MPTStyle.brand
        case MPTConst.taskFailed: return MPTStyle.danger
        default: return MPTStyle.textSecondary
        }
    }
}
