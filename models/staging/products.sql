{{ config(materialized="view") }}

select product_id, product_name, category, is_active

from {{ source("merch", "products") }}
