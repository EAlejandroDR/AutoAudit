
-- SCRIPT 01: DDL DEL SISTEMA AutoAudit


CREATE TABLE IF NOT EXISTS estaciones_trabajo (
    id_estacion SERIAL PRIMARY KEY,
    nombre_estacion VARCHAR(100),
    ip_estacion INET NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS usuarios_auditados (
    id_usuario SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    rol VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS tablas_auditadas (
    id_tabla SERIAL PRIMARY KEY,
    nombre_esquema VARCHAR(50) NOT NULL DEFAULT 'public',
    nombre_tabla VARCHAR(100) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_esquema_tabla UNIQUE (nombre_esquema, nombre_tabla)
);

CREATE TABLE IF NOT EXISTS columnas_auditadas (
    id_columna SERIAL PRIMARY KEY,
    id_tabla INT NOT NULL REFERENCES tablas_auditadas(id_tabla) ON DELETE CASCADE,
    nombre_columna VARCHAR(100) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_tabla_columna UNIQUE (id_tabla, nombre_columna)
);

CREATE TABLE IF NOT EXISTS eventos_auditados (
    id_evento SERIAL PRIMARY KEY,
    tipo_evento VARCHAR(10) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS configuracion_auditoria (
    id_config SERIAL PRIMARY KEY,
    id_columna INT NOT NULL REFERENCES columnas_auditadas(id_columna) ON DELETE CASCADE,
    id_evento INT NOT NULL REFERENCES eventos_auditados(id_evento) ON DELETE CASCADE,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_columna_evento UNIQUE (id_columna, id_evento)
);

CREATE TABLE IF NOT EXISTS bitacora_auditoria (
    id_bitacora BIGSERIAL PRIMARY KEY,
    id_config INT REFERENCES configuracion_auditoria(id_config) ON DELETE SET NULL,
    esquema_nombre VARCHAR(50) NOT NULL,
    tabla_nombre VARCHAR(100) NOT NULL,
    columna_nombre VARCHAR(100) NOT NULL,
    tipo_operacion VARCHAR(10) NOT NULL,
    valor_anterior TEXT,
    valor_nuevo TEXT,
    usuario_bd VARCHAR(100) NOT NULL,
    ip_origen INET,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
