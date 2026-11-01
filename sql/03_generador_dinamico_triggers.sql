
-- SCRIPT 03: FUNCIÓN Y GENERADOR DINÁMICO DE TRIGGERS

-- 1. Función Genérica que procesa e inserta en la bitácora
CREATE OR REPLACE FUNCTION fn_procesar_auditoria()
RETURNS TRIGGER AS $$
DECLARE
    v_rec RECORD;
    v_val_old TEXT;
    v_val_new TEXT;
    v_user VARCHAR;
    v_ip INET;
BEGIN
    v_user := session_user;
    BEGIN
        v_ip := inet_client_addr();
    EXCEPTION WHEN OTHERS THEN
        v_ip := '127.0.0.1'::inet;
    END;

    FOR v_rec IN 
        SELECT 
            ca.id_config,
            col.nombre_columna,
            e.tipo_evento
        FROM configuracion_auditoria ca
        JOIN columnas_auditadas col ON ca.id_columna = col.id_columna
        JOIN tablas_auditadas t ON col.id_tabla = t.id_tabla
        JOIN eventos_auditados e ON ca.id_evento = e.id_evento
        WHERE t.nombre_esquema = TG_TABLE_SCHEMA
          AND t.nombre_tabla = TG_TABLE_NAME
          AND t.activa = TRUE
          AND col.activa = TRUE
          AND ca.activa = TRUE
          AND e.tipo_evento = TG_OP
    LOOP
        v_val_old := NULL;
        v_val_new := NULL;

        IF (TG_OP = 'INSERT') THEN
            EXECUTE format('SELECT ($1).%I::text', v_rec.nombre_columna) USING NEW INTO v_val_new;
        ELSIF (TG_OP = 'UPDATE') THEN
            EXECUTE format('SELECT ($1).%I::text', v_rec.nombre_columna) USING OLD INTO v_val_old;
            EXECUTE format('SELECT ($1).%I::text', v_rec.nombre_columna) USING NEW INTO v_val_new;
            IF (v_val_old IS NOT DISTINCT FROM v_val_new) THEN
                CONTINUE;
            END IF;
        ELSIF (TG_OP = 'DELETE') THEN
            EXECUTE format('SELECT ($1).%I::text', v_rec.nombre_columna) USING OLD INTO v_val_old;
        END IF;

        INSERT INTO bitacora_auditoria (
            id_config, esquema_nombre, tabla_nombre, columna_nombre,
            tipo_operacion, valor_anterior, valor_nuevo, usuario_bd, ip_origen
        ) VALUES (
            v_rec.id_config, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_rec.nombre_columna,
            TG_OP, v_val_old, v_val_new, v_user, v_ip
        );
    END LOOP;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2. Procedimiento Almacenado que crea o reemplaza el Trigger en una tabla
CREATE OR REPLACE PROCEDURE sp_generar_trigger_tabla(p_esquema VARCHAR, p_tabla VARCHAR)
AS $$
DECLARE
    v_trg_name TEXT;
    v_sql TEXT;
BEGIN
    v_trg_name := format('trg_audit_%s_%s', p_esquema, p_tabla);
    
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.%I;', v_trg_name, p_esquema, p_tabla);

    v_sql := format('
        CREATE TRIGGER %I
        AFTER INSERT OR UPDATE OR DELETE ON %I.%I
        FOR EACH ROW
        EXECUTE FUNCTION fn_procesar_auditoria();
    ', v_trg_name, p_esquema, p_tabla);

    EXECUTE v_sql;
END;
$$ LANGUAGE plpgsql;
