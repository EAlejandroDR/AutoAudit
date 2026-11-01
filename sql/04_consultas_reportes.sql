
-- SCRIPT 04: CONSULTAS DE AUDITORÍA Y REPORTES

-- Consulta de historial completo ordenado por fecha más reciente
SELECT 
    id_bitacora,
    tabla_nombre,
    columna_nombre,
    tipo_operacion,
    valor_anterior,
    valor_nuevo,
    usuario_bd,
    ip_origen,
    fecha_hora
FROM bitacora_auditoria
ORDER BY fecha_hora DESC;

-- Consulta con filtros dinámicos (Por usuario y columna)
SELECT * 
FROM bitacora_auditoria
WHERE usuario_bd ILIKE '%postgres%'
  AND columna_nombre ILIKE '%correo%'
ORDER BY fecha_hora DESC;
