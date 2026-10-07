{{ config(materialized="view") }}
select
    manifestid as manifest_id,
    arenaid as arena_id,
    manifestname as manifest_name,
    classname as class_name,
    sectiontypename as section_type_name,
    sectionname as section_name,
    rowname as row_name,
    firstseat as first_seat,
    lastseat as last_seat,
    seatincrement as seat_increment,
    numberofseats as number_of_seats,
    defaultpricecode as default_price_code
from {{ source("archtics", "archticsmanifest") }}
