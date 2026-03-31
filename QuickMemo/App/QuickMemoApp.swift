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
            logger.error("ModelContainer initialization FAILED: \(error). Deleting store and recreating.")
            let config = ModelConfiguration()
            let storeURL = config.url
            let storeDir = storeURL.deletingLastPathComponent()
            let storeName = storeURL.lastPathComponent
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = storeDir.appending(path: storeName + suffix)
                try? FileManager.default.removeItem(at: fileURL)
            }
            logger.notice("Deleted old store at \(storeURL.path)")
            do {
                modelContainer = try ModelContainer(for: Memo.self, Label.self)
                logger.notice("ModelContainer recreated successfully after store deletion")
            } catch {
                fatalError("Failed to create ModelContainer even after store deletion: \(error)")
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
