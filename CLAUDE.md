# QuickMemo

## Overview
QuickMemo is a fast, lightweight memo app for iOS with GitHub sync and widget support.

## Tech Stack
- **UI**: SwiftUI
- **Data**: SwiftData
- **Minimum Deployment Target**: iOS 17.0
- **Monetization**: StoreKit 2 (IAP) + Ad banners

## Build
```bash
xcodegen generate && xcodebuild build -scheme QuickMemo
```

## Project Structure
- `QuickMemo/` — Main app target
- `QuickMemoWidget/` — WidgetKit extension
- `docs/` — Documentation (committed to Git)

## Configuration
- **GitHub OAuth**: Credentials stored in `GitHub.xcconfig` (listed in `.gitignore`, never commit)
- See `GitHub.xcconfig.example` for the template
- Setup instructions: `docs/GITHUB_OAUTH_SETUP.md`

## Known Issues / Gotchas
- **SwiftUI.Label vs Models.Label**: The app has a `Label` model that conflicts with `SwiftUI.Label`. Always use explicit module prefixes when both are in scope (e.g., `QuickMemo.Label` for the model).

## Conventions
- Code comments and commit messages in English
- UI strings: Japanese (primary) + English localizations
