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
