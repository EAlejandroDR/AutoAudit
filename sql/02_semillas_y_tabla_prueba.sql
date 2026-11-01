
-- SCRIPT 02: DATOS INICIALES (SEMILLAS) Y TABLA DE PRUEBA


-- Poblar catálogo de eventos auditables
INSERT INTO eventos_auditados (tipo_evento) 
VALUES ('INSERT'), ('UPDATE'), ('DELETE')
ON CONFLICT (tipo_evento) DO NOTHING;

-- Tabla de prueba sobre la cual se aplicará la auditoría
CREATE TABLE IF NOT EXISTS clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100),
    telefono VARCHAR(20)
);
