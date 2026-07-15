-- キーペア認証の設定
--
-- profiles.yml(.example) は private_key_path によるキーペア認証を前提としています。
-- 事前にローカル（Snowflake外）で秘密鍵・公開鍵を生成してください。
--
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
--   openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
--
-- rsa_key.p8 は dbtの private_key_path が指す場所に安全に配置し、Gitには含めないでください。
-- rsa_key.pub の中身（-----BEGIN/END PUBLIC KEY----- の行を除いた本体のみ）を
-- 下記のロールに登録します。

use role accountadmin;

alter user <ユーザー名> set rsa_public_key='<rsa_key.pubの中身をここに貼り付け>';

-- 鍵をローテーションする場合は rsa_public_key_2 を使うと無停止で切り替えられる
-- alter user <ユーザー名> set rsa_public_key_2='<新しい公開鍵>';
