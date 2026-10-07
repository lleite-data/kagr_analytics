with dbt_model as (

    select skhash, seasonyear, manifestid, seasonid, sectionname, rowname, seats,
           capacity, classname, classification, stadiumlevel, rowlevel, basecategory,
           description, organizationname
    from {{ ref('dim_seat_blocks') }}

),

legacy as (

    select skhash, seasonyear, manifestid, seasonid, sectionname, rowname, seats,
           capacity, classname, classification, stadiumlevel, rowlevel, basecategory,
           description, organizationname
    from {{ var('legacy_table', 'legacy.dim_seat_blocks') }}

)

select 'only_in_dbt' as side, * from (select * from dbt_model minus select * from legacy)
union all
select 'only_in_legacy' as side, * from (select * from legacy minus select * from dbt_model)