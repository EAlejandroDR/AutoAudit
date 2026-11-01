from flask import Flask, render_template, request, redirect, url_for, flash
import psycopg
from psycopg.rows import dict_row
import csv
from io import StringIO
from flask import Response

app = Flask(__name__)
app.secret_key = 'autoaudit_secret_key'

# Configuración de conexión a PostgreSQL
DB_CONFIG = {
    'dbname': 'ProyecroBD',
    'user': 'postgres',
    'password': '1234',
    'host': 'localhost',
    'port': '5432'
}

def get_db_connection():
    conn = psycopg.connect(**DB_CONFIG, row_factory=dict_row)
    return conn

# -------------------------------------------------------------------
# MÓDULO DE CONFIGURACIÓN DE AUDITORÍA
# -------------------------------------------------------------------
@app.route('/exportar_csv', methods=['GET'])
def exportar_csv():
    usuario_filtro = request.args.get('usuario', '').strip()
    columna_filtro = request.args.get('columna', '').strip()

    conn = get_db_connection()
    cur = conn.cursor()

    query = """
        SELECT id_bitacora, esquema_nombre, tabla_nombre, columna_nombre,
               tipo_operacion, valor_anterior, valor_nuevo, usuario_bd, 
               ip_origen, fecha_hora
        FROM bitacora_auditoria
        WHERE 1=1
    """
    params = []

    if usuario_filtro:
        query += " AND usuario_bd ILIKE %s"
        params.append(f"%{usuario_filtro}%")

    if columna_filtro:
        query += " AND columna_nombre ILIKE %s"
        params.append(f"%{columna_filtro}%")

    query += " ORDER BY fecha_hora DESC;"
    cur.execute(query, params)
    registros = cur.fetchall()
    cur.close()
    conn.close()

    # Generación de archivo CSV en memoria
    si = StringIO()
    cw = csv.writer(si)
    cw.writerow(['ID', 'Esquema', 'Tabla', 'Columna', 'Operacion', 'Valor Anterior', 'Valor Nuevo', 'Usuario BD', 'IP Origen', 'Fecha/Hora'])

    for r in registros:
        cw.writerow([
            r['id_bitacora'], r['esquema_nombre'], r['tabla_nombre'], r['columna_nombre'],
            r['tipo_operacion'], r['valor_anterior'], r['valor_nuevo'], r['usuario_bd'],
            r['ip_origen'], r['fecha_hora']
        ])

    output = Response(si.getvalue(), mimetype='text/csv')
    output.headers["Content-Disposition"] = "attachment; filename=reporte_bitacora_autoaudit.csv"
    return output

@app.route('/')
@app.route('/configuracion', methods=['GET'])
def vista_configuracion():
    conn = get_db_connection()
    cur = conn.cursor()

    # 1. Obtener tablas del diccionario de datos de PostgreSQL
    cur.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
          AND table_type = 'BASE TABLE'
          AND table_name NOT IN (
              'estaciones_trabajo', 'usuarios_auditados', 'tablas_auditadas',
              'columnas_auditadas', 'eventos_auditados', 'configuracion_auditoria',
              'bitacora_auditoria'
          )
        ORDER BY table_name;
    """)
    tablas_bd = cur.fetchall()

    tabla_seleccionada = request.args.get('tabla')
    columnas_tabla = []
    config_actual = {}

    if tabla_seleccionada:
        # 2. Obtener columnas de la tabla seleccionada
        cur.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position;
        """, (tabla_seleccionada,))
        columnas_tabla = cur.fetchall()

        # 3. Cargar estado de auditoría configurado previamente
        cur.execute("""
            SELECT col.nombre_columna, e.tipo_evento, ca.activa
            FROM configuracion_auditoria ca
            JOIN columnas_auditadas col ON ca.id_columna = col.id_columna
            JOIN tablas_auditadas t ON col.id_tabla = t.id_tabla
            JOIN eventos_auditados e ON ca.id_evento = e.id_evento
            WHERE t.nombre_tabla = %s AND t.nombre_esquema = 'public';
        """, (tabla_seleccionada,))
        
        for row in cur.fetchall():
            clave = f"{row['nombre_columna']}_{row['tipo_evento']}"
            config_actual[clave] = row['activa']

    cur.close()
    conn.close()

    return render_template(
        'configuracion.html',
        tablas=tablas_bd,
        tabla_seleccionada=tabla_seleccionada,
        columnas=columnas_tabla,
        config_actual=config_actual
    )


