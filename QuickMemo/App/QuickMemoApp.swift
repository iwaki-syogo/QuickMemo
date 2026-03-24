import SwiftUI
import SwiftData

@main
struct QuickMemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Memo.self, Label.self])
    }
}
