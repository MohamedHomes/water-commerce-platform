-- 007: deterministic seed of the initial catalog, cities, and delivery zones.
-- Replaces the previous in-memory fixtures/config while preserving existing API IDs.

INSERT INTO categories (id, name, slug, description, created_at, updated_at) VALUES
    ('cat-water', 'Bottled Water', 'bottled-water', 'Still and sparkling water', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('cat-boxes', 'Water Boxes', 'water-boxes', 'Water ready to drink cartons', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('cat-bulk', 'Bulk Supply', 'bulk-supply', 'Commercial and household bulk supply', '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    description = EXCLUDED.description,
    updated_at = EXCLUDED.updated_at;

INSERT INTO brands (id, name, slug, description, created_at, updated_at) VALUES
    ('brand-aquaflow', 'AquaFlow', 'aquaflow', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('brand-nature', 'Nature Spring', 'nature-spring', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('brand-pure', 'PureDrop', 'puredrop', NULL, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    description = EXCLUDED.description,
    updated_at = EXCLUDED.updated_at;

INSERT INTO products (
    id, name, slug, category_id, brand_id, description, price, compare_at_price,
    discount_percent, availability, image_url, package_size, quantity, volume,
    weight, dimensions, is_active, created_at, updated_at
) VALUES
    (
        'prod-1', 'AquaFlow 1.5L Mineral Water', 'aquaflow-15l-mineral-water',
        'cat-water', 'brand-aquaflow',
        'Refreshing mineral water for everyday hydration.',
        4.50, 5.50, 18, 'in_stock', 'https://images.example.com/water-15l.png',
        '1.5L bottle', 120, '1.5L', '1.5kg', '18 x 7 x 7 cm', TRUE,
        '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
    ),
    (
        'prod-2', 'PureDrop Family Pack', 'puredrop-family-pack',
        'cat-bulk', 'brand-pure',
        'High-quality water for households and recurring deliveries.',
        24.00, 30.00, 20, 'low_stock', 'https://images.example.com/family-pack.png',
        '12 x 1.5L', 36, '18L', '18kg', '40 x 30 x 20 cm', TRUE,
        '2026-01-10T00:00:00Z', '2026-01-10T00:00:00Z'
    ),
    (
        'prod-3', 'Nature Spring 330ml Can', 'nature-spring-330ml-can',
        'cat-water', 'brand-nature',
        'Lightweight, easy-drink sparkling water.',
        2.75, 3.25, 15, 'in_stock', 'https://images.example.com/sparkling-can.png',
        '330ml can', 200, '330ml', '0.4kg', '12 x 6 x 6 cm', TRUE,
        '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z'
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    slug = EXCLUDED.slug,
    category_id = EXCLUDED.category_id,
    brand_id = EXCLUDED.brand_id,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    compare_at_price = EXCLUDED.compare_at_price,
    discount_percent = EXCLUDED.discount_percent,
    availability = EXCLUDED.availability,
    image_url = EXCLUDED.image_url,
    package_size = EXCLUDED.package_size,
    quantity = EXCLUDED.quantity,
    volume = EXCLUDED.volume,
    weight = EXCLUDED.weight,
    dimensions = EXCLUDED.dimensions,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

INSERT INTO product_variants (
    id, product_id, sku, barcode, package_size, quantity, volume, weight,
    dimensions, price, compare_at_price, discount_percent, is_available, created_at, updated_at
) VALUES
    ('var-1', 'prod-1',
        'AF-15L-001', '1234567890123', '1.5L bottle', 12, '1.5L', '1.5kg', '18 x 7 x 7 cm',
        4.50, 5.50, 18, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('var-2', 'prod-2',
        'PD-12X15L', '2345678901234', '12 x 1.5L', 4, '18L', '18kg', '40 x 30 x 20 cm',
        24.00, 30.00, 20, TRUE, '2026-01-10T00:00:00Z', '2026-01-10T00:00:00Z'),
    ('var-3', 'prod-3',
        'NS-330ML-001', '3456789012345', '330ml can', 15, '330ml', '0.4kg', '12 x 6 x 6 cm',
        2.75, 3.25, 15, TRUE, '2026-02-01T00:00:00Z', '2026-02-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    product_id = EXCLUDED.product_id,
    sku = EXCLUDED.sku,
    barcode = EXCLUDED.barcode,
    package_size = EXCLUDED.package_size,
    quantity = EXCLUDED.quantity,
    volume = EXCLUDED.volume,
    weight = EXCLUDED.weight,
    dimensions = EXCLUDED.dimensions,
    price = EXCLUDED.price,
    compare_at_price = EXCLUDED.compare_at_price,
    discount_percent = EXCLUDED.discount_percent,
    is_available = EXCLUDED.is_available,
    updated_at = EXCLUDED.updated_at;

INSERT INTO cities (id, name, country_code, region, is_active, created_at, updated_at) VALUES
    ('city-riyadh', 'Riyadh', 'SA', 'Central', TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('city-jeddah', 'Jeddah', 'SA', 'Western', TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    country_code = EXCLUDED.country_code,
    region = EXCLUDED.region,
    is_active = TRUE,
    updated_at = EXCLUDED.updated_at;

INSERT INTO delivery_zones (id, city_id, name, base_fee, express_fee, estimated_minutes, is_active, created_at, updated_at) VALUES
    ('zone-riyadh-central', 'city-riyadh', 'Central Riyadh', 12, 10, 30, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
    ('zone-jeddah-central', 'city-jeddah', 'Central Jeddah', 14, 10, 35, TRUE, '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    city_id = EXCLUDED.city_id,
    name = EXCLUDED.name,
    base_fee = EXCLUDED.base_fee,
    express_fee = EXCLUDED.express_fee,
    estimated_minutes = EXCLUDED.estimated_minutes,
    is_active = TRUE,
    updated_at = EXCLUDED.updated_at;
