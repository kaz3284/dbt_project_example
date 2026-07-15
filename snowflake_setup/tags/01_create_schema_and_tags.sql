-- タグベースマスキングポリシー用の準備: スキーマとタグの作成
--
-- 実行前提:
--   - dbtが接続するデータベース（DEV_DB / PROD_DB / TRIAL_DB など）に対して
--     `use database <対象DB>;` を実行してから、このスクリプトを流してください。
--   - 実行ロールには当該データベースへの CREATE SCHEMA 権限が必要です
--     （例: SYSADMIN、または当該DBのオーナーロール）。
--
-- dbt/macros/apply_tag_setting.sql は `tags.<タグ名>` という
-- スキーマ修飾なしの参照でタグを設定するため、
-- タグは必ず「対象データベース」配下の `tags` スキーマに作成する必要があります。

create schema if not exists tags
  comment = 'マスキングポリシー用タグを格納するスキーマ';

-- レベル1: 結合可能な形での保護（hash化など）を想定するタグ
create tag if not exists tags.masking_policy_secure_level_1
  allowed_values 'mask_hash', 'mask_anonymous'
  comment = 'レベル1の情報保護（例: hash化。値の一致による結合は可能）を表すタグ';

-- レベル2: より強い保護（匿名化など）を想定するタグ
create tag if not exists tags.masking_policy_secure_level_2
  allowed_values 'mask_hash', 'mask_anonymous'
  comment = 'レベル2の情報保護（例: 匿名化。値の一致による結合も不可）を表すタグ';

-- 新しいマスキング種別（value）を追加する場合は、
-- 上記 allowed_values と 02_create_masking_policies.sql の CASE 分岐を
-- 両方更新してください。
