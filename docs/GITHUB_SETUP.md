# GitHub 連携の設定方法

Issuepad は **Personal Access Token（PAT）** を使用して、メモを GitHub Issues と同期します。

## Personal Access Token の作成

### クラシックトークン

1. [GitHub Settings > Developer settings > Personal access tokens (classic)](https://github.com/settings/tokens) にアクセスします
2. **Generate new token (classic)** をクリックします
3. わかりやすい名前を設定します（例：「Issuepad」）
4. **`repo`** スコープを選択します
5. **Generate token** をクリックします
6. トークンをコピーして、Issuepad の設定 > GitHub連携に貼り付けます

### Fine-grained トークン

1. [GitHub Settings > Developer settings > Fine-grained tokens](https://github.com/settings/personal-access-tokens/new) にアクセスします
2. わかりやすい名前と有効期限を設定します
3. **Repository access** で、同期したい特定のリポジトリを選択します
4. **Permissions > Repository permissions** で、**Issues** を **Read and write** に設定します
5. **Generate token** をクリックします
6. トークンをコピーして、Issuepad の設定 > GitHub連携に貼り付けます
