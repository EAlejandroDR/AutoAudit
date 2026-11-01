
-- SCRIPT 06: PRUEBAS DE RENDIMIENTO Y VOLUMETRÍA

-- Prueba 1: Inserción masiva de 10,000 registros
EXPLAIN ANALYZE
INSERT INTO clientes (nombre, correo, telefono)
SELECT 
    'Cliente_' || i,
    'usuario_' || i || '@test.com',
    '5555-' || LPAD(i::text, 4, '0')
FROM generate_series(1, 10000) AS i;

-- Prueba 2: Actualización masiva
EXPLAIN ANALYZE
UPDATE clientes 
SET correo = 'actualizado_' || id_cliente || '@test.com';

-- Prueba 3: Verificación del volumen en bitácora y espacio consumido
SELECT COUNT(*) AS total_registros_bitacora FROM bitacora_auditoria;
SELECT pg_size_pretty(pg_total_relation_size('bitacora_auditoria')) AS tamano_bitacora;

-- Prueba 4: Eliminación masiva
EXPLAIN ANALYZE
DELETE FROM clientes WHERE id_cliente <= 5000;
