# GitHub Integration Setup

QuickMemo uses a **Personal Access Token (PAT)** to sync memos with GitHub Issues.

## Creating a Personal Access Token

### Classic Token

1. Go to [GitHub Settings > Developer settings > Personal access tokens (classic)](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Set a descriptive name (e.g., "QuickMemo")
4. Select the **`repo`** scope
5. Click **Generate token**
6. Copy the token and paste it into QuickMemo's Settings > GitHub連携

### Fine-grained Token

1. Go to [GitHub Settings > Developer settings > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new)
2. Set a descriptive name and expiration
3. Under **Repository access**, select the specific repository you want to sync with
4. Under **Permissions > Repository permissions**, set **Issues** to **Read and write**
5. Click **Generate token**
6. Copy the token and paste it into QuickMemo's Settings > GitHub連携
