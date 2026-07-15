-- dbt実行ロールへの権限付与

-- dbt/macros/apply_tag_setting.sql が発行する
-- `alter table/view ... modify column ... set tag tags.xxx = 'yyy'`
-- を実行するために、対象タグへの APPLY 権限が必要。
grant apply on tag tags.masking_policy_secure_level_1 to role DEVELOPER;
grant apply on tag tags.masking_policy_secure_level_2 to role DEVELOPER;

-- tags スキーマ自体への参照権限
grant usage on schema tags to role DEVELOPER;
