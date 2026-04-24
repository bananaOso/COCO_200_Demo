with source as (
    select * from {{ source('tasty_bytes', 'TRUCK') }}
),

renamed as (
    select
        truck_id,
        menu_type_id,
        primary_city,
        region,
        iso_region,
        country,
        iso_country_code,
        franchise_flag,
        year,
        make,
        model,
        ev_flag,
        franchise_id,
        truck_opening_date
    from source
)

select * from renamed
