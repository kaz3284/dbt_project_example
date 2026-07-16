# dbt ハンズオン設計書：Snowflake TPC-H データマート構築

> この設計書は、dbt (dbt-snowflake アダプタ) で Snowflake のサンプルデータからデータマートを構築するハンズオン用の実装指示書です。
> 記載された SQL・YAML はそのまま実装できる完成形です。実装担当（人間 or LLM）は本書の各節を上から順にファイル化してください。
>
> *Co-authored with CoCo*

---

## 1. 概要・前提

### 1.1 目的
- dbt の推奨アーキテクチャ（**staging → intermediate → marts** の3層）を体験する。
- Snowflake の共有サンプルデータ `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` を使い、受注ビジネスのデータマート（データウェアハウス）を構築する。
- 最終成果物 `mart_sales_by_region` で「地域×年月の売上サマリ」を作り、`dbt docs` の Lineage が `REGION → NATION → CUSTOMER → ORDERS → LINEITEM` と綺麗に伸びる様子を可視化する。

### 1.2 なぜ TPCH_SF1 か
- 最大テーブル `LINEITEM` でも約600万行と小さく、ハンズオン中でも数秒で `dbt run` が完走する。
- 「顧客 → 注文 → 明細」というシンプルで直感的なスタースキーマ構造。
- `SNOWFLAKE_SAMPLE_DATA` は共有DBのためストレージ課金なし（クエリ実行のウェアハウス代のみ）。

### 1.3 前提環境
| 項目 | 値 |
|------|-----|
| dbt アダプタ | `dbt-snowflake`（dbt 1.7 以降を想定） |
| ソースDB / スキーマ | `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1`（読み取り専用の共有DB） |
| 出力先DB | 任意（例：`DBT_HANDSON`）。事前に `CREATE DATABASE DBT_HANDSON;` 済みとする |
| 出力先スキーマ | dbt が `target` に応じて自動生成（例：`DBT_<ユーザー名>`） |
| ウェアハウス | XSMALL で十分 |
| ロール | `SNOWFLAKE_SAMPLE_DATA` への SELECT 権限と出力先DBへの CREATE 権限を持つロール |

> 注意：`SNOWFLAKE_SAMPLE_DATA` はデフォルトで全アカウントに共有されている。もし存在しない場合は `CREATE DATABASE SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA;` を管理者ロールで実行する。

### 1.4 完成後の Lineage イメージ
```
source: TPCH_SF1
  REGION ─────► stg_tpch__regions ──┐
  NATION ─────► stg_tpch__nations ──┤
  CUSTOMER ───► stg_tpch__customers ┤
  ORDERS ─────► stg_tpch__orders ───┼─► int_orders_with_items ─┐
  LINEITEM ───► stg_tpch__lineitems ┘                          │
                                                               ├─► fct_orders
  stg_tpch__customers ─► dim_customers (+ nations, regions)    │
                                                               ▼
  (regions + nations + customers + int_orders_with_items) ─► mart_sales_by_region
```

---

## 2. ソースデータ定義

`SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` から以下5テーブルを使用する。

### CUSTOMER（顧客・150,000行）
| カラム | 型 | 説明 |
|--------|-----|------|
| C_CUSTKEY | NUMBER | 顧客キー（PK） |
| C_NAME | TEXT | 顧客名 |
| C_NATIONKEY | NUMBER | 国キー（→ NATION.N_NATIONKEY） |
| C_MKTSEGMENT | TEXT | 市場セグメント |
| C_ACCTBAL | NUMBER | 口座残高 |

### ORDERS（注文・1,500,000行）
| カラム | 型 | 説明 |
|--------|-----|------|
| O_ORDERKEY | NUMBER | 注文キー（PK） |
| O_CUSTKEY | NUMBER | 顧客キー（→ CUSTOMER.C_CUSTKEY） |
| O_ORDERSTATUS | TEXT | 注文ステータス |
| O_TOTALPRICE | NUMBER | 注文合計金額 |
| O_ORDERDATE | DATE | 注文日 |
| O_ORDERPRIORITY | TEXT | 注文優先度 |

### LINEITEM（注文明細・6,001,215行）
| カラム | 型 | 説明 |
|--------|-----|------|
| L_ORDERKEY | NUMBER | 注文キー（→ ORDERS.O_ORDERKEY） |
| L_LINENUMBER | NUMBER | 明細行番号（複合PK: ORDERKEY+LINENUMBER） |
| L_QUANTITY | NUMBER | 数量 |
| L_EXTENDEDPRICE | NUMBER | 明細金額（単価×数量） |
| L_DISCOUNT | NUMBER | 割引率（0〜1） |
| L_TAX | NUMBER | 税率 |
| L_RETURNFLAG | TEXT | 返品フラグ |
| L_SHIPDATE | DATE | 出荷日 |

