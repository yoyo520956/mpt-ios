import Foundation
import SwiftUI

/// 任务队列（对应原版 app/services/task.py + state.py）
struct MPTTask: Identifiable, Codable, Equatable {
    var id: String
    var subject: String
    var state: Int = MPTConst.taskProcessing
    var progress: Int = 0
    var createdAt: Date = Date()
    var outputPath: String = ""
    var error: String = ""
}

final class TaskManager: ObservableObject {
    static let shared = TaskManager()
    @Published var tasks: [MPTTask] = []

    private let storeURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MPT", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tasks.json")
    }()

    private init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let arr = try? JSONDecoder().decode([MPTTask].self, from: data) else { return }
        tasks = arr
    }

    func save() {
        if let data = try? JSONEncoder().encode(tasks) {
            try? data.write(to: storeURL)
        }
    }

    @discardableResult
    func create(subject: String) -> MPTTask {
        let t = MPTTask(id: UUID().uuidString, subject: subject)
        tasks.insert(t, at: 0)
        save()
        return t
    }

    func update(_ id: String, state: Int? = nil, progress: Int? = nil, outputPath: String? = nil, error: String? = nil) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        if let state { tasks[idx].state = state }
        if let progress { tasks[idx].progress = progress }
        if let outputPath { tasks[idx].outputPath = outputPath }
        if let error { tasks[idx].error = error }
        save()
    }

    func remove(_ id: String) {
        tasks.removeAll { $0.id == id }
        save()
    }
}
