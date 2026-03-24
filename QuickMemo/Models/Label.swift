import Foundation
import SwiftData

@Model
class Label {
    var id: UUID
    var githubID: Int
    var name: String
    var color: String
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        githubID: Int = 0,
        name: String = "",
        color: String = "",
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.githubID = githubID
        self.name = name
        self.color = color
        self.lastUsedAt = lastUsedAt
    }
}
