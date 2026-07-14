# Dev Container

このディレクトリは、dbt(dbt-snowflake)の実行環境と、Claude Code(CLI + VS Code拡張)をVS Code Dev Container上に構築するための定義です。

## 構成ファイル

```
.devcontainer/
├── .devcontainer.json       # Dev Container本体の設定
├── Dockerfile               # ベースイメージ（Python + dbt-snowflake）
├── docker-compose.yml       # コンテナ定義（共通設定・環境変数・基本マウント）
├── docker-compose.local.yml # ローカル開発用の追加マウント（gitconfig、SSH agent、gnupg等）
└── requirements.txt         # pipでインストールするパッケージ（dbt-snowflake）
```

## 前提条件

- Docker Desktop がインストール・起動していること
- VS Code に [Dev Containers拡張](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) がインストールされていること
- ホスト側に以下が存在すること（`docker-compose.yml` / `docker-compose.local.yml` でコンテナにマウントされます）
  - `~/.dbt`（`profiles.yml` など。`dbt/profiles.yml.example` を参考にホスト側で用意してください）
  - `~/.aws`
  - `~/.ssh`
  - `~/.gnupg`
  - `~/.gitconfig`
- Snowflake接続用の環境変数がホスト側のシェルで設定されていること（`docker-compose.yml` の `environment` で引き継がれます）
  - `SNOWFLAKE_ACCOUNT`
  - `DBT_ENV_SECRET_SNOWFLAKE_KEY_PASSPHRASE_DEV`

## 起動方法

1. VS Codeでこのリポジトリを開く
2. コマンドパレット(`Cmd+Shift+P`)から **Dev Containers: Reopen in Container** を実行
   - 初回はイメージのビルドとfeatureのインストールが走るため数分かかります
   - 通知が出た場合は「Reopen in Container」を選択してもOKです
3. コンテナが起動したら、ターミナルは自動的に `/workspace` (リポジトリルート) を指します

リビルドが必要な場合（Dockerfileや`.devcontainer.json`を変更した場合）は、コマンドパレットから **Dev Containers: Rebuild Container** を実行してください。

## Claude Codeの利用

このDev ContainerにはClaude Code CLIとVS Code拡張(`anthropic.claude-code`)が組み込まれています。

- CLI本体は [`ghcr.io/anthropics/devcontainer-features/claude-code`](https://github.com/anthropics/devcontainer-features) featureでインストールされます（Dockerfileには焼き込んでいないため、ホスト側の通常開発には一切影響しません）。
- 認証情報(`~/.claude`)は名前付きボリューム(`claude-code-config-${devcontainerId}`)に永続化されます。**コンテナをリビルドしても再ログインは不要**ですが、このリポジトリを初めてDev Containerで開いたときだけ、ターミナルで一度ログインしてください。

  ```bash
  claude
  # または
  claude login
  ```

- APIキー方式で認証したい場合は、`.devcontainer.json` 内でコメントアウトされている以下の設定を有効にし、ホスト側で `ANTHROPIC_API_KEY` を環境変数として設定してください（キーをファイルに直接書かないでください）。

  ```jsonc
  "remoteEnv": {
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  }
  ```

## 補足・注意事項

- `docker-compose.local.yml` のSSH agentソケットのマウント(`/run/host-services/ssh-auth.sock`)は **Docker Desktop for Mac** 前提のパスです。他OSで開発する場合は該当箇所の見直しが必要です。
- このDev Containerは `vscode` ユーザーにパスワードなしsudoが付与された標準構成です。隔離性を高めたい場合（例: `claude --dangerously-skip-permissions` を使う運用等）は、追加のファイアウォール設定などのハードニングを検討してください。
