Welcome to your new dbt project!

## このプロジェクトについて

Snowflakeをウェアハウスとして使用するdbtのサンプルプロジェクトです。

### 主な構成

```
dbt/
├── dbt_project.yml        # プロジェクト設定
├── packages.yml           # dbt_utilsなどのパッケージ依存
├── macros/                # カスタムマクロ（詳細は macros/README.md 参照）
├── seeds/
│   ├── raw_address.csv    # サンプル用の住所生データ
│   └── schema.yml         # シードのカラム定義
└── models/
    └── example/
        ├── mp_address.sql      # サンプルモデル（raw_addressシードを参照）
        └── schema.yml          # モデルのカラム定義
```

> タグベースのマスキングポリシー自動適用の仕組みについては [`macros/README.md`](./macros/README.md) を参照してください。

## セットアップ

このリポジトリには VS Code の Dev Container 設定（`.devcontainer/`）が含まれており、`dbt-snowflake` などの依存関係が入った環境がすぐに使えます。

1. VS Codeで本リポジトリを開き、「Reopen in Container」でDev Containerを起動します。
2. Snowflake接続用の `profiles.yml` を `~/.dbt/` に用意します（`docker-compose.yml` で `~/.dbt` はコンテナにマウントされます）。
3. 接続に必要な環境変数を設定します（`docker-compose.yml` 参照）。
   - `SNOWFLAKE_ACCOUNT`
   - `DBT_ENV_SECRET_SNOWFLAKE_KEY_PASSPHRASE_DEV`
4. コンテナ内で依存パッケージをインストールします。
   ```bash
   dbt deps
   ```

### 接続確認

```bash
dbt debug
```

### Using the starter project

Try running the following commands:
- dbt seed
- dbt run
- dbt test
- dbt docs generate && dbt docs serve


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
