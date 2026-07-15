-- マスキングポリシーの平文参照クリアランス用ロールと、その包含関係の作成
--
-- SECURE_LEVEL_2 ⊃ SECURE_LEVEL_1 ⊃ SECURE_LEVEL_0 という1本のロール階層にする。
-- 上位ロールへ下位ロールを付与（grant role <下位> to role <上位>）しておくことで、
-- 「上位ロールは下位ロールの権限を包含する」という関係になり、
-- masking policy側は IS_ROLE_IN_SESSION('SECURE_LEVEL_1') だけで
-- SECURE_LEVEL_1 / SECURE_LEVEL_2 のどちらのロールが有効でもtrueと判定できる。
-- また、SECURE_LEVEL_0へ付与した基本のSELECT/USAGE権限もSECURE_LEVEL_1/2へ自動的に伝播する。
--
-- SECURE_LEVEL_0: マスキング対象データを閲覧できる（マスク済みの値のみ参照可能）
-- SECURE_LEVEL_1: SECURE_LEVEL_1タグの列を平文参照可（SECURE_LEVEL_0の権限も継承）
-- SECURE_LEVEL_2: SECURE_LEVEL_1・SECURE_LEVEL_2タグの列を平文参照可（上位クリアランス）
--
-- 実行ロールには CREATE ROLE / MANAGE GRANTS 権限が必要です（例: SECURITYADMIN）。

create role if not exists SECURE_LEVEL_0;
create role if not exists SECURE_LEVEL_1;
create role if not exists SECURE_LEVEL_2;

-- SECURE_LEVEL_1 は SECURE_LEVEL_0 を、SECURE_LEVEL_2 は SECURE_LEVEL_1 を包含する
grant role SECURE_LEVEL_0 to role SECURE_LEVEL_1;
grant role SECURE_LEVEL_1 to role SECURE_LEVEL_2;

-- dbt実行ロール（DEVELOPER）は上位クリアランスを持ち、マスキング対象カラムも平文で参照できる
grant role SECURE_LEVEL_2 to role DEVELOPER;

-- SECURE_LEVEL_0への基本権限（テーブルを参照できないとマスキングの有無に関わらずクエリ自体ができないため付与）。
-- SECURE_LEVEL_1/2はロール階層でこれを継承する。
use role sysadmin;

grant usage on warehouse developer_wh to role SECURE_LEVEL_0;

grant usage on database trial_db to role SECURE_LEVEL_0;
grant usage on all schemas in database trial_db to role SECURE_LEVEL_0;
grant select on all tables in database trial_db to role SECURE_LEVEL_0;
grant usage on future schemas in database trial_db to role SECURE_LEVEL_0;
grant select on future tables in database trial_db to role SECURE_LEVEL_0;
