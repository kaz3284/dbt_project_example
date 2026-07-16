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
