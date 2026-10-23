ALTER TABLE products
    DROP CONSTRAINT IF EXISTS products_category_id_fkey,
    DROP CONSTRAINT IF EXISTS products_brand_id_fkey;

ALTER TABLE product_variants
    DROP CONSTRAINT IF EXISTS product_variants_product_id_fkey;

ALTER TABLE carts
    DROP CONSTRAINT IF EXISTS carts_customer_id_fkey,
    DROP CONSTRAINT IF EXISTS fk_carts_customer;

ALTER TABLE cart_items
    DROP CONSTRAINT IF EXISTS cart_items_product_id_fkey,
    DROP CONSTRAINT IF EXISTS fk_cart_items_product,
    DROP CONSTRAINT IF EXISTS cart_items_variant_id_fkey;

ALTER TABLE delivery_zones
    DROP CONSTRAINT IF EXISTS delivery_zones_city_id_fkey,
    ALTER COLUMN id DROP DEFAULT;

ALTER TABLE customer_addresses
    DROP CONSTRAINT IF EXISTS customer_addresses_city_id_fkey;

ALTER TABLE checkout_sessions
    DROP CONSTRAINT IF EXISTS checkout_sessions_delivery_zone_id_fkey;

ALTER TABLE categories
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text;

ALTER TABLE brands
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text;

ALTER TABLE products
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN category_id TYPE VARCHAR(128) USING category_id::text,
    ALTER COLUMN brand_id TYPE VARCHAR(128) USING brand_id::text;

ALTER TABLE product_variants
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN product_id TYPE VARCHAR(128) USING product_id::text;

ALTER TABLE cart_items
    ALTER COLUMN product_id TYPE VARCHAR(128) USING product_id::text,
    ALTER COLUMN variant_id TYPE VARCHAR(128) USING variant_id::text;

ALTER TABLE cities
    ALTER COLUMN id DROP DEFAULT,
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE delivery_zones
    ALTER COLUMN id TYPE VARCHAR(128) USING id::text,
    ALTER COLUMN city_id TYPE VARCHAR(128) USING city_id::text,
    ALTER COLUMN id SET DEFAULT gen_random_uuid()::text;

ALTER TABLE customer_addresses
    ALTER COLUMN city_id TYPE VARCHAR(128) USING city_id::text;

ALTER TABLE checkout_sessions
    ALTER COLUMN delivery_zone_id TYPE VARCHAR(128) USING delivery_zone_id::text,
    ADD COLUMN IF NOT EXISTS delivery_option VARCHAR(32) NOT NULL DEFAULT 'standard';

ALTER TABLE products
    ADD CONSTRAINT products_category_id_fkey
        FOREIGN KEY (category_id) REFERENCES categories(id),
    ADD CONSTRAINT products_brand_id_fkey
        FOREIGN KEY (brand_id) REFERENCES brands(id);

ALTER TABLE product_variants
    ADD CONSTRAINT product_variants_product_id_fkey
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE;

ALTER TABLE carts
    ADD CONSTRAINT fk_carts_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE;

ALTER TABLE cart_items
    ADD CONSTRAINT fk_cart_items_product
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    ADD CONSTRAINT cart_items_variant_id_fkey
        FOREIGN KEY (variant_id) REFERENCES product_variants(id) ON DELETE SET NULL;

ALTER TABLE delivery_zones
    ADD CONSTRAINT delivery_zones_city_id_fkey
        FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE RESTRICT;

ALTER TABLE customer_addresses
    ADD CONSTRAINT customer_addresses_city_id_fkey
        FOREIGN KEY (city_id) REFERENCES cities(id) ON DELETE RESTRICT;

ALTER TABLE checkout_sessions
    ADD CONSTRAINT checkout_sessions_delivery_zone_id_fkey
        FOREIGN KEY (delivery_zone_id) REFERENCES delivery_zones(id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_checkout_sessions_delivery_option
        CHECK (delivery_option IN ('standard', 'express'));
