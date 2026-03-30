import SwiftUI
import SwiftData
import GoogleMobileAds
import os

private let logger = Logger(subsystem: "com.iwakisyogo.QuickMemo", category: "App")

@main
struct QuickMemoApp: App {
    @State private var gitHubAccount = GitHubAccount()
    @State private var syncService = SyncService()
    @State private var storeKitService = StoreKitService()
    @State private var showNewMemo = true

    let modelContainer: ModelContainer

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        do {
            modelContainer = try ModelContainer(for: Memo.self, Label.self)
            logger.notice("ModelContainer initialized successfully")
        } catch {
            logger.error("ModelContainer initialization FAILED: \(error). Creating fresh store.")
            // If migration fails, delete and recreate the store
            let schema = Schema([Memo.self, Label.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

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
        .modelContainer(modelContainer)
    }
}
