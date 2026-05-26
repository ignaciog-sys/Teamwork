-- ═════════════════════════════════════════════════════════════
--                 CREAR SCHEMAS INICIALES
-- ═════════════════════════════════════════════════════════════

-- Schema de staging (datos temporales)
CREATE SCHEMA IF NOT EXISTS staging
    AUTHORIZATION datanalyst;

-- Schema analítico (dimensional)
CREATE SCHEMA IF NOT EXISTS analytics
    AUTHORIZATION datanalyst;

-- Schema de reporting (vistas agregadas)
CREATE SCHEMA IF NOT EXISTS reporting
    AUTHORIZATION datanalyst;

-- Schema de auditoría y control
CREATE SCHEMA IF NOT EXISTS audit
    AUTHORIZATION datanalyst;

-- Dar permisos básicos
GRANT USAGE ON SCHEMA staging TO public;
GRANT USAGE ON SCHEMA analytics TO public;
GRANT USAGE ON SCHEMA reporting TO public;
GRANT USAGE ON SCHEMA audit TO public;

-- Comentarios
COMMENT ON SCHEMA staging IS 'Tablas temporales para cargas ETL';
COMMENT ON SCHEMA analytics IS 'Tablas de dimensiones y hechos (Data Warehouse)';
COMMENT ON SCHEMA reporting IS 'Vistas materializadas y reportes OLAP';
COMMENT ON SCHEMA audit IS 'Tablas de auditoría y control';

-- ═════════════════════════════════════════════════════════════
--              TABLA DE CONTROL ETL
-- ═════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS analytics.etl_log (
    etl_id SERIAL PRIMARY KEY,
    etl_name VARCHAR(100) NOT NULL,
    etl_start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    etl_end_time TIMESTAMP,
    etl_status VARCHAR(20) 
        CHECK (etl_status IN ('RUNNING', 'SUCCESS', 'FAILED', 'PARTIAL')),
    etl_records_processed INT DEFAULT 0,
    etl_records_failed INT DEFAULT 0,
    etl_duration_seconds INT,
    etl_error_message TEXT,
    etl_version VARCHAR(20),
    
    CONSTRAINT fk_status_check CHECK (
        (etl_status != 'SUCCESS' OR etl_records_failed = 0) AND
        (etl_end_time IS NULL OR etl_end_time >= etl_start_time)
    )
);

CREATE INDEX idx_etl_log_start ON analytics.etl_log(etl_start_time DESC);
CREATE INDEX idx_etl_log_status ON analytics.etl_log(etl_status);

COMMENT ON TABLE analytics.etl_log IS 'Registro de ejecuciones del pipeline ETL';
COMMENT ON COLUMN analytics.etl_log.etl_name IS 'Nombre del pipeline ejecutado';
COMMENT ON COLUMN analytics.etl_log.etl_status IS 'Estado final de ejecución';

-- ═════════════════════════════════════════════════════════════
--         TABLA DE METADATA (Control de actualizaciones)
-- ═════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS analytics.metadata_control (
    table_name VARCHAR(100) PRIMARY KEY,
    schema_name VARCHAR(50) DEFAULT 'analytics',
    last_update TIMESTAMP,
    row_count INT DEFAULT 0,
    data_quality_score DECIMAL(5,2),
    last_etl_id INT,
    notes TEXT,
    
    FOREIGN KEY (last_etl_id) REFERENCES analytics.etl_log(etl_id)
);

COMMENT ON TABLE analytics.metadata_control IS 'Metadata de control para cada tabla';
COMMENT ON COLUMN analytics.metadata_control.data_quality_score IS 'Score 0-100 de calidad de datos';

-- ═════════════════════════════════════════════════════════════
--            TABLA DE AUDITORIA
-- ═════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS audit.change_log (
    change_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100),
    old_values JSONB,
    new_values JSONB,
    change_reason TEXT
);

CREATE INDEX idx_change_log_table ON audit.change_log(table_name);
CREATE INDEX idx_change_log_timestamp ON audit.change_log(changed_at DESC);

COMMENT ON TABLE audit.change_log IS 'Registro de cambios en tablas críticas';

-- ═════════════════════════════════════════════════════════════
--              INICIALIZACIONES FINALES
-- ═════════════════════════════════════════════════════════════

-- Crear el primer registro de control
INSERT INTO analytics.metadata_control (table_name, schema_name, notes)
VALUES 
    ('dim_cliente', 'analytics', 'Dimensión de clientes'),
    ('dim_producto', 'analytics', 'Dimensión de productos'),
    ('dim_fecha', 'analytics', 'Dimensión temporal'),
    ('dim_ubicacion', 'analytics', 'Dimensión geográfica'),
    ('dim_pago', 'analytics', 'Dimensión de métodos de pago'),
    ('dim_estado', 'analytics', 'Dimensión de estados de orden'),
    ('fact_orden', 'analytics', 'Tabla de hechos: órdenes'),
    ('mv_ventas_diarias', 'reporting', 'Vista materializada: ventas diarias'),
    ('mv_rfm_clientes', 'reporting', 'Vista materializada: RFM clientes'),
    ('mv_producto_vendido', 'reporting', 'Vista materializada: desempeño de productos')
ON CONFLICT (table_name) DO NOTHING;

-- Log de creación de schemas
INSERT INTO analytics.etl_log (etl_name, etl_status, etl_records_processed)
VALUES ('Schema Creation', 'SUCCESS', 4)
ON CONFLICT DO NOTHING;

-- Dar permisos finales
GRANT CREATE ON DATABASE warehouse TO datanalyst;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO datanalyst;
GRANT ALL PRIVILEGES ON SCHEMA staging TO datanalyst;
GRANT ALL PRIVILEGES ON SCHEMA reporting TO datanalyst;
GRANT ALL PRIVILEGES ON SCHEMA audit TO datanalyst;

-- Habilitar extensiones útiles
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

COMMIT;
