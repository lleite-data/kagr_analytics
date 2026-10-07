{{
    config(
        materialized="incremental",
        incremental_strategy="delete+insert",
        unique_key="sale_date",
        cluster_by=["sale_date"],
    )
}}

with
    refunds as (
        select order_id, sum(refund_amount) as refund_amount
        from {{ ref("refunds") }}
        group by order_id
    ),

    source as (

        select
            order_id,
            event_id,
            customer_id,
            order_date,
            quantity,
            unit_price,
            status,
            _loaded_at
        from {{ ref("orders") }}

        {% if is_incremental() %}
            where
                order_date >= (
                    select dateadd(days, -3, max(sale_date)) as max_loaded
                    from {{ this }}
                )
        {% endif %}

    ),

    enrich_event as (

        select
            src.order_id,
            src.event_id,
            e.event_name,
            e.venue_id,
            case
                when e.event_name is null then 'UNKNOWN' else e.event_type
            end as event_type,
            src.customer_id,
            src.order_date,
            src.quantity,
            src.quantity * src.unit_price
            - coalesce(r.refund_amount, 0) as gross_amount,
            src.status,
            src._loaded_at
        from source as src
        left join {{ ref("events") }} as e on src.event_id = e.event_id
        left join refunds as r on src.order_id = r.order_id
    ),

    final as (

        select
            order_date as sale_date,
            event_id,
            venue_id,
            event_type,
            count(distinct(order_id)) as orders_count,
            sum(quantity) as tickets_sold,
            sum(gross_amount) as net_revenue,
            current_timestamp() as updated_at
        from enrich_event
        where status = 'COMPLETED' or status = 'REFUNDED'
        group by order_date, event_id, venue_id, event_type
    )

select *
from final
