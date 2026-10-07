{{ config(materialized="view") }}
select seasonid as season_id
from {{ source("archtics", "archticsevents") }}
