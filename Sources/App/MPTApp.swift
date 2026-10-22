import SwiftUI

@main
struct MoneyPrinterTurboApp: App {
    @StateObject private var config = ConfigStore.shared
    @StateObject private var tasks = TaskManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(config)
                .environmentObject(tasks)
                .tint(MPTStyle.primary)
        }
    }
}
