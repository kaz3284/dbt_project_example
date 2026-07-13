
{{ 
    config(
        materialized='table',
        alias='address',
    ) 
}}

with source_data as (

    select *
    from {{ ref('raw_address') }}

)

select *
from source_data
