{{ config(materialized="view") }}
select
    seasonid as season_id,
    seasonyear as season_year,
    manifestid as manifest_id,
    arenaid as arena_id,
    organizationid as organization_id
from {{ source("archtics", "archticsseasons") }}
