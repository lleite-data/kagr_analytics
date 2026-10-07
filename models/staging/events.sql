{{ config(materialized="view") }}

select event_id, event_name, venue_id, event_type

from {{ source("ticketing", "events") }}
