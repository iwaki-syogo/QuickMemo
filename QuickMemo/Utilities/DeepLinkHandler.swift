import Foundation

enum DeepLink {
    case newMemo
    case githubCallback(code: String)
    case unknown
}

enum DeepLinkHandler {
    static func parse(url: URL) -> DeepLink {
        guard url.scheme == AppConstants.urlScheme else {
            return .unknown
        }

        switch url.host {
        case "new":
            return .newMemo
        case "github":
            if url.path == "/callback",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                return .githubCallback(code: code)
            }
            return .unknown
        default:
            return .unknown
        }
    }
}
