{{ config(materialized="view") }}

select
    sale_id,
    store_id,
    product_id,
    sale_ts,
    qty,
    unit_price,
    discount_pct,
    status,
    _loaded_at
from {{ source("merch", "sales") }}