> 純売上の定義：`L_EXTENDEDPRICE * (1 - L_DISCOUNT)`（TPC-H の慣例）

### NATION（国・25行）
| カラム | 型 | 説明 |
|--------|-----|------|
| N_NATIONKEY | NUMBER | 国キー（PK） |
| N_NAME | TEXT | 国名 |
| N_REGIONKEY | NUMBER | 地域キー（→ REGION.R_REGIONKEY） |

### REGION（地域・5行）
| カラム | 型 | 説明 |
|--------|-----|------|
| R_REGIONKEY | NUMBER | 地域キー（PK） |
| R_NAME | TEXT | 地域名（AMERICA / ASIA / EUROPE 等） |

---

## 3. プロジェクト構成

### 3.1 ディレクトリツリー
```
dbt_tpch_handson/
├── dbt_project.yml
├── packages.yml                 # 任意（dbt_utils を使う場合）
├── models/
│   ├── staging/
│   │   ├── _tpch__sources.yml
│   │   ├── _tpch__models.yml
│   │   ├── stg_tpch__customers.sql
│   │   ├── stg_tpch__orders.sql
│   │   ├── stg_tpch__lineitems.sql
│   │   ├── stg_tpch__nations.sql
│   │   └── stg_tpch__regions.sql
│   ├── intermediate/
│   │   └── int_orders_with_items.sql
│   └── marts/
│       ├── _marts__models.yml
│       ├── dim_customers.sql
│       ├── fct_orders.sql
│       └── mart_sales_by_region.sql
```

### 3.2 dbt_project.yml
```yaml
name: 'dbt_tpch_handson'
version: '1.0.0'
config-version: 2

profile: 'dbt_tpch_handson'   # profiles.yml 側のプロファイル名に合わせる

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]

models:
  dbt_tpch_handson:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
```

### 3.3 packages.yml（任意）
```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.1.0", "<2.0.0"]
```
> `dbt_utils` は必須ではない。使う場合は `dbt deps` を実行。本設計書のSQLは dbt_utils なしでも動作する。

### 3.4 マテリアライズ方針
| 層 | materialized | 理由 |
|----|--------------|------|
| staging | `view` | ソースの1:1クレンジング。物理化不要で常に最新を参照 |
| intermediate | `ephemeral` | 中間ロジック。CTEとしてインライン展開されテーブルを作らない |
| marts | `table` | 分析用の最終成果物。BIやクエリのパフォーマンスを優先 |

---

## 4. モデル詳細設計

### 4.1 staging 層

#### stg_tpch__customers
- **目的**：CUSTOMER をリネーム・整形した1:1ビュー。
- **入力**：`source('tpch', 'customer')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| customer_key | 顧客キー |
| customer_name | 顧客名 |
| nation_key | 国キー |
| market_segment | 市場セグメント |
| account_balance | 口座残高 |

- **実装SQL**（`models/staging/stg_tpch__customers.sql`）
```sql
with source as (
    select * from {{ source('tpch', 'customer') }}
),

renamed as (
    select
        c_custkey    as customer_key,
        c_name       as customer_name,
        c_nationkey  as nation_key,
        c_mktsegment as market_segment,
        c_acctbal    as account_balance
    from source
)

select * from renamed
```

#### stg_tpch__orders
- **目的**：ORDERS をリネーム・整形。注文年月を派生列として追加。
- **入力**：`source('tpch', 'orders')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| order_key | 注文キー |
| customer_key | 顧客キー |
| order_status | 注文ステータス |
| total_price | 注文合計金額 |
| order_date | 注文日 |
| order_month | 注文年月（月初日に丸め） |
| order_priority | 注文優先度 |

- **実装SQL**（`models/staging/stg_tpch__orders.sql`）
```sql
with source as (
    select * from {{ source('tpch', 'orders') }}
),

renamed as (
    select
        o_orderkey                    as order_key,
        o_custkey                     as customer_key,
        o_orderstatus                 as order_status,
        o_totalprice                  as total_price,
        o_orderdate                   as order_date,
        date_trunc('month', o_orderdate) as order_month,
        o_orderpriority               as order_priority
    from source
)

select * from renamed
```

