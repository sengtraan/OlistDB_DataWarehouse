CREATE DATABASE OlistDWStage
GO

USE OlistDWStage
GO

SELECT * INTO stg_orders FROM OlistDB.dbo.orders;
SELECT * INTO stg_order_items FROM OlistDB.dbo.order_items;
SELECT * INTO stg_customers FROM OlistDB.dbo.customers;
SELECT * INTO stg_sellers FROM OlistDB.dbo.sellers;
SELECT * INTO stg_products FROM OlistDB.dbo.products;
SELECT * INTO stg_product_category_translation FROM OlistDB.dbo.product_category_name_translation;
SELECT * INTO stg_order_payments FROM OlistDB.dbo.order_payments;
SELECT * INTO stg_order_reviews FROM OlistDB.dbo.order_reviews;
GO


-- Staging Order Items
SELECT 
    o.order_id,
    order_item_id,
    product_id,
    seller_id,
    price,
    freight_value,
	o.order_purchase_timestamp
INTO dbo.stg_order_items_mix
FROM OlistDB.dbo.order_items oi left join OlistDB.dbo.orders o on oi.order_id = o.order_id;
Go


-- Staging Dim Reviews
SELECT 
    review_id,
    order_id,
    review_score,
    review_creation_date
INTO dbo.stg_dim_review
FROM OlistDB.dbo.order_reviews;
Go

USE OlistDW
GO

-------------------------------------------------------------- Load Dim ---------------------------------------------------------------------------------

-- Load dim_review
INSERT INTO dim_review (
    review_id,
    order_id,
    review_score,
    review_creation_date
)
SELECT
    review_id,
    order_id,
    review_score,
    review_creation_date
FROM OlistDWStage.dbo.stg_dim_review;
Go



-- Load vào dim_orders
INSERT INTO dbo.dim_orders (
    order_id, customer_id, order_status,
    order_purchase_timestamp, order_approved_at,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM OlistDWStage.dbo.stg_orders;
GO


-- Load vào dim_order_items
INSERT INTO dbo.dim_order_items (
    order_id, order_item_id, product_id, seller_id,
    shipping_limit_date, price, freight_value
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
FROM OlistDWStage.dbo.stg_order_items;
GO


-- Load vào dim_customer
INSERT INTO dbo.dim_customer (customer_id, customer_unique_id, customer_city, customer_state)
SELECT DISTINCT customer_id, customer_unique_id, customer_city, customer_state
FROM OlistDWStage.dbo.stg_customers;
GO

-- Load vào dim_seller
INSERT INTO dbo.dim_seller (seller_id, seller_city, seller_state)
SELECT DISTINCT seller_id, seller_city, seller_state
FROM OlistDWStage.dbo.stg_sellers;
GO

-- Load dim_date_time
BULK INSERT dim_date_time
FROM 'C:\Users\Asus\Desktop\Data_Engineer\Kho_du_lieu\project\olist_csv_export\DimDateTime.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2, 
    FIELDTERMINATOR = ',', 
    ROWTERMINATOR = '\n',
    TABLOCK,
    ERRORFILE = 'C:\Users\Asus\Desktop\DimDateTime_ErrorRows.log' 
);
Go


-- Load vào dim_product
INSERT INTO dbo.dim_product (
    product_id, product_category_name, product_category_name_english,
    product_length_cm, product_height_cm, product_width_cm, product_weight_g
)
SELECT 
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_length_cm, p.product_height_cm, p.product_width_cm, p.product_weight_g
FROM OlistDWStage.dbo.stg_products p
JOIN OlistDWStage.dbo.stg_product_category_translation t ON p.product_category_name = t.product_category_name;
GO


-- Load vào dim_order_payments
INSERT INTO dim_order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM OlistDWStage.dbo.stg_order_payments;
GO

---------------------------------------------------------------- Load Fact ------------------------------------------------------------------


-- Load vào fact_order_fulfillment
INSERT INTO dbo.fact_order_fulfillment (
    customer_key, seller_key, date_time_key,
    order_key, order_item_key, order_id,
    customer_id, seller_id,
    order_purchase_date, order_approved_date,
    order_delivered_carrier_date, order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_days, estimated_days, late_delivery
)
SELECT 
    dc.customer_key, ds.seller_key, d.date_time_key,
    o.order_key, oi.order_item_key, o.order_id,
    o.customer_id, oi.seller_id,
    o.order_purchase_timestamp, o.order_approved_at,
    o.order_delivered_carrier_date, o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date),
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date),
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
        ELSE 0 
    END
FROM OlistDW.dbo.dim_orders o
JOIN OlistDW.dbo.dim_order_items oi ON o.order_id = oi.order_id
JOIN OlistDW.dbo.dim_customer dc     ON dc.customer_id = o.customer_id
JOIN OlistDW.dbo.dim_seller ds       ON ds.seller_id = oi.seller_id
JOIN OlistDW.dbo.dim_date_time d     ON d.date_time_key = FORMAT(o.order_purchase_timestamp, 'yyyy-MM-dd HH:mm') + ':00';
GO




-- Load vào fact_sales
INSERT INTO dbo.fact_sales (
    product_key, seller_key, customer_key,
    order_payment_key, date_time_key,
    order_key, order_item_key,
    order_id, order_item_id, product_id, seller_id, customer_id,
    payment_type, price, freight_value, payment_value, order_purchase_date
)
SELECT 
    product_key, seller_key, customer_key,
    p.order_payment_key, d.date_time_key,
    o.order_key, oi.order_item_key,
    oi.order_id, oi.order_item_id, oi.product_id, oi.seller_id, o.customer_id,
    p.payment_type, oi.price, oi.freight_value, p.payment_value,
    o.order_purchase_timestamp
FROM OlistDW.dbo.dim_order_items oi
JOIN OlistDW.dbo.dim_orders o ON oi.order_id = o.order_id
LEFT JOIN (
    SELECT 
        order_payment_key, order_id, 
        MAX(payment_type) AS payment_type,
        SUM(payment_value) AS payment_value
    FROM OlistDW.dbo.dim_order_payments
    GROUP BY order_id, order_payment_key
) p ON oi.order_id = p.order_id
JOIN OlistDW.dbo.dim_product dp ON dp.product_id = oi.product_id
JOIN OlistDW.dbo.dim_seller ds ON ds.seller_id = oi.seller_id
JOIN OlistDW.dbo.dim_customer dc ON dc.customer_id = o.customer_id
JOIN OlistDW.dbo.dim_date_time d 
    ON d.date_time_key = FORMAT(o.order_purchase_timestamp, 'yyyy-MM-dd HH:mm') + ':00';
GO


-- Load Fact Product Seller Peformance
insert into OlistDW.dbo.fact_product_seller_performance
(order_item_id, order_id, price, freight_value, review_score, product_key, seller_key, review_key, datetime_key, review_create_datetime)
select 
	o.order_item_id,
	o.order_id,
	o.price,
	o.freight_value,
	r.review_score,
	p.product_key,
	s.seller_key,
	r.review_key,
	FORMAT(o.order_purchase_timestamp, 'yyyy-MM-dd HH:mm') + ':00' AS datetime_key,
	FORMAT(r.review_creation_date, 'yyyy-MM-dd HH:mm') + ':00' AS review_create_datetime
from OlistDWStage.dbo.stg_order_items_mix o 
join OlistDW.dbo.dim_product p on o.product_id = p.product_id
join OlistDW.dbo.dim_seller s on o.seller_id = s.seller_id
join OlistDW.dbo.dim_review r on o.order_id = r.order_id;
GO
