# GitHub OAuth App Setup Guide

## 1. Create a GitHub OAuth App

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Click **OAuth Apps** in the left sidebar
3. Click **New OAuth App**
4. Fill in the following:
   - **Application name**: `QuickMemo`
   - **Homepage URL**: `https://github.com` (placeholder)
   - **Authorization callback URL**: `quickmemo://github/callback`
5. Click **Register application**

## 2. Get Client ID and Client Secret

1. After creating the app, you will see the **Client ID** on the app's page
2. Click **Generate a new client secret** to create a Client Secret
3. **Copy both values immediately** — the Client Secret is only shown once

## 3. Configure GitHub.xcconfig

1. Open `GitHub.xcconfig` in the project root (created from `GitHub.xcconfig.example`)
2. Replace the placeholder values:

```
GITHUB_CLIENT_ID = your_actual_client_id
GITHUB_CLIENT_SECRET = your_actual_client_secret
```

## Important Notes

- **NEVER commit `GitHub.xcconfig` to source control.** It is already listed in `.gitignore`.
- If you need to share credentials with team members, use a secure channel (not Git).
- For production, consider using a server-side proxy for the OAuth token exchange instead of bundling the Client Secret in the app binary.
