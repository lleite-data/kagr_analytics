{{ config(materialized="table") }}

select row_number() over (order by seq4()) as seat
from table(generator(rowcount => {{ var("max_seat_number") }}))
