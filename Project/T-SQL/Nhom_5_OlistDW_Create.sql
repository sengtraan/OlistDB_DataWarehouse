CREATE DATABASE OlistDW
GO

USE OlistDW
GO

----------------------------------------------------------------------------- Tạo các Dimension ---------------------------------------------------------------------------------------------

-- Tạo Dim Customer
CREATE TABLE dim_customer (
	customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id NVARCHAR(100),
    customer_unique_id NVARCHAR(100),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(100)
);
GO

-- Tạo Dim Seller
CREATE TABLE dim_seller (
    seller_key INT IDENTITY(1,1) PRIMARY KEY,
	seller_id NVARCHAR(100),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(100)
);
GO

-- Tạo Dim Date
CREATE TABLE dim_date_time (
    date_time_key VARCHAR(20) PRIMARY KEY, 
    date_key INT,                          
    time_key INT,                       
    hour INT,
    minute INT,
    second INT,
    day INT,
    month INT,
    year INT,
    weekday_name VARCHAR(20),
    weekday_number INT,
    month_name VARCHAR(20),
    quarter INT,
    is_weekend BIT
);
GO

-- Tạo Dim Product
CREATE TABLE dim_product (
	product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id NVARCHAR(100),
    product_category_name NVARCHAR(100),
    product_category_name_english NVARCHAR(100),
    product_length_cm float,
    product_height_cm float,
    product_width_cm float,
    product_weight_g float
);
GO

-- Tạo Dim Review
CREATE TABLE dim_review (
    review_key INT IDENTITY(1,1) PRIMARY KEY,
    review_id NVARCHAR(50),    
    order_id NVARCHAR(50),
    review_score TINYINT,
    review_creation_date DATETIME
);
GO

-- Tạo Dim Orders
CREATE TABLE dim_orders (
    order_key INT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(50),
    customer_id NVARCHAR(50),
    order_status NVARCHAR(50),
    order_purchase_timestamp DATETIME2(7),
    order_approved_at DATETIME2(7),
    order_delivered_carrier_date DATETIME2(7),
    order_delivered_customer_date DATETIME2(7),
    order_estimated_delivery_date DATETIME2(7)
);
GO

-- Tạo Dim Orders Items
CREATE TABLE dim_order_items (
    order_item_key INT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(50),
    order_item_id INT,
    product_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    shipping_limit_date DATETIME2(7),
    price FLOAT,
    freight_value FLOAT
);
GO

-- Tạo Dim Orders Payment
CREATE TABLE dim_order_payments (
    order_payment_key INT IDENTITY(1,1) PRIMARY KEY,
    order_id NVARCHAR(50),
    payment_sequential INT,
    payment_type NVARCHAR(50),
    payment_installments INT,
    payment_value FLOAT
);
GO


----------------------------------------------------------------------------- Tạo các Fact ---------------------------------------------------------------------------------------------

-- Tạo Fact Order Fulfillment & Delivery Performance
CREATE TABLE fact_order_fulfillment (
    fact_order_fulfillment_key INT IDENTITY(1,1) PRIMARY KEY,
	customer_key INT,
	seller_key INT,
	date_time_key VARCHAR(20),
	order_key INT,
	order_item_key INT, 
	order_id NVARCHAR(100),
    customer_id NVARCHAR(100),
    seller_id NVARCHAR(100),
    order_purchase_date DATETIME,
    order_approved_date DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME,
    delivery_days INT, -- Thực tế
    estimated_days INT, -- Dự kiến
    late_delivery bit, -- order_delivered_customer_date > order_estimated_delivery_date
	--PRIMARY KEY(seller_key,order_id, seller_id, customer_key, customer_id),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key),
	FOREIGN KEY (date_time_key) REFERENCES dim_date_time(date_time_key),
	FOREIGN KEY (order_key) REFERENCES dim_orders(order_key),
	FOREIGN KEY (order_item_key) REFERENCES dim_order_items(order_item_key)

);
GO


-- Tạo Fact Sales
CREATE TABLE fact_sales (
    fact_sales_key INT IDENTITY(1,1),
	product_key INT,
	seller_key INT, 
	customer_key INT,
	order_payment_key INT,
	date_time_key VARCHAR(20),
	order_key INT,
	order_item_key INT,
	order_id NVARCHAR(100),
    order_item_id INT,
    product_id NVARCHAR(100),
    seller_id NVARCHAR(100),
    customer_id NVARCHAR(100),
    payment_type NVARCHAR(100),
    price FLOAT,
    freight_value FLOAT,
    payment_value FLOAT,
    order_purchase_date DATETIME,
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (order_payment_key) REFERENCES dim_order_payments(order_payment_key),
	FOREIGN KEY (date_time_key) REFERENCES dim_date_time(date_time_key),
	FOREIGN KEY (order_key) REFERENCES dim_orders(order_key),
	FOREIGN KEY (order_item_key) REFERENCES dim_order_items(order_item_key)
);
GO

-- Tạo Fact Product Seller & Performance
CREATE TABLE fact_product_seller_performance (
	fact_id INT IDENTITY(1,1) PRIMARY KEY,
    order_item_id TINYINT,
    order_id NVARCHAR(50),
    product_key INT,
    seller_key INT,
    review_key INT,
    datetime_key VARCHAR(20),
    price FLOAT,
    freight_value FLOAT,
    review_score TINYINT,
    review_create_datetime VARCHAR(20),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (seller_key) REFERENCES dim_seller(seller_key),
    FOREIGN KEY (review_key) REFERENCES dim_review(review_key),
    FOREIGN KEY (datetime_key) REFERENCES dim_date_time(date_time_key),
    FOREIGN KEY (review_create_datetime) REFERENCES dim_date_time(date_time_key)
);
GO