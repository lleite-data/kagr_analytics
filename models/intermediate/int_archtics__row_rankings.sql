{{ config(materialized="view") }}

with
    manifest_rows as (

        select distinct
            season_id,
            season_year,
            manifest_id,
            manifest_name,
            class_name,
            section_type_name,
            section_name,
            row_name
        from {{ ref("int_archtics__season_manifest") }}

    ),

    numeric_rows as (

        select distinct
            m.season_year,
            m.manifest_id,
            m.manifest_name,
            m.class_name,
            m.season_id,
            m.section_name,
            m.row_name::varchar as row_name,
            dense_rank() over (
                partition by m.season_year, m.manifest_id, m.season_id, m.section_name
                order by try_to_numeric(m.row_name, 'TM9') asc
            ) as row_rank_asc,
            dense_rank() over (
                partition by m.season_year, m.manifest_id, m.season_id, m.section_name
                order by try_to_numeric(m.row_name, 'TM9') desc
            ) as row_rank_desc
        from manifest_rows as m
        where
            try_to_numeric(m.row_name, 'TM9') is not null
            and try_to_numeric(m.row_name, 'TM9') > 0
            -- Snowflake REGEXP matches the WHOLE string: this means "contains a letter"
            and m.section_name not regexp '.*?[a-zA-Z].*?'
            and m.row_name not regexp '.*?[a-zA-Z].*?'

    ),

    alphanumeric_rows as (

        -- Everything not classified as numeric.
        -- Legacy ordering kept as-is: the ASC rank sorts longer names first.
        select distinct
            m.season_year,
            m.manifest_id,
            m.manifest_name,
            m.class_name,
            m.season_id,
            m.section_name,
            m.row_name::varchar as row_name,
            dense_rank() over (
                partition by m.season_year, m.manifest_id, m.season_id, m.section_name
                order by
                    length(
                        upper(trim(try_cast(m.row_name as varchar)))
                    ) desc nulls last,
                    upper(trim(try_cast(m.row_name as varchar))) asc
            ) as row_rank_asc,
            dense_rank() over (
                partition by m.season_year, m.manifest_id, m.season_id, m.section_name
                order by
                    length(
                        upper(trim(try_cast(m.row_name as varchar)))
                    ) asc nulls first,
                    upper(trim(try_cast(m.row_name as varchar))) desc
            ) as row_rank_desc
        from manifest_rows as m
        left join
            numeric_rows as nr
            on m.season_id = nr.season_id
            and m.season_year = nr.season_year
            and m.manifest_id = nr.manifest_id
            and m.section_name = nr.section_name
            and m.row_name = nr.row_name
        where nr.season_id is null

    ),

    all_rows as (

        select
            season_year,
            manifest_id,
            manifest_name,
            class_name,
            season_id,
            section_name,
            row_name,
            row_rank_asc,
            row_rank_desc
        from numeric_rows

        union

        select
            season_year,
            manifest_id,
            manifest_name,
            class_name,
            season_id,
            section_name,
            row_name,
            row_rank_asc,
            row_rank_desc
        from alphanumeric_rows

    ),

    typed_rows as (

        select
            *,
            case
                when upper(row_name) regexp '.*?[A-Z]{1,}.*?' then 2 else 1
            end as row_type
        from all_rows

    )

select distinct
    season_year,
    manifest_id,
    manifest_name,
    class_name,
    season_id,
    section_name,
    row_name,
    row_type,
    -- numeric rows (type 1) rank before alphanumeric rows (type 2) front-to-back...
    dense_rank() over (
        partition by season_year, manifest_id, season_id, section_name
        order by row_type, row_rank_asc
    ) as row_count_asc,
    -- ...and alphanumeric rows rank first back-to-front (so "last row" can be
    -- alphanumeric)
    dense_rank() over (
        partition by season_year, manifest_id, season_id, section_name
        order by row_type desc, row_rank_desc
    ) as row_count_desc
from typed_rows
