# Snowflake側マスキングポリシー設定

`dbt/macros/apply_tag_setting.sql` が前提とする、Snowflake側の環境構築・ロール・タグ・マスキングポリシーの定義一式です。
dbtプロジェクトの一部ではなく、Snowflake上に**事前に一度だけ**適用しておく管理者作業のためのSQLです
（`dbt run` 実行前にこれが無いと `Schema 'XXXX_DB.TAGS' does not exist or not authorized.` のようなエラーになります）。

## 構成

目的の異なるSQLをディレクトリで分けています。

- `init/` — アカウントの初回環境構築（アカウント全体で一度だけ実行）
  - `01_create_warehouse_and_database.sql` — ウェアハウス（`DEVELOPER_WH`）・データベース（`TRIAL_DB`）を作成
  - `02_create_developer_role.sql` — dbtを実行するロール（`DEVELOPER`）を作成し、ウェアハウス・データベースへの権限を付与
  - `03_setup_keypair_auth.sql` — キーペア認証（`profiles.yml`の`private_key_path`）用の公開鍵をユーザーへ登録
- `roles/` — マスキングポリシーのクリアランス用ロールの作成（アカウント全体で一度だけ実行）
  - `01_create_masking_clearance_roles.sql` — クリアランス用ロール（`SECURE_LEVEL_0` / `SECURE_LEVEL_1` / `SECURE_LEVEL_2`）を作成し、
    `SECURE_LEVEL_2 ⊃ SECURE_LEVEL_1 ⊃ SECURE_LEVEL_0` の1本のロール階層を組む。
    `DEVELOPER`（dbt実行ロール）にも`SECURE_LEVEL_2`を付与し、マスキング対象カラムを平文参照できるようにする。
- `tags/` — タグ・マスキングポリシーの作成とアタッチ（dbtが接続する**データベースごと**に実行）
  - `01_create_schema_and_tags.sql` — `tags` スキーマとタグオブジェクトを作成
  - `02_create_masking_policies.sql` — マスキングポリシーを作成
  - `03_attach_masking_policies_to_tags.sql` — タグにマスキングポリシーを関連付け
  - `04_grants.sql` — dbt実行ロール（`DEVELOPER`）へタグ付与に必要な権限を付与

## 前提

- `models/example/schema.yml` の `meta.tag` で使われているタグ名・値と一致させています。
  - タグ: `tags.masking_policy_secure_level_1`, `tags.masking_policy_secure_level_2`
  - 値: `mask_hash`（hash化・結合可）, `mask_anonymous`（匿名化・結合不可）
- `init/`・`roles/` はアカウント全体で一度だけ実行すれば十分です。
- `tags/` はdbtが接続する**データベースごと**（`profiles.yml` の `DEV_DB` / `PROD_DB` や、実際の `TRIAL_DB` など）に
  適用する必要があります。タグはデータベース内の `tags` スキーマに作成され、
  マクロもデータベース修飾なしで `tags.<タグ名>` を参照するためです。

## 実行方法

Snowsight や SnowSQL でディレクトリ・番号順に実行してください。

### 1. 初回環境構築（`init/`。アカウント全体で一度だけ）

1. `init/01_create_warehouse_and_database.sql` — ウェアハウス・データベースを作成（SYSADMIN/ACCOUNTADMIN相当）
2. `init/02_create_developer_role.sql` — `DEVELOPER`ロールを作成し、ウェアハウス・データベースへの権限を付与（ACCOUNTADMIN相当）
3. `init/03_setup_keypair_auth.sql` — キーペア認証用の公開鍵をユーザーへ登録（ACCOUNTADMIN相当）

### 2. ロールの作成（`roles/`。アカウント全体で一度だけ）

```sql
use role securityadmin;
```

1. `roles/01_create_masking_clearance_roles.sql` — `SECURE_LEVEL_0`/`SECURE_LEVEL_1`/`SECURE_LEVEL_2`ロールを作成・階層化し、
   `SECURE_LEVEL_0`へテーブル参照の基本権限を、`DEVELOPER`へ`SECURE_LEVEL_2`（マスキング除外）を付与