#### stg_tpch__lineitems
- **目的**：LINEITEM をリネームし、純売上（net_amount）を計算。
- **入力**：`source('tpch', 'lineitem')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| order_key | 注文キー |
| line_number | 明細行番号 |
| quantity | 数量 |
| extended_price | 明細金額 |
| discount | 割引率 |
| tax | 税率 |
| net_amount | 純売上 = extended_price × (1 - discount) |
| return_flag | 返品フラグ |
| ship_date | 出荷日 |

- **実装SQL**（`models/staging/stg_tpch__lineitems.sql`）
```sql
with source as (
    select * from {{ source('tpch', 'lineitem') }}
),

renamed as (
    select
        l_orderkey        as order_key,
        l_linenumber      as line_number,
        l_quantity        as quantity,
        l_extendedprice   as extended_price,
        l_discount        as discount,
        l_tax             as tax,
        l_extendedprice * (1 - l_discount) as net_amount,
        l_returnflag      as return_flag,
        l_shipdate        as ship_date
    from source
)

select * from renamed
```

#### stg_tpch__nations
- **目的**：NATION をリネーム。
- **入力**：`source('tpch', 'nation')`
- **出力カラム**：nation_key / nation_name / region_key
- **実装SQL**（`models/staging/stg_tpch__nations.sql`）
```sql
with source as (
    select * from {{ source('tpch', 'nation') }}
),

renamed as (
    select
        n_nationkey as nation_key,
        n_name      as nation_name,
        n_regionkey as region_key
    from source
)

select * from renamed
```

#### stg_tpch__regions
- **目的**：REGION をリネーム。
- **入力**：`source('tpch', 'region')`
- **出力カラム**：region_key / region_name
- **実装SQL**（`models/staging/stg_tpch__regions.sql`）
```sql
with source as (
    select * from {{ source('tpch', 'region') }}
),

renamed as (
    select
        r_regionkey as region_key,
        r_name      as region_name
    from source
)

select * from renamed
```

---

### 4.2 intermediate 層

#### int_orders_with_items
- **目的**：注文（orders）と明細（lineitems）を結合し、注文単位に明細を集約する。marts 層の複数モデルから再利用する中間テーブル。
- **入力**：`ref('stg_tpch__orders')` / `ref('stg_tpch__lineitems')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| order_key | 注文キー |
| customer_key | 顧客キー |
| order_date | 注文日 |
| order_month | 注文年月 |
| order_status | 注文ステータス |
| line_item_count | 明細行数 |
| total_quantity | 合計数量 |
| net_sales_amount | 純売上合計（明細のnet_amount合計） |

- **変換ロジック**：`order_key` で内部結合 → `order_key` 単位に `count` / `sum` で集約。
- **実装SQL**（`models/intermediate/int_orders_with_items.sql`）
```sql
with orders as (
    select * from {{ ref('stg_tpch__orders') }}
),

lineitems as (
    select * from {{ ref('stg_tpch__lineitems') }}
),

joined as (
    select
        o.order_key,
        o.customer_key,
        o.order_date,
        o.order_month,
        o.order_status,
        count(l.line_number)  as line_item_count,
        sum(l.quantity)       as total_quantity,
        sum(l.net_amount)     as net_sales_amount
    from orders o
    inner join lineitems l
        on o.order_key = l.order_key
    group by
        o.order_key,
        o.customer_key,
        o.order_date,
        o.order_month,
        o.order_status
)

select * from joined
```

---

### 4.3 marts 層

#### dim_customers
- **目的**：顧客ディメンション。顧客に国名・地域名を付与する。
- **入力**：`ref('stg_tpch__customers')` / `ref('stg_tpch__nations')` / `ref('stg_tpch__regions')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| customer_key | 顧客キー（PK） |
| customer_name | 顧客名 |
| market_segment | 市場セグメント |
| account_balance | 口座残高 |
| nation_name | 国名 |
| region_name | 地域名 |

- **実装SQL**（`models/marts/dim_customers.sql`）
```sql
with customers as (
    select * from {{ ref('stg_tpch__customers') }}
),

nations as (
    select * from {{ ref('stg_tpch__nations') }}
),

regions as (
    select * from {{ ref('stg_tpch__regions') }}
),

final as (
    select
        c.customer_key,
        c.customer_name,
        c.market_segment,
        c.account_balance,
        n.nation_name,
        r.region_name
    from customers c
    left join nations n
        on c.nation_key = n.nation_key
    left join regions r
        on n.region_key = r.region_key
)

