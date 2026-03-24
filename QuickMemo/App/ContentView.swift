import SwiftUI

struct ContentView: View {
    @Binding var showNewMemo: Bool

    var body: some View {
        NavigationStack {
            MemoListView()
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
                .navigationDestination(isPresented: $showNewMemo) {
                    InputView()
                }
        }
    }
}
