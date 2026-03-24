import SwiftUI

struct AdBannerView: View {
    @Environment(StoreKitService.self) private var storeKitService

    var body: some View {
        if !storeKitService.isAdFree {
            bannerPlaceholder
        }
    }

    private var bannerPlaceholder: some View {
        Text("広告スペース")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.secondarySystemBackground))
    }
}