@app.route('/guardar_configuracion', methods=['POST'])
def guardar_configuracion():
    tabla = request.form.get('tabla')
    if not tabla:
        flash('Seleccione una tabla válida.', 'danger')
        return redirect(url_for('vista_configuracion'))

    conn = get_db_connection()
    cur = conn.cursor()

    try:
        # Registrar tabla si no existe en tablas_auditadas
        cur.execute("""
            INSERT INTO tablas_auditadas (nombre_esquema, nombre_tabla, activa)
            VALUES ('public', %s, TRUE)
            ON CONFLICT (nombre_esquema, nombre_tabla) 
            DO UPDATE SET activa = TRUE
            RETURNING id_tabla;
        """, (tabla,))
        id_tabla = cur.fetchone()['id_tabla']

        # Obtener columnas enviadas desde el formulario
        cur.execute("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = %s;
        """, (tabla,))
        columnas_bd = [row['column_name'] for row in cur.fetchall()]

        eventos = ['INSERT', 'UPDATE', 'DELETE']

        for col in columnas_bd:
            # Registrar columna
            cur.execute("""
                INSERT INTO columnas_auditadas (id_tabla, nombre_columna, activa)
                VALUES (%s, %s, TRUE)
                ON CONFLICT (id_tabla, nombre_columna) 
                DO UPDATE SET activa = TRUE
                RETURNING id_columna;
            """, (id_tabla, col))
            id_columna = cur.fetchone()['id_columna']

            for ev in eventos:
                campo_form = f"check_{col}_{ev}"
                esta_activo = True if request.form.get(campo_form) else False

                cur.execute("""
                    SELECT id_evento FROM eventos_auditados WHERE tipo_evento = %s;
                """, (ev,))
                id_evento = cur.fetchone()['id_evento']

                cur.execute("""
                    INSERT INTO configuracion_auditoria (id_columna, id_evento, activa)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (id_columna, id_evento) 
                    DO UPDATE SET activa = EXCLUDED.activa;
                """, (id_columna, id_evento, esta_activo))

        # Desplegar/Actualizar Trigger dinámicamente en PostgreSQL
        cur.execute("CALL sp_generar_trigger_tabla('public', %s);", (tabla,))
        
        conn.commit()
        flash(f'Configuración guardada y Trigger desplegado exitosamente para "{tabla}".', 'success')

    except Exception as e:
        conn.rollback()
        flash(f'Error al guardar la configuración: {str(e)}', 'danger')
    finally:
        cur.close()
        conn.close()

    return redirect(url_for('vista_configuracion', tabla=tabla))


# -------------------------------------------------------------------
# MÓDULO DE CONSULTA Y REPORTE DE BITÁCORA
# -------------------------------------------------------------------

@app.route('/bitacora', methods=['GET'])
def vista_bitacora():
    usuario_filtro = request.args.get('usuario', '').strip()
    columna_filtro = request.args.get('columna', '').strip()

    conn = get_db_connection()
    cur = conn.cursor()

    query = """
        SELECT id_bitacora, esquema_nombre, tabla_nombre, columna_nombre,
               tipo_operacion, valor_anterior, valor_nuevo, usuario_bd, 
               ip_origen, fecha_hora
        FROM bitacora_auditoria
        WHERE 1=1
    """
    params = []

    if usuario_filtro:
        query += " AND usuario_bd ILIKE %s"
        params.append(f"%{usuario_filtro}%")

    if columna_filtro:
        query += " AND columna_nombre ILIKE %s"
        params.append(f"%{columna_filtro}%")

    query += " ORDER BY fecha_hora DESC LIMIT 100;"

    cur.execute(query, params)
    registros = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        'bitacora.html',
        registros=registros,
        usuario_filtro=usuario_filtro,
        columna_filtro=columna_filtro
    )


if __name__ == '__main__':
    app.run(debug=True, port=5000)
