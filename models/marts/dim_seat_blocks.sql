{{ config(materialized="table") }}

with
    season_manifest as (select * from {{ ref("int_archtics__season_manifest") }}),

    events as (select season_id from {{ ref("stg_archtics__events") }}),

    seat_blocks as (select * from {{ ref("int_archtics__seat_blocks") }}),

    row_rankings as (select * from {{ ref("int_archtics__row_rankings") }}),

    joined as (

        select
            sm.season_year,
            sm.manifest_id,
            sm.season_id,
            sm.section_name,
            sm.row_name,
            sm.class_name,
            sm.manifest_name,
            sm.default_price_code,
            sm.organization_id,
            sb.seats,
            sb.capacity_calc,
            rc.section_name as rc_section_name,
            rc.row_count_asc as rc_row_count_asc,
            rcmin.row_name as first_row_name,
            rcmax.row_name as last_row_name
        from season_manifest as sm

        inner join events as e on sm.season_id = e.season_id

        inner join
            seat_blocks as sb
            on sm.season_id = sb.season_id
            and sm.season_year = sb.season_year
            and sm.section_name = sb.section_name
            and sm.row_name = sb.row_name
            and sm.manifest_id = sb.manifest_id
            and sm.first_seat::varchar = split_part(sb.seats, ',', 1)::varchar
            and sm.last_seat::varchar = split_part(sb.seats, ',', -1)::varchar
        left join
            row_rankings as rc
            on sm.season_year = rc.season_year
            and sm.season_id = rc.season_id
            and sm.manifest_id = rc.manifest_id
            and sm.section_name = rc.section_name
            and sm.row_name = rc.row_name
        left join
            row_rankings as rcmin
            on sm.season_year = rcmin.season_year
            and sm.season_id = rcmin.season_id
            and sm.manifest_id = rcmin.manifest_id
            and sm.section_name = rcmin.section_name
            and rcmin.row_count_asc = 1
        left join
            row_rankings as rcmax
            on sm.season_year = rcmax.season_year
            and sm.season_id = rcmax.season_id
            and sm.manifest_id = rcmax.manifest_id
            and sm.section_name = rcmax.section_name
            and rcmax.row_count_desc = 1

    ),

    with_quartile as (

        select
            *,
            ntile(4) over (
                partition by season_year, manifest_id, season_id, section_name
                order by rc_row_count_asc
            ) as row_quartile
        from joined

    ),

    final as (

        select distinct
            sha2(
                '{{ var("team_abbr") }}'
                || '-'
                || ifnull(to_char(season_year), '')
                || '-'
                || ifnull(to_char(manifest_id), '')
                || '-'
                || ifnull(to_char(season_id), '')
                || '-'
                || ifnull(to_char(section_name), '')
                || '-'
                || ifnull(to_char(row_name), '')
                || '-'
                || ifnull(to_char(seats), ''),
                512
            ) as skhash,
            season_year::number(38, 0) as seasonyear,
            manifest_id as manifestid,
            season_id as seasonid,
            section_name as sectionname,
            row_name as rowname,
            seats,
            capacity_calc as capacity,
            class_name as classname,
            case
                when trim(row_name) ilike '%SRO%'
                then 'SRO'
                when trim(row_name) ilike '%ADA%'
                then 'ADA'
                else 'Manifest'
            end as classification,
            case
                when
                    organization_id in ({{ var("stadium_level_org_ids") | join(", ") }})
                then
                    case
                        when default_price_code ilike 'S%'
                        then 'Suites'
                        when default_price_code ilike 'P%'
                        then 'Porch'
                        when default_price_code ilike 'DH%'
                        then 'Solon'
                        when default_price_code ilike 'EH%'
                        then 'Gilt Edge Club'
                        when default_price_code ilike 'T%'
                        then 'Home run terrace / Rally''s field house'
                        else 'Other'
                    end
                else 'Other'
            end as stadiumlevel,
            case
                when
                    rc_section_name is null
                    or section_name regexp '.*?[a-zA-Z].*?'
                    or row_name ilike '%GA%'
                    or row_name ilike '%SRO%'
                    or row_name ilike '%WC%'
                    or row_name ilike '%VIP%'
                    or row_name ilike '%LIST%'
                    or row_name ilike '%LFT%'
                    or row_name ilike '%LOFT%'
                    or row_name ilike '%SUITE%'
                    or row_name ilike '%LUXURY%'
                    or row_name regexp '^[a-zA-Z]{4,}$'
                    or row_name regexp '[A-Za-z]+[0-9]+'
                    or row_name regexp '[0-9]+[a-zA-Z]+'
                then ''
                else
                    case
                        when to_char(row_name) = to_char(first_row_name)
                        then 'First row'
                        when to_char(row_name) = to_char(last_row_name)
                        then 'Last row'
                        when row_quartile = 1
                        then 'Front 25%'
                        when row_quartile in (2, 3)
                        then 'Middle'
                        when row_quartile = 4
                        then 'Last 25%'
                    end
            end as rowlevel,

            null::number as rowsortorder,
            null::varchar as stadiumside,
            null::varchar as sightline,
            default_price_code as basecategory,
            manifest_name as description,
            '{{ var("organization_name") }}' as organizationname
        from with_quartile

    )

select
    skhash,
    seasonyear,
    manifestid,
    seasonid,
    sectionname,
    rowname,
    seats,
    capacity,
    classname,
    classification,
    stadiumlevel,
    rowlevel,
    rowsortorder,
    stadiumside,
    sightline,
    basecategory,
    description,
    organizationname,
    1 as active
from final
qualify
    row_number() over (
        partition by skhash
        order by
            case
                when rowlevel = ''
                then 6
                when rowlevel = 'First row'
                then 5
                when rowlevel = 'Last row'
                then 4
                when rowlevel = 'Front 25%'
                then 3
                when rowlevel = 'Last 25%'
                then 2
                when rowlevel = 'Middle'
                then 1
            end asc,
            classname,
            basecategory,
            description
    )
    = 1
