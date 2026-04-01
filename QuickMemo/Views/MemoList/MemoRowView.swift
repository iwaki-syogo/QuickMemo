import SwiftUI

struct MemoRowView: View {
    let memo: Memo
    var labels: [Label] = []
    var showRepository: Bool = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if showRepository, let owner = memo.repositoryOwner, let repo = memo.repositoryName {
                    Text("\(owner)/\(repo)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(labels, id: \.id) { label in
                            Text(label.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: label.color).opacity(0.2))
                                .foregroundStyle(Color(hex: label.color))
                                .clipShape(Capsule())
                        }
                    }
                }

                Text(DateFormatting.relativeString(from: memo.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if memo.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}
