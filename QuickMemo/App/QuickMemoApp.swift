import SwiftUI
import SwiftData

@main
struct QuickMemoApp: App {
    @State private var gitHubAccount = GitHubAccount()
    @State private var syncService = SyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(gitHubAccount)
                .environment(syncService)
                .onOpenURL { url in
                    // GitHub OAuth callback is handled by ASWebAuthenticationSession
                }
        }
        .modelContainer(for: [Memo.self, Label.self])
    }
}
