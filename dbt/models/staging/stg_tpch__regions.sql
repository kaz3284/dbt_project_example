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
