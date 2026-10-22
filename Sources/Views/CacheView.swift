import SwiftUI

/// 缓存页（对应原版 3 列 metrics + 清理）
struct CacheView: View {
    @EnvironmentObject private var config: ConfigStore
    @State private var count: Int = 0
    @State private var size: String = "0 B"
    @State private var oldest: String = "-"

    var body: some View {
        VStack(alignment: .leading, spacing: MPTStyle.s4) {
            HStack(spacing: MPTStyle.s4) {
                metric("文件数", "\(count)")
                metric("占用空间", size)
                metric("最早文件", oldest)
            }
            MPTAccentButton(title: "清理缓存", icon: "trash") { refresh() }
            Spacer()
        }
        .padding(MPTStyle.s4)
        .navigationTitle("缓存")
        .onAppear { refresh() }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: MPTStyle.s1) {
            Text(title).font(MPTStyle.caption()).foregroundColor(MPTStyle.textSecondary)
            Text(value).font(MPTStyle.title(18)).foregroundColor(MPTStyle.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MPTStyle.s3)
        .background(MPTStyle.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: MPTStyle.radiusMedium).stroke(MPTStyle.border, lineWidth: 1))
    }

    private func refresh() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MPT", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])) ?? []
        count = files.count
        let total = files.reduce(0) { sum, url in
            sum + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        size = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
        let dates = files.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        oldest = dates.min().map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "-"
    }
}
