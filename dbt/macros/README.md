# タグベースマスキングポリシーの自動適用

このディレクトリのマクロは、モデルの`meta`設定からSnowflakeのマスキングポリシー用タグをカラムへ自動付与する仕組みを提供します。

## 構成

- `apply_tag_setting.sql` — `meta.tag`の設定内容を元に、対象カラムへマスキングポリシーのタグを付与するマクロ。`dbt_project.yml`の`post-hook`から呼び出されます。
- `get_meta_objects.sql` — モデルの各カラムから指定した`meta`キー（既定は`tag`）の設定を収集するヘルパーマクロ。

## 仕組み

1. `models/example/schema.yml` のように、モデルのカラム定義に `meta.tag` でマスキングポリシーの種類（`type: masking_policy`）・タグ名（`name`）・タグ値（`value`）を指定します。

   ```yaml
   columns:
     - name: zip
       meta:
         tag:
           - type: masking_policy
             name: masking_policy_secure_level_2
             value: mask_anonymous
   ```

2. `dbt_project.yml` の `post-hook` で `apply_tag_setting()` マクロがモデル実行後に呼び出されます。
3. `apply_tag_setting` は `get_meta_objects` マクロを使って対象モデルの `meta.tag` を持つカラムを収集し、`alter table/view ... modify column ... set tag tags.<タグ名> = '<タグ値>'` のSQLを発行してSnowflake上のオブジェクトにタグを設定します。

これにより、モデルをビルドするたびに、あらかじめ定義したマスキングポリシー用タグがカラムへ自動的に反映されます。

> 事前にSnowflake側でロール（`DEVELOPER`、`SECURE_LEVEL_1`/`SECURE_LEVEL_2`）、タグ（`tags.masking_policy_secure_level_1` など）、マスキングポリシー（`mask_hash` / `mask_anonymous` など）を作成・アタッチしておく必要があります。これらの定義SQLは [`snowflake_setup/`](../../snowflake_setup/README.md) にまとまっています（`init/` → `roles/` → `tags/` の順で適用）。dbtを実行する前に、接続先のデータベースに対して一度適用してください。
