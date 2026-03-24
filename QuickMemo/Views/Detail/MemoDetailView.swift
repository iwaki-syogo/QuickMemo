import SwiftUI
import SwiftData

struct MemoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let memo: Memo
    @State private var viewModel = MemoDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("タイトル", text: $viewModel.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Divider()

                TextEditor(text: $viewModel.body)
                    .font(.body)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)

                Divider()

                statusSection

                metadataSection
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setMemo(memo, context: modelContext)
        }
        .onDisappear {
            viewModel.save()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                viewModel.save()
            }
        }
    }

    private var statusSection: some View {
        HStack {
            Text("ステータス")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.toggleStatus()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.status == .open ? "circle.fill" : "checkmark.circle.fill")
                        .font(.caption)
                    Text(viewModel.status == .open ? "Open" : "Closed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(viewModel.status == .open ? Color.green : Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (viewModel.status == .open ? Color.green : Color.secondary)
                        .opacity(0.12)
                )
                .clipShape(Capsule())
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("作成日時")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("更新日時")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(memo.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
}
