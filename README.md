# dbtのexampleプロジェクト

Snowflakeを利用するdbtプロジェクトのサンプルリポジトリです。VS Codeの Dev Container で開発環境を構築し、`dbt/` 配下がdbtプロジェクト本体になっています。

## リポジトリ構成

```
.
├── .devcontainer/   # VS Code Dev Container定義（dbt-snowflake実行環境）
└── dbt/             # dbtプロジェクト本体（詳細は dbt/README.md 参照）
```

- dbtプロジェクトのセットアップやモデル構成については [`dbt/README.md`](./dbt/README.md) を参照してください。
- タグベースのマスキングポリシー自動適用の仕組みについては [`dbt/macros/README.md`](./dbt/macros/README.md) を参照してください。

## dbtの基本的な使い方

コマンドは `dbt/` ディレクトリ内（`dbt_project.yml` があるディレクトリ）で実行します。

```bash
cd dbt
```

### 依存パッケージのインストール

`packages.yml` に定義したパッケージ（dbt_utilsなど）をインストールします。モデルを実行する前に一度実行してください。

```bash
dbt deps
```

### 接続確認

`profiles.yml` の設定内容でSnowflakeに接続できるか確認します。

```bash
dbt debug
```

### シードデータの投入

`seeds/` 配下のCSVをSnowflake上にテーブルとして投入します。`mp_address` モデルはこのシード（`raw_address`）を参照しているため、`dbt run` の前に一度実行してください。

```bash
dbt seed
```

### モデルのビルド（実行）

`models/` 配下のSQLモデルを実行し、テーブル・ビューとしてSnowflake上に作成します。

```bash
dbt run
```

特定のモデルのみ実行したい場合は `--select` を使います。

```bash
dbt run --select mp_address
```

### テストの実行

`schema.yml` などに定義したテスト（not_null、uniqueなど）を実行します。

```bash
dbt test
```

### ドキュメントの生成・閲覧

モデルやカラムの説明、依存関係（Lineage）をブラウザで確認できます。

```bash
dbt docs generate
dbt docs serve
```

### クリーンアップ

`target/`・`dbt_packages/` など、生成物を削除します。

```bash
dbt clean
```

## 参考リンク

- [dbtドキュメント](https://docs.getdbt.com/docs/introduction)
- [dbt Discourse（よくある質問）](https://discourse.getdbt.com/)
- [dbt Community Slack](https://community.getdbt.com/)
