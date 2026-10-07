{{ config(materialized="view") }}

select
    s.season_id,
    s.season_year,
    s.organization_id,
    m.manifest_id,
    m.arena_id,
    m.manifest_name,
    m.class_name,
    m.section_type_name,
    m.section_name,
    m.row_name,
    m.first_seat,
    m.last_seat,
    m.seat_increment,
    m.number_of_seats,
    m.default_price_code
from {{ ref("stg_archtics__manifest") }} as m
inner join
    {{ ref("stg_archtics__seasons") }} as s
    on m.manifest_id = s.manifest_id
    and m.arena_id = s.arena_id
