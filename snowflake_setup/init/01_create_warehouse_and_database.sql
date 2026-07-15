-- ウェアハウス・データベースの作成
--
-- アカウントの初回環境構築時に一度だけ実行します（データベース／環境ごとに実行する
-- roles/・tags/ 配下のスクリプトとは異なり、こちらはアカウント全体で一度きりの作業です）。

use role sysadmin;

create warehouse if not exists developer_wh
  warehouse_size = 'XSMALL'
  initially_suspended = true;

-- 必要に応じて自動サスペンド等を追加設定してください
-- alter warehouse developer_wh set auto_suspend = 60 auto_resume = true;

use role accountadmin;

create database if not exists trial_db;
