
{{ 
    config(
        materialized='table',
        alias='address',
    ) 
}}

with source_data as (

    select 
        1 as account_id,
        'Japan' as country,
        '81-0001' as zip,
        'Saitama-ken' as prefecture,
        'Hiki-gun' as city,
        '0001' as address,
        '00-0000-0001' as tel,
        '00-0001-0001' as fax
    union all
    select
        2 as account_id,
        'Japan' as country,
        '81-0002' as zip,
        'Saitama-ken' as prefecture,
        'Higashimatsuyama-shi' as city,
        '0002' as address,
        '00-0000-0002' as tel,
        '00-0001-0002' as fax
    union all
    select
        3 as account_id,
        'Japan' as country,
        '81-0003' as zip,
        'Tokyo' as prefecture,
        'Toshima-ku' as city,
        '0003' as address,
        '00-0000-0003' as tel,
        '00-0001-0003' as fax
)

select *
from source_data
