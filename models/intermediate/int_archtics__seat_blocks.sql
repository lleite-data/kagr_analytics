{{ config(materialized="view") }}

with
    exploded_seats as (

        select
            sm.season_id,
            sm.season_year,
            sm.manifest_id,
            sm.section_name,
            sm.row_name,
            sm.first_seat,
            sm.last_seat,
            sm.number_of_seats,
            n.seat
        from {{ ref("int_archtics__season_manifest") }} as sm
        inner join
            {{ ref("int_archtics__seat_numbers") }} as n
            on n.seat <= sm.last_seat
            and n.seat >= sm.first_seat
        where sm.seat_increment = 1

    ),

    ranked_seats as (

        -- Legacy used grp by on all columns here, distinct then
        select distinct
            rc.season_id,
            rc.season_year,
            rc.manifest_id,
            rc.section_name,
            rc.row_name,
            rc.row_type,
            rc.row_count_asc,
            rc.row_count_desc,
            s.first_seat,
            s.last_seat,
            s.number_of_seats,
            s.seat
        from {{ ref("int_archtics__row_rankings") }} as rc
        inner join
            exploded_seats as s
            on rc.season_year = s.season_year
            and rc.manifest_id = s.manifest_id
            and rc.season_id = s.season_id
            and rc.section_name = s.section_name
            and rc.row_name = s.row_name

    )

select
    manifest_id,
    season_id,
    season_year,
    section_name,
    row_name,
    row_type,
    row_count_asc,
    row_count_desc,
    number_of_seats,
    first_seat,
    last_seat,
    listagg(distinct seat, ',') within group (order by seat) as seats,
    count(
        distinct manifest_id, season_id, season_year, section_name, row_name, seat
    ) as capacity_calc
from ranked_seats
where ifnull(seat::varchar, '') <> ''
group by
    manifest_id,
    season_id,
    season_year,
    section_name,
    row_name,
    row_type,
    row_count_asc,
    row_count_desc,
    number_of_seats,
    first_seat,
    last_seat
