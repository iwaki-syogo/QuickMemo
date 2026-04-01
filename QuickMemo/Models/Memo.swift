import Foundation
import SwiftData

enum MemoStatus: String, Codable {
    case open
    case closed
    case merged
}

enum SyncStatus: String, Codable {
    case synced
    case pending
    case failed
    case notLinked
}

@Model
class Memo {
    var id: UUID
    var title: String
    var body: String?
    var isPinned: Bool
    var status: MemoStatus
    var createdAt: Date
    var updatedAt: Date
    var githubIssueNumber: Int?
    var githubIssueURL: String?
    @Attribute(originalName: "syncStatus") var syncStatusRaw: String

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .notLinked }
        set { syncStatusRaw = newValue.rawValue }
    }
    var syncError: String?
    var lastSyncedAt: Date?
    var labelIDs: [UUID]
    var repositoryOwner: String?
    var repositoryName: String?

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String? = nil,
        isPinned: Bool = false,
        status: MemoStatus = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        githubIssueNumber: Int? = nil,
        githubIssueURL: String? = nil,
        syncStatus: SyncStatus = .notLinked,
        syncError: String? = nil,
        lastSyncedAt: Date? = nil,
        labelIDs: [UUID] = [],
        repositoryOwner: String? = nil,
        repositoryName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.isPinned = isPinned
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.githubIssueNumber = githubIssueNumber
        self.githubIssueURL = githubIssueURL
        self.syncStatusRaw = syncStatus.rawValue
        self.syncError = syncError
        self.lastSyncedAt = lastSyncedAt
        self.labelIDs = labelIDs
        self.repositoryOwner = repositoryOwner
        self.repositoryName = repositoryName
    }
}
