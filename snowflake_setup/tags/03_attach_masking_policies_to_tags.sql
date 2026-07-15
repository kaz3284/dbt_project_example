-- タグにマスキングポリシーを関連付ける
--
-- 実行ロールには APPLY MASKING POLICY 権限が必要です（例: ACCOUNTADMIN）。
-- これ以降、tags.masking_policy_secure_level_1 / level_2 のいずれかが
-- 付与された列は、対応するポリシーの判定ロジックに従ってマスキングされます。

alter tag tags.masking_policy_secure_level_1 set
  masking policy tags.secure_level_1_string;

alter tag tags.masking_policy_secure_level_2 set
  masking policy tags.secure_level_2_string;