select * from final
```

#### fct_orders
- **目的**：注文ファクト。中間テーブルに顧客の国・地域を付与した明細粒度=注文粒度のファクト。
- **入力**：`ref('int_orders_with_items')` / `ref('dim_customers')`
- **出力カラム**

| カラム | 説明 |
|--------|------|
| order_key | 注文キー（PK） |
| customer_key | 顧客キー |
| customer_name | 顧客名 |
| region_name | 地域名 |
| nation_name | 国名 |
| order_date | 注文日 |
| order_month | 注文年月 |
| order_status | 注文ステータス |
| line_item_count | 明細行数 |
| total_quantity | 合計数量 |
| net_sales_amount | 純売上合計 |

- **実装SQL**（`models/marts/fct_orders.sql`）
```sql
with orders as (
    select * from {{ ref('int_orders_with_items') }}
),

customers as (
    select * from {{ ref('dim_customers') }}
),

final as (
    select
        o.order_key,
        o.customer_key,
        c.customer_name,
        c.region_name,
        c.nation_name,
        o.order_date,
        o.order_month,
        o.order_status,
        o.line_item_count,
        o.total_quantity,
        o.net_sales_amount
    from orders o
    left join customers c
        on o.customer_key = c.customer_key
)

select * from final
```

#### mart_sales_by_region（★本設計書の主役）
- **目的**：`REGION → NATION → CUSTOMER → ORDERS → LINEITEM` を全結合し、**地域 × 年月**で売上を集約した最終データマート。dbt docs 上で Lineage が最も長く伸びるモデル。
- **入力**：`ref('stg_tpch__regions')` / `ref('stg_tpch__nations')` / `ref('stg_tpch__customers')` / `ref('int_orders_with_items')`
  - ※ `int_orders_with_items` の内部に orders と lineitems が含まれるため、実質5テーブルすべてが上流に連なる。
- **出力カラム**

| カラム | 説明 |
|--------|------|
| region_name | 地域名 |
| order_month | 注文年月（月初日） |
| order_count | 注文件数 |
| customer_count | ユニーク顧客数 |
| total_quantity | 合計数量 |
| net_sales_amount | 純売上合計 |
| avg_order_value | 平均注文単価（net_sales_amount / order_count） |

- **変換ロジック**
  1. `int_orders_with_items`（注文×明細集約済み）を起点にする。
  2. `customer_key` で customers を結合 → `nation_key` で nations を結合 → `region_key` で regions を結合し、地域名を取得。
  3. `region_name` × `order_month` で集約。
- **実装SQL**（`models/marts/mart_sales_by_region.sql`）
```sql
with orders as (
    select * from {{ ref('int_orders_with_items') }}
),

customers as (
    select * from {{ ref('stg_tpch__customers') }}
),

nations as (
    select * from {{ ref('stg_tpch__nations') }}
),

regions as (
    select * from {{ ref('stg_tpch__regions') }}
),

joined as (
    select
        r.region_name,
        o.order_month,
        o.order_key,
        o.customer_key,
        o.total_quantity,
        o.net_sales_amount
    from orders o
    inner join customers c
        on o.customer_key = c.customer_key
    inner join nations n
        on c.nation_key = n.nation_key
    inner join regions r
        on n.region_key = r.region_key
),

aggregated as (
    select
        region_name,
        order_month,
        count(distinct order_key)     as order_count,
        count(distinct customer_key)  as customer_count,
        sum(total_quantity)           as total_quantity,
        sum(net_sales_amount)         as net_sales_amount,
        sum(net_sales_amount) / nullif(count(distinct order_key), 0) as avg_order_value
    from joined
    group by region_name, order_month
)

select * from aggregated
order by region_name, order_month
```

---

## 5. テスト・ドキュメント定義

### 5.1 ソース定義（`models/staging/_tpch__sources.yml`）
```yaml
version: 2

sources:
  - name: tpch
    database: SNOWFLAKE_SAMPLE_DATA
    schema: TPCH_SF1
    description: "Snowflake が共有する TPC-H サンプルデータ（スケールファクタ1）"
    tables:
      - name: customer
      - name: orders
      - name: lineitem
      - name: nation
      - name: region
```

### 5.2 staging モデルのテスト・説明（`models/staging/_tpch__models.yml`）
```yaml
version: 2

