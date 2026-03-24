import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MemoListViewModel()

    var body: some View {
        Group {
            if viewModel.pinnedMemos.isEmpty && viewModel.otherMemos.isEmpty {
                emptyStateView
            } else {
                memoList
            }
        }
        .navigationTitle("QuickMemo")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    InputView()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.fetchMemos()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("メモがありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("右上のボタンから新規メモを作成できます")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var memoList: some View {
        List {
            if !viewModel.pinnedMemos.isEmpty {
                Section("ピン留め") {
                    ForEach(viewModel.pinnedMemos, id: \.id) { memo in
                        NavigationLink {
                            MemoDetailView(memo: memo)
                        } label: {
                            MemoRowView(memo: memo)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.togglePin(memo)
                            } label: {
                                SwiftUI.Label("ピン解除", systemImage: "pin.slash")
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteMemo(memo)
                            } label: {
                                SwiftUI.Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                ForEach(viewModel.otherMemos, id: \.id) { memo in
                    NavigationLink {
                        MemoDetailView(memo: memo)
                    } label: {
                        MemoRowView(memo: memo)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            viewModel.togglePin(memo)
                        } label: {
                            SwiftUI.Label("ピン留め", systemImage: "pin")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteMemo(memo)
                        } label: {
                            SwiftUI.Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
