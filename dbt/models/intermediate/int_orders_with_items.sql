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
