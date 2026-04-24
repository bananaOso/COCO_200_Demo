# Tasty Bytes dbt Pipeline

dbt 1.9, Snowflake, sqlfluff. Source: DBT_TASTY_BYTES.RAW_DBT.

## Commands
- `dbt build --select state:modified+`: Build changed models
- `dbt test --select <model>`: Test one model
- `dbt compile --select <model>`: Check SQL compiles
- `sqlfluff lint models/`: Lint SQL

## Architecture
- models/staging/        1:1 with source, rename + cast only
- models/intermediate/   Joins and business logic
- models/marts/          Final tables for BI

## Rules — CRITICAL
- ALWAYS use {{ ref('model') }} and {{ source('tasty_bytes', 'TABLE') }}
  Never hardcode DBT_TASTY_BYTES.RAW_DBT.table_name
- ALWAYS use explicit column lists, never SELECT *
- Every model MUST have a schema.yml with description + tests
- Staging models: ONLY rename, cast, filter. NO joins, NO GROUP BY
- Intermediate: where joins happen
- Marts: aggregations and final metrics
- NEVER modify models/staging/ once created — build on top of them
- Run sqlfluff fix before committing

## Naming Conventions
- Staging: stg_tasty_bytes__<table>.sql
- Intermediate: int_<entity>__<verb>.sql
- Facts: fct_<entity>.sql
- Dimensions: dim_<entity>.sql

## Source Tables (DBT_TASTY_BYTES.RAW_DBT)
- ORDER_HEADER: order_id, truck_id, location_id, customer_id, order_ts, order_amount, order_total
- ORDER_DETAIL: order_detail_id, order_id, menu_item_id, quantity, unit_price, price
- CUSTOMER_LOYALTY: customer_id, first_name, last_name, city, country, sign_up_date, e_mail
- MENU: menu_id, menu_type, truck_brand_name, menu_item_name, item_category, cost_of_goods_usd, sale_price_usd
- TRUCK: truck_id, primary_city, region, country, make, model, franchise_id, truck_opening_date
- FRANCHISE: franchise_id, first_name, last_name, city, country
- LOCATION: location_id, location, city, region, country
- COUNTRY: country_id, country, iso_currency, city, city_population

## Git Workflow
- Feature branches only: feature/<description>
- All changes via PR to main
