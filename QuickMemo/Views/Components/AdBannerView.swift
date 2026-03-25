import SwiftUI
import GoogleMobileAds

struct AdBannerView: View {
    @Environment(StoreKitService.self) private var storeKitService

    var body: some View {
        if !storeKitService.isAdFree {
            BannerAdView()
                .frame(height: 50)
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        // Test ad unit ID (replace before production release)
        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        if uiView.rootViewController == nil {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                uiView.rootViewController = rootVC
                uiView.load(GADRequest())
            }
        }
    }
}
