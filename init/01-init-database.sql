-- Crear base de datos principal
CREATE DATABASE IF NOT EXISTS andes_db;

-- Usar la base de datos
USE andes_db;

-- Crear tabla de ejemplo para logs de eventos
CREATE TABLE IF NOT EXISTS event_logs (
    id UInt64,
    timestamp DateTime DEFAULT now(),
    event_type LowCardinality(String),
    user_id UInt32,
    session_id String,
    ip_address IPv4,
    user_agent String,
    url String,
    status_code UInt16,
    response_time_ms UInt32,
    bytes_sent UInt64,
    referrer String,
    country LowCardinality(String),
    city LowCardinality(String),
    device_type LowCardinality(String),
    browser LowCardinality(String),
    os LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, event_type, user_id)
TTL timestamp + INTERVAL 90 DAY;

-- Crear tabla de ejemplo para métricas de rendimiento
CREATE TABLE IF NOT EXISTS performance_metrics (
    timestamp DateTime DEFAULT now(),
    metric_name LowCardinality(String),
    metric_value Float64,
    instance_id String,
    service_name LowCardinality(String),
    environment LowCardinality(String) DEFAULT 'production',
    tags Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, metric_name, instance_id)
TTL timestamp + INTERVAL 30 DAY;

-- Crear tabla de ejemplo para datos de usuarios
CREATE TABLE IF NOT EXISTS user_activity (
    user_id UInt32,
    activity_date Date DEFAULT today(),
    page_views UInt32,
    session_duration UInt32,
    actions_count UInt16,
    last_action_timestamp DateTime,
    device_type LowCardinality(String),
    channel LowCardinality(String)
) ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(activity_date)
ORDER BY (user_id, activity_date, device_type)
TTL activity_date + INTERVAL 365 DAY;

-- Crear vista materializada para resúmenes diarios
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_summary
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, event_type)
AS SELECT 
    toDate(timestamp) as date,
    event_type,
    count() as total_events,
    uniq(user_id) as unique_users,
    avg(response_time_ms) as avg_response_time
FROM event_logs
GROUP BY date, event_type;

-- Insertar algunos datos de ejemplo
INSERT INTO event_logs (id, event_type, user_id, session_id, ip_address, url, status_code, response_time_ms, country, device_type) VALUES
(1, 'page_view', 1001, 'sess_001', '192.168.1.100', '/home', 200, 150, 'Argentina', 'desktop'),
(2, 'click', 1001, 'sess_001', '192.168.1.100', '/products', 200, 89, 'Argentina', 'desktop'),
(3, 'page_view', 1002, 'sess_002', '192.168.1.101', '/login', 200, 234, 'Chile', 'mobile'),
(4, 'login', 1002, 'sess_002', '192.168.1.101', '/dashboard', 200, 445, 'Chile', 'mobile');

INSERT INTO performance_metrics (metric_name, metric_value, instance_id, service_name) VALUES
('cpu_usage', 45.2, 'web-01', 'frontend'),
('memory_usage', 67.8, 'web-01', 'frontend'),
('response_time', 120.5, 'api-01', 'backend'),
('db_connections', 25, 'db-01', 'database');

INSERT INTO user_activity (user_id, page_views, session_duration, actions_count, device_type, channel) VALUES
(1001, 15, 1200, 8, 'desktop', 'organic'),
(1002, 7, 450, 3, 'mobile', 'social'),
(1003, 23, 2100, 12, 'tablet', 'email');

-- Crear algunos índices útiles
CREATE INDEX IF NOT EXISTS idx_event_user ON event_logs (user_id) TYPE minmax GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_event_status ON event_logs (status_code) TYPE set(100) GRANULARITY 1;