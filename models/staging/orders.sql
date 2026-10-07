{{ config(materialized="view") }}

with
    source as (select * from {{ source("ticketing", "orders") }}),

    cleaned as (

        select
            order_id,
            event_id,
            customer_id,
            order_ts::date as order_date,
            quantity,
            unit_price,
            status,
            _loaded_at
        from source

        where status <> 'TEST'

        qualify row_number() over (partition by order_id order by _loaded_at desc) = 1
    )

select *
from cleaned
