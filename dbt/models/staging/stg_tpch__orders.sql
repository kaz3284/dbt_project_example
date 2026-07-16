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
