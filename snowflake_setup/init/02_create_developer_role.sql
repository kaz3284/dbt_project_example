-- dbt実行ロール（DEVELOPER）の作成と権限付与
--
-- アカウントの初回環境構築時に一度だけ実行します。
-- 01_create_warehouse_and_database.sql で作成したウェアハウス・データベースを前提とします。

use role accountadmin;

create role if not exists developer;

-- ウェアハウス・データベースへの利用権限
grant usage on warehouse developer_wh to role developer;
grant all on database trial_db to role developer;

-- DEVELOPERロールが新規データベースを作成できるようにする
grant create database on account to role developer;

-- ロール階層: SYSADMIN配下のロールとして運用する
grant role developer to role sysadmin;
revoke role developer from role accountadmin;

-- dbtを実行するユーザーへの割り当て例
-- grant role developer to user <ユーザー名>;
