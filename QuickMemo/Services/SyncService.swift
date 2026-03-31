import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class SyncService {
    private let apiClient = GitHubAPIClient()
    var isSyncing = false

    func syncMemo(_ memo: Memo, account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }

        let owner = memo.repositoryOwner ?? account.repositoryOwner
        let repo = memo.repositoryName ?? account.repositoryName

        memo.syncStatus = .pending
        do { try context.save() } catch { print("[QuickMemo] Failed to save pending status: \(error)") }

        do {
            let labelNames = fetchLabelNames(for: memo, context: context)

            if let issueNumber = memo.githubIssueNumber {
                let state = memo.status == .open ? "open" : "closed"
                let issue = try await apiClient.updateIssue(
                    owner: owner,
                    repo: repo,
                    number: issueNumber,
                    title: memo.title,
                    body: memo.body,
                    state: state
                )
                memo.githubIssueURL = issue.htmlURL

                // Always sync labels (including empty array to clear all labels)
                try await apiClient.setIssueLabels(
                    owner: owner,
                    repo: repo,
                    number: issueNumber,
                    labels: labelNames
                )
            } else {
                let issue = try await apiClient.createIssue(
                    owner: owner,
                    repo: repo,
                    title: memo.title,
                    body: memo.body,
                    labels: labelNames
                )
                memo.githubIssueNumber = issue.number
                memo.githubIssueURL = issue.htmlURL
            }

            memo.syncStatus = .synced
            memo.syncError = nil
            memo.lastSyncedAt = Date()
            do { try context.save() } catch { print("[QuickMemo] Failed to save synced status: \(error)") }
        } catch {
            memo.syncStatus = .failed
            memo.syncError = error.localizedDescription
            do { try context.save() } catch { print("[QuickMemo] Failed to save failed status: \(error)") }
        }
    }

    func retryFailedAndPending(account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let pendingRaw = SyncStatus.pending.rawValue
        let failedRaw = SyncStatus.failed.rawValue
        let descriptor = FetchDescriptor<Memo>(
            predicate: #Predicate<Memo> { memo in
                memo.syncStatusRaw == pendingRaw || memo.syncStatusRaw == failedRaw
            }
        )

        guard let memos = try? context.fetch(descriptor) else { return }

        for memo in memos {
            if memo.syncError?.hasPrefix("[transfer]") == true,
               let owner = memo.repositoryOwner,
               let repo = memo.repositoryName {
                await transferMemo(memo, toOwner: owner, repoName: repo, account: account, context: context)
            } else {
                await syncMemo(memo, account: account, context: context)
            }
        }
    }

    func transferMemo(_ memo: Memo, toOwner newOwner: String, repoName newRepo: String, account: GitHubAccount, context: ModelContext) async {
        let oldOwner = memo.repositoryOwner ?? account.repositoryOwner
        let oldRepo = memo.repositoryName ?? account.repositoryName

        memo.syncStatus = .pending
        do { try context.save() } catch { print("[QuickMemo] Failed to save pending status: \(error)") }

        do {
            let labelNames = fetchLabelNames(for: memo, context: context)
            let alreadySameRepo = memo.repositoryOwner == newOwner && memo.repositoryName == newRepo

            // Capture old issue info before intermediate state may clear them
            let oldIssueNumber = memo.githubIssueNumber
            let oldIssueURL = memo.githubIssueURL

            // Close old issue (skip if already pointing to the same repo)
            if !alreadySameRepo, let oldIssueNumber {
                let transferNote = "\n\n---\n> Transferred to [\(newOwner)/\(newRepo)](https://github.com/\(newOwner)/\(newRepo))"
                let oldBody = (memo.body ?? "") + transferNote
                _ = try await apiClient.updateIssue(
                    owner: oldOwner,
                    repo: oldRepo,
                    number: oldIssueNumber,
                    body: oldBody,
                    state: "closed"
                )

                // Persist intermediate state so retry skips the old close
                memo.repositoryOwner = newOwner
                memo.repositoryName = newRepo
                memo.githubIssueNumber = nil
                memo.githubIssueURL = nil
                do { try context.save() } catch {
                    print("[QuickMemo] Failed to save intermediate transfer state: \(error)")
                }
            }

            // Use captured old issue info for the cross-reference link
            let oldNumber = oldIssueNumber ?? 0
            let oldURL = oldIssueURL ?? "https://github.com/\(oldOwner)/\(oldRepo)"
            let originNote = "\n\n---\n> Transferred from [\(oldOwner)/\(oldRepo)#\(oldNumber)](\(oldURL))"
            let newBody = (memo.body ?? "") + originNote
            let newIssue = try await apiClient.createIssue(
                owner: newOwner,
                repo: newRepo,
                title: memo.title,
                body: newBody,
                labels: labelNames
            )

            // Update memo properties
            memo.githubIssueNumber = newIssue.number
            memo.githubIssueURL = newIssue.htmlURL
            memo.repositoryOwner = newOwner
            memo.repositoryName = newRepo
            memo.syncStatus = .synced
            memo.syncError = nil
            memo.lastSyncedAt = Date()

            // Best-effort label setting (including empty to clear labels)
            try? await apiClient.setIssueLabels(
                owner: newOwner,
                repo: newRepo,
                number: newIssue.number,
                labels: labelNames
            )

            do { try context.save() } catch { print("[QuickMemo] Failed to save after transfer: \(error)") }
        } catch {
            memo.syncStatus = .failed
            memo.syncError = "[transfer] " + error.localizedDescription
            do { try context.save() } catch { print("[QuickMemo] Failed to save failed status: \(error)") }
        }
    }

    func importIssues(account: GitHubAccount, context: ModelContext) async {
        guard account.isLinked, account.hasRepository else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        let owner = account.repositoryOwner
        let repo = account.repositoryName

        do {
            let issues = try await apiClient.fetchIssues(owner: owner, repo: repo, state: "open")

            // Fetch existing issue numbers to avoid duplicates
            let descriptor = FetchDescriptor<Memo>()
            let existingMemos = (try? context.fetch(descriptor)) ?? []
            let existingIssueNumbers = Set(existingMemos.compactMap(\.githubIssueNumber))

            // Build mutable label lookup by githubID so missing labels can be created
            let labelDescriptor = FetchDescriptor<Label>()
            var labelsByGithubID: [Int: Label] = Dictionary(
                uniqueKeysWithValues: ((try? context.fetch(labelDescriptor)) ?? []).map { ($0.githubID, $0) }
            )

            for issue in issues {
                // Skip pull requests (GitHub Issues API includes PRs — PRs have /pull/ in URL)
                guard issue.htmlURL.contains("/issues/") else { continue }
                guard !existingIssueNumbers.contains(issue.number) else { continue }

                let memo = Memo(
                    title: issue.title,
                    body: issue.body,
                    status: issue.state == "open" ? .open : .closed,
                    githubIssueNumber: issue.number,
                    githubIssueURL: issue.htmlURL,
                    syncStatus: .synced,
                    lastSyncedAt: Date(),
                    repositoryOwner: owner,
                    repositoryName: repo
                )

                // Resolve or create labels by githubID so colors and names display correctly
                if let issueLabels = issue.labels {
                    let resolvedIDs = issueLabels.map { ghLabel -> UUID in
                        if let existing = labelsByGithubID[ghLabel.id] {
                            return existing.id
                        }
                        let newLabel = Label(githubID: ghLabel.id, name: ghLabel.name, color: ghLabel.color)
                        context.insert(newLabel)
                        labelsByGithubID[ghLabel.id] = newLabel
                        return newLabel.id
                    }
                    memo.labelIDs = resolvedIDs
                }

                context.insert(memo)
            }

            try context.save()
        } catch {
            print("[QuickMemo] Failed to import issues: \(error)")
        }
    }

    private func fetchLabelNames(for memo: Memo, context: ModelContext) -> [String] {
        guard !memo.labelIDs.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Label>()
        guard let allLabels = try? context.fetch(descriptor) else { return [] }

        return allLabels
            .filter { memo.labelIDs.contains($0.id) }
            .map(\.name)
    }
}
