import SwiftUI
import GoogleMobileAds

struct AdBannerView: View {
    @Environment(StoreKitService.self) private var storeKitService

    var body: some View {
        if !storeKitService.isAdFree {
            BannerAdView()
                .frame(height: 50)
                .background(Color.gray.opacity(0.1))
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = "ca-app-pub-1265529246324725/7315685794"
        banner.delegate = context.coordinator
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

    class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[AdMob] Ad loaded successfully")
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdMob] Failed to load ad: \(error.localizedDescription)")
        }
    }
}