### 3. タグ・マスキングポリシーの作成（`tags/`。対象データベースごと）

```sql
use database trial_db;  -- dbtが接続するデータベースに合わせて変更
```

1. `tags/01_create_schema_and_tags.sql` — `tags` スキーマとタグオブジェクトを作成（SYSADMIN相当の権限）
2. `tags/02_create_masking_policies.sql` — マスキングポリシーを作成（SECURITYADMIN/ACCOUNTADMIN相当）
3. `tags/03_attach_masking_policies_to_tags.sql` — タグにマスキングポリシーを関連付け（ACCOUNTADMIN相当。APPLY MASKING POLICY権限が必要）
4. `tags/04_grants.sql` — dbt実行ロール（`DEVELOPER`）へタグ付与に必要な権限を付与（SECURITYADMIN/ACCOUNTADMIN相当）

## 仕組み

[こちらの記事](https://zenn.dev/dataheroes/articles/996125bc1737c1) の構成に合わせ、タグのレベル（level_1 / level_2）ごとに
専用のマスキングポリシーを用意し、クエリを実行しているロールの「クリアランス」でマスキングの要否を判定します。

- `tags.secure_level_1_string` — `IS_ROLE_IN_SESSION('SECURE_LEVEL_1')` が true なら平文参照可
- `tags.secure_level_2_string` — `IS_ROLE_IN_SESSION('SECURE_LEVEL_2')` が true なら平文参照可

クリアランスの判定はロールの列挙ではなく**ロールの包含関係**で行います。
`roles/01_create_masking_clearance_roles.sql` で
`SECURE_LEVEL_2 ⊃ SECURE_LEVEL_1 ⊃ SECURE_LEVEL_0` という1本のロール階層を組んでいるため、
`SECURE_LEVEL_2` を有効化したセッションは `SECURE_LEVEL_1`（と`SECURE_LEVEL_0`）を継承しており、
`IS_ROLE_IN_SESSION('SECURE_LEVEL_1')` も true になります（＝レベル1はレベル2に含まれる）。
`SECURE_LEVEL_0` はマスキング対象のテーブルを参照するための基本のSELECT/USAGE権限のみを持ち、
マスキング自体は除外されない（＝常にマスクされた値を見る）役割です。

クリアランスが無いロールから参照された場合は、`SYSTEM$GET_TAG_ON_CURRENT_COLUMN()` で
そのカラムに設定されているタグの**値**を読み取り、`mask_hash` ならハッシュ化（`sha2`）、
それ以外（`mask_anonymous` など）は固定文字列 `'***'` にマスクします。空文字列はそのまま通します。

- `roles/01_create_masking_clearance_roles.sql` では `DEVELOPER`（dbt実行ロール）に`SECURE_LEVEL_2`を付与しています。
  そのためdbtがモデルをビルド・クエリする際は上位クリアランスとしてマスキング対象カラムも平文で扱われます
  （マスキングはdbtの外でこれらのテーブルを参照する、より低い権限のロール向けの制御です）。
- `SECURE_LEVEL_0` / `SECURE_LEVEL_1` / `SECURE_LEVEL_2` は平文参照用のクリアランスロールです。
  実際にどのユーザー・ロールへ割り当てるかは `roles/01_create_masking_clearance_roles.sql` 内の例を
  組織のロール階層に合わせて調整してください。
- 対象カラム（prefecture, city, zip, address, tel, fax）はすべて文字列型のため、文字列用ポリシーのみ用意しています。
  数値・日付型の列にタグ付けする場合は同様のポリシーを追加してください。

## 新しいマスキング種別を追加する場合

1. `tags/01_create_schema_and_tags.sql` の `allowed_values` に新しい値を追加
2. `tags/02_create_masking_policies.sql` の `case` 文に対応する分岐を追加
3. `schema.yml` の `meta.tag` で新しい `value` を指定
