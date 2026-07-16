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
