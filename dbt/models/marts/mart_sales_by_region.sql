with orders as (
    select * from {{ ref('fct_orders') }}
),

aggregated as (
    select
        region_name,
        order_month,
        count(*)                      as order_count,
        count(distinct customer_key)  as customer_count,
        sum(total_quantity)           as total_quantity,
        sum(net_sales_amount)         as net_sales_amount,
        sum(net_sales_amount) / nullif(count(*), 0) as avg_order_value
    from orders
    group by region_name, order_month
)

select * from aggregated
