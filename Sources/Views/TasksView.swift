import SwiftUI
import AVKit

/// 任务管理（对应原版任务列表；P2 起完成项可播放/分享 MP4）
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
                        if !t.note.isEmpty {
                            Text(t.note).font(MPTStyle.caption()).foregroundColor(MPTStyle.textSecondary).lineLimit(2)
                        }
                        if !t.error.isEmpty {
                            Text(t.error).font(MPTStyle.caption()).foregroundColor(MPTStyle.danger)
                        }
                        if t.state == MPTConst.taskComplete, let url = validOutput(t) {
                            OutputPlayerRow(url: url)
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

    private func validOutput(_ t: MPTTask) -> URL? {
        guard !t.outputPath.isEmpty,
              FileManager.default.fileExists(atPath: t.outputPath) else { return nil }
        return URL(fileURLWithPath: t.outputPath)
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

/// MP4 结果行：内嵌播放 + 分享（对应原版任务页视频预览）
struct OutputPlayerRow: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s2) {
            VideoPlayer(player: player)
                .frame(height: 150)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: MPTStyle.radiusMedium))
                .onAppear {
                    if player == nil { player = AVPlayer(url: url) }
                }
            HStack(spacing: MPTStyle.s3) {
                Button {
                    if player == nil { player = AVPlayer(url: url) }
                    player?.play()
                } label: {
                    Label("播放", systemImage: "play.fill").font(MPTStyle.body())
                }
                .buttonStyle(.plain)
                ShareLink(item: url) {
                    Label("分享", systemImage: "square.and.arrow.up").font(MPTStyle.body())
                }
                Spacer()
                Text(fileInfo)
                    .font(MPTStyle.caption())
                    .foregroundColor(MPTStyle.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var fileInfo: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64).map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
        return url.lastPathComponent + " · " + size
    }
}
