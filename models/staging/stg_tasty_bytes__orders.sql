with source as (
    select * from {{ source('tasty_bytes', 'ORDER_HEADER') }}
),

renamed as (
    select
        order_id,
        truck_id,
        location_id::int as location_id,
        customer_id,
        shift_id,
        order_channel,
        order_ts,
        order_currency,
        order_amount,
        order_total
    from source
)

select * from renamed
-- test
-- test2
-- test
