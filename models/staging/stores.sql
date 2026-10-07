{{ config(materialized="view") }}


select store_id, store_name, venue_id
from {{ source("merch", "stores") }}
