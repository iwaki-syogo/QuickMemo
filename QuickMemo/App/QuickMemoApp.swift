import SwiftUI
import SwiftData

@main
struct QuickMemoApp: App {
    @State private var gitHubAccount = GitHubAccount()
    @State private var syncService = SyncService()
    @State private var storeKitService = StoreKitService()
    @State private var showNewMemo = true

    var body: some Scene {
        WindowGroup {
            ContentView(showNewMemo: $showNewMemo)
                .environment(gitHubAccount)
                .environment(syncService)
                .environment(storeKitService)
                .onOpenURL { url in
                    let deepLink = DeepLinkHandler.parse(url: url)
                    switch deepLink {
                    case .newMemo:
                        showNewMemo = true
                    case .githubCallback:
                        break
                    case .unknown:
                        break
                    }
                }
                .task {
                    await storeKitService.checkEntitlements()
                }
        }
        .modelContainer(for: [Memo.self, Label.self])
    }
}
