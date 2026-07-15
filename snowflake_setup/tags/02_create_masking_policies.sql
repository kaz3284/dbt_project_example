-- レベルごとに専用のマスキングポリシーを作成する
--
-- 参考: https://zenn.dev/dataheroes/articles/996125bc1737c1
--
-- タグの値（mask_hash / mask_anonymous）ではなく、
-- クエリを実行しているロールの「クリアランス」でマスキングの要否を判定し、
-- クリアランスが無い場合にタグの値でマスキング方法（hash化 or 匿名化）を出し分ける。
--
-- クリアランスの判定には IS_ROLE_IN_SESSION() を使い、ロールの包含関係（階層）で判別する。
-- ../roles/01_create_masking_clearance_roles.sql で
-- `grant role SECURE_LEVEL_1 to role SECURE_LEVEL_2;` のように上位ロールへ下位ロールを付与しておくことで、
-- SECURE_LEVEL_2 が有効なセッションでは IS_ROLE_IN_SESSION('SECURE_LEVEL_1') も true になり、
-- 「SECURE_LEVEL_2はSECURE_LEVEL_1を包含する」を個別のロール列挙なしで表現できる。
--
-- SECURE_LEVEL_1 ロール: レベル1相当のデータまで平文参照可
-- SECURE_LEVEL_2 ロール: SECURE_LEVEL_1を継承しているため、レベル1・レベル2どちらのデータも平文参照可
-- ロール名・権限体系は運用に合わせて調整してください。

create or replace masking policy tags.secure_level_1_string as (val string) returns string ->
  case
    when is_role_in_session('SECURE_LEVEL_1') then val
    when length(val) = 0 then val
    when system$get_tag_on_current_column('tags.masking_policy_secure_level_1') = 'mask_hash' then sha2(val)
    else '***'
  end;

create or replace masking policy tags.secure_level_2_string as (val string) returns string ->
  case
    when is_role_in_session('SECURE_LEVEL_2') then val
    when length(val) = 0 then val
    when system$get_tag_on_current_column('tags.masking_policy_secure_level_2') = 'mask_hash' then sha2(val)
    else '***'
  end;
