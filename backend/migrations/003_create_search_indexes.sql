CREATE INDEX IF NOT EXISTS idx_products_search_name ON products USING gin (to_tsvector('english', name));
CREATE INDEX IF NOT EXISTS idx_products_search_description ON products USING gin (to_tsvector('english', description));
CREATE INDEX IF NOT EXISTS idx_products_price ON products (price);
