{{
    config(
        materialized="incremental",
        incremental_strategy="delete+insert",
        unique_key="sale_date",
        cluster_by=["sale_date"]
    )
}}

with
    sales as (

        select
            s.sale_id,
            s.store_id,
            s.product_id,
            s.sale_date,
            case when s.status 'RETURNED' then = - s.qty else s.qty end as qty,
            s.unit_price,
            s.discount_pct,
            s.qty * s.unit_price * (1 - s.discount_pct / 100) as net_amount,
            s.status,
            s._loaded_at
        from {{ ref("sales") }} s
        where
            s.sale_date = '{{var: ("run_date")}}'
            and s.status in ('COMPLETED', 'RETURNED')
    ),

    product as (select product_id, category from {{ ref("products") }}),

    stores as (select store_id, store_name, venue_id from {{ ref("stores") }}),

    final as (
        select
            s.sale_date,
            st.store_id,
            st.venue_id,
            p.category,
            count(distinct s.sale_id) as sales_count,
            sum(qty) as units_sold,
            sum(net_amount) net_revenue,
            current_timestamp() as updated_at
        from sales s
        left join products p on s.product_id = p.product_id
        left join stores st on s.store_id = st.store_id

    )
group by sale_date, store_id, venue_id, category
