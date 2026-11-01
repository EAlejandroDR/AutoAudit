
-- SCRIPT 05: SEGURIDAD Y PROTECCIÓN DE LA BITÁCORA


-- Revocar permisos de modificación directa sobre la bitácora a usuarios estándar
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON bitacora_auditoria FROM PUBLIC;

-- Permitir que el trigger escriba en la bitácora con privilegios elevados de su creador
ALTER FUNCTION fn_procesar_auditoria() SECURITY DEFINER;
