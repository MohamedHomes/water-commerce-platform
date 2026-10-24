ALTER TABLE categories
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(150),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

ALTER TABLE brands
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(150),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

ALTER TABLE products
    ADD COLUMN IF NOT EXISTS name_ar VARCHAR(200),
    ADD COLUMN IF NOT EXISTS description_ar TEXT;

UPDATE categories
SET name_ar = CASE id
        WHEN 'cat-water' THEN 'مياه معبأة'
        WHEN 'cat-boxes' THEN 'عبوات مياه'
        WHEN 'cat-bulk' THEN 'توريد بالجملة'
        ELSE name_ar
    END,
    description_ar = CASE id
        WHEN 'cat-water' THEN 'مياه عادية وفوارة'
        WHEN 'cat-boxes' THEN 'عبوات مياه جاهزة للشرب'
        WHEN 'cat-bulk' THEN 'توريد كميات كبيرة للمنازل والمنشآت'
        ELSE description_ar
    END
WHERE id IN ('cat-water', 'cat-boxes', 'cat-bulk');

UPDATE brands
SET name_ar = CASE id
        WHEN 'brand-aquaflow' THEN 'أكوافلو'
        WHEN 'brand-nature' THEN 'نيتشر سبرينغ'
        WHEN 'brand-pure' THEN 'بيور دروب'
        ELSE name_ar
    END
WHERE id IN ('brand-aquaflow', 'brand-nature', 'brand-pure');

UPDATE products
SET name_ar = CASE id
        WHEN 'prod-1' THEN 'مياه أكوافلو المعدنية ١٫٥ لتر'
        WHEN 'prod-2' THEN 'عبوة بيور دروب العائلية'
        WHEN 'prod-3' THEN 'مياه نيتشر سبرينغ ٣٣٠ مل'
        ELSE name_ar
    END,
    description_ar = CASE id
        WHEN 'prod-1' THEN 'مياه معدنية منعشة لترطيب يومي.'
        WHEN 'prod-2' THEN 'مياه عالية الجودة للمنازل والتوصيل الدوري.'
        WHEN 'prod-3' THEN 'مياه فوارة خفيفة وسهلة الشرب.'
        ELSE description_ar
    END
WHERE id IN ('prod-1', 'prod-2', 'prod-3');