models:
  - name: stg_tpch__customers
    description: "顧客マスタのクレンジング済みビュー"
    columns:
      - name: customer_key
        description: "顧客キー（主キー）"
        tests:
          - unique
          - not_null

  - name: stg_tpch__orders
    description: "注文のクレンジング済みビュー"
    columns:
      - name: order_key
        description: "注文キー（主キー）"
        tests:
          - unique
          - not_null
      - name: customer_key
        tests:
          - not_null
          - relationships:
              to: ref('stg_tpch__customers')
              field: customer_key

  - name: stg_tpch__lineitems
    description: "注文明細のクレンジング済みビュー。net_amount を計算済み"
    columns:
      - name: order_key
        tests:
          - not_null
          - relationships:
              to: ref('stg_tpch__orders')
              field: order_key

  - name: stg_tpch__nations
    description: "国マスタ"
    columns:
      - name: nation_key
        tests:
          - unique
          - not_null

  - name: stg_tpch__regions
    description: "地域マスタ"
    columns:
      - name: region_key
        tests:
          - unique
          - not_null
```

### 5.3 marts モデルのテスト・説明（`models/marts/_marts__models.yml`）
```yaml
version: 2

models:
  - name: dim_customers
    description: "顧客ディメンション。国名・地域名を付与済み"
    columns:
      - name: customer_key
        description: "顧客キー（主キー）"
        tests:
          - unique
          - not_null

  - name: fct_orders
    description: "注文ファクト。注文粒度で売上・地域を保持"
    columns:
      - name: order_key
        description: "注文キー（主キー）"
        tests:
          - unique
          - not_null
      - name: net_sales_amount
        tests:
          - not_null

  - name: mart_sales_by_region
    description: "★地域×年月の売上サマリ。REGION→NATION→CUSTOMER→ORDERS→LINEITEM を全結合した最終データマート"
    columns:
      - name: region_name
        tests:
          - not_null
      - name: order_month
        tests:
          - not_null
      - name: net_sales_amount
        description: "純売上合計 = Σ(extended_price × (1 - discount))"
        tests:
          - not_null
```

---

## 6. 実行手順

```bash
# 1. 依存パッケージ取得（packages.yml を使う場合のみ）
dbt deps

# 2. 接続確認
dbt debug

# 3. 全モデル構築
dbt run

# 4. 特定モデルのみ構築したい場合（上流も含める）
dbt run --select +mart_sales_by_region

# 5. テスト実行
dbt test

# 6. ドキュメント生成 & Lineage 閲覧
dbt docs generate
dbt docs serve
```

### 6.1 結果検証サンプルクエリ
`dbt run` 完了後、出力先スキーマで以下を実行して `mart_sales_by_region` を確認する。

```sql
-- 地域別の総売上ランキング
select
    region_name,
    sum(net_sales_amount) as total_net_sales,
    sum(order_count)      as total_orders
from mart_sales_by_region
group by region_name
order by total_net_sales desc;

-- 特定地域の月次推移
select
    order_month,
    net_sales_amount,
    order_count,
    avg_order_value
from mart_sales_by_region
where region_name = 'ASIA'
order by order_month;
```

**期待される結果イメージ**：TPC-H のデータは 1992〜1998 年に分布するため、`order_month` はこの範囲の月初日となり、5地域（AFRICA / AMERICA / ASIA / EUROPE / MIDDLE EAST）× 月数の行が出力される。

---

## 7. 発展課題（時間があれば）

### 7.1 incremental モデル化
`fct_orders` を増分更新に変更し、Snowflake の差分処理を体験する。
```sql
{{ config(materialized='incremental', unique_key='order_key') }}

-- ... 通常のSELECT ...
{% if is_incremental() %}
where order_date > (select max(order_date) from {{ this }})
{% endif %}
```

### 7.2 seed でマスタ追加
`seeds/region_targets.csv`（地域ごとの売上目標）を用意し、`dbt seed` で投入 → `mart_sales_by_region` と結合して達成率を算出するモデルを追加する。

### 7.3 Snowflake 固有機能への応用
- marts を **Dynamic Table** としてマテリアライズ（`materialized='dynamic_table'` + `snowflake_warehouse` / `target_lag` 設定）し、自動リフレッシュを体験。
- `mart_sales_by_region` を元に **Semantic View** を定義し、Cortex Analyst で自然言語クエリを試す。

---

## 付録：実装チェックリスト
- [ ] `dbt_project.yml` のマテリアライズ設定が層ごとに正しい
- [ ] staging 5モデルが `source()` を参照している
- [ ] intermediate / marts が `ref()` のみを参照している（`source()` を直接参照しない）
- [ ] `mart_sales_by_region` の上流に5ソースすべてが連なっている（`dbt docs` の Lineage で確認）
- [ ] `dbt test` が全て pass する
- [ ] 検証クエリで地域別売上が出力される
