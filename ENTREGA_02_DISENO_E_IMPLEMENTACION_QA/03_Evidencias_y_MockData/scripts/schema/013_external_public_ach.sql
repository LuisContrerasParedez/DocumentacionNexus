-- Production deploy - paso 013
-- ACH publico entrante para bancos externos: rol, permisos, seed tecnico y procesamiento atomico.

WITH permisos_seed(codigo, nombre, descripcion, modulo, accion) AS (
    VALUES
        ('ach.public.auth.login', 'Login ACH publico', 'Permite autenticarse como banco externo en la Public API.', 'ACH_PUBLIC', 'login'),
        ('ach.public.cuentas.consultar', 'Consultar cuentas ACH publicas', 'Permite validar cuentas destino para ACH entrante.', 'ACH_PUBLIC', 'consultar'),
        ('ach.public.transferencias.crear', 'Crear transferencias ACH publicas', 'Permite registrar transferencias ACH entrantes.', 'ACH_PUBLIC', 'crear')
)
INSERT INTO seguridad.permisos (codigo, nombre, descripcion, modulo, accion, estado, created_at, updated_at)
SELECT codigo, nombre, descripcion, modulo, accion, true, now(), now()
FROM permisos_seed
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    modulo = EXCLUDED.modulo,
    accion = EXCLUDED.accion,
    estado = true,
    updated_at = now();

INSERT INTO seguridad.roles (codigo, nombre, descripcion, estado, created_at, updated_at)
VALUES ('BANCO_EXTERNO', 'BANCO_EXTERNO', 'Acceso exclusivo para bancos externos que consumen ACH publico.', true, now(), now())
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    estado = true,
    updated_at = now();

WITH rol_permiso_seed(rol_codigo, permiso_codigo) AS (
    VALUES
        ('BANCO_EXTERNO', 'ach.public.auth.login'),
        ('BANCO_EXTERNO', 'ach.public.cuentas.consultar'),
        ('BANCO_EXTERNO', 'ach.public.transferencias.crear')
)
INSERT INTO seguridad.roles_permisos (rol_id, permiso_id, created_at, created_by)
SELECT r.id, p.id, now(), NULL
FROM rol_permiso_seed x
INNER JOIN seguridad.roles r ON r.codigo = x.rol_codigo
INNER JOIN seguridad.permisos p ON p.codigo = x.permiso_codigo
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

DO $$
DECLARE
    v_has_descripcion boolean;
    v_has_tipo boolean;
    v_has_tipo_cuenta boolean;
    v_has_activo boolean;
    v_has_activa boolean;
    v_has_updated_at boolean;
    v_sql text;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'descripcion'
    ) INTO v_has_descripcion;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'tipo'
    ) INTO v_has_tipo;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'tipo_cuenta'
    ) INTO v_has_tipo_cuenta;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'activo'
    ) INTO v_has_activo;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'activa'
    ) INTO v_has_activa;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'contabilidad'
          AND table_name = 'plan_cuentas'
          AND column_name = 'updated_at'
    ) INTO v_has_updated_at;

    v_sql := '
        INSERT INTO contabilidad.plan_cuentas (
            codigo,
            nombre';

    IF v_has_descripcion THEN
        v_sql := v_sql || ',
            descripcion';
    END IF;

    IF v_has_tipo THEN
        v_sql := v_sql || ', tipo';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', tipo_cuenta';
    END IF;

    v_sql := v_sql || ',
            ';

    IF v_has_activa THEN
        v_sql := v_sql || 'activa';
    ELSIF v_has_activo THEN
        v_sql := v_sql || 'activo';
    ELSE
        RAISE EXCEPTION 'No existe columna activa/activo en contabilidad.plan_cuentas.';
    END IF;

    v_sql := v_sql || ',
            created_at';

    IF v_has_updated_at THEN
        v_sql := v_sql || ',
            updated_at';
    END IF;

    v_sql := v_sql || '
        )
        VALUES
            (''1102'', ''Compensacion ACH''';

    IF v_has_descripcion THEN
        v_sql := v_sql || ', ''Cuenta puente para acreditaciones ACH entrantes.''';
    END IF;

    IF v_has_tipo THEN
        v_sql := v_sql || ', ''ACTIVO''';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', ''ACTIVO''';
    END IF;

    v_sql := v_sql || ', true, now()';

    IF v_has_updated_at THEN
        v_sql := v_sql || ', now()';
    END IF;

    v_sql := v_sql || ')
        ON CONFLICT (codigo) DO UPDATE
        SET nombre = EXCLUDED.nombre';

    IF v_has_descripcion THEN
        v_sql := v_sql || ',
            descripcion = EXCLUDED.descripcion';
    END IF;

    IF v_has_tipo THEN
        v_sql := v_sql || ',
            tipo = EXCLUDED.tipo';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ',
            tipo_cuenta = EXCLUDED.tipo_cuenta';
    END IF;

    v_sql := v_sql || ',
            ';

    IF v_has_activa THEN
        v_sql := v_sql || 'activa = EXCLUDED.activa';
    ELSE
        v_sql := v_sql || 'activo = EXCLUDED.activo';
    END IF;

    IF v_has_updated_at THEN
        v_sql := v_sql || ',
            updated_at = now()';
    END IF;

    v_sql := v_sql || ';';

    EXECUTE v_sql;
END $$;

CREATE TABLE IF NOT EXISTS ach.transferencias_entrantes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_banco_externo_id uuid NOT NULL,
    banco_externo varchar(120) NOT NULL,
    cuenta_externa varchar(120) NOT NULL,
    cuenta_destino_id uuid NOT NULL,
    numero_cuenta_destino varchar(50) NOT NULL,
    monto numeric(18,2) NOT NULL,
    moneda varchar(10) NOT NULL DEFAULT 'GTQ',
    referencia text NULL,
    tipo varchar(20) NOT NULL DEFAULT 'ENTRANTE',
    codigo_confirmacion text NOT NULL,
    estado varchar(20) NOT NULL,
    movimiento_id uuid NULL,
    request_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    response_json jsonb NULL,
    mensaje_error text NULL,
    fecha_procesamiento timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS usuario_banco_externo_id uuid;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS banco_externo varchar(120);
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS cuenta_externa varchar(120);
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS cuenta_destino_id uuid;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS numero_cuenta_destino varchar(50);
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS monto numeric(18,2);
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS moneda varchar(10) DEFAULT 'GTQ';
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS referencia text;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS tipo varchar(20) DEFAULT 'ENTRANTE';
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS codigo_confirmacion text;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS estado varchar(20);
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS movimiento_id uuid;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS request_json jsonb DEFAULT '{}'::jsonb;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS response_json jsonb;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS mensaje_error text;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS fecha_procesamiento timestamptz;
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE ach.transferencias_entrantes ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

UPDATE ach.transferencias_entrantes
SET tipo = COALESCE(NULLIF(BTRIM(tipo), ''), 'ENTRANTE'),
    moneda = COALESCE(NULLIF(BTRIM(moneda), ''), 'GTQ'),
    request_json = COALESCE(request_json, '{}'::jsonb),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

CREATE UNIQUE INDEX IF NOT EXISTS ux_ach_transferencias_entrantes_codigo_confirmacion
    ON ach.transferencias_entrantes (codigo_confirmacion);

CREATE INDEX IF NOT EXISTS idx_ach_transferencias_entrantes_cuenta_destino
    ON ach.transferencias_entrantes (cuenta_destino_id);

CREATE INDEX IF NOT EXISTS idx_ach_transferencias_entrantes_usuario
    ON ach.transferencias_entrantes (usuario_banco_externo_id);

CREATE INDEX IF NOT EXISTS idx_ach_transferencias_entrantes_estado
    ON ach.transferencias_entrantes (estado);

CREATE INDEX IF NOT EXISTS idx_ach_transferencias_entrantes_fecha
    ON ach.transferencias_entrantes (COALESCE(fecha_procesamiento, created_at) DESC);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ach_transferencias_entrantes_usuario'
          AND conrelid = 'ach.transferencias_entrantes'::regclass
    ) THEN
        ALTER TABLE ach.transferencias_entrantes
            ADD CONSTRAINT fk_ach_transferencias_entrantes_usuario
            FOREIGN KEY (usuario_banco_externo_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ach_transferencias_entrantes_cuenta_destino'
          AND conrelid = 'ach.transferencias_entrantes'::regclass
    ) THEN
        ALTER TABLE ach.transferencias_entrantes
            ADD CONSTRAINT fk_ach_transferencias_entrantes_cuenta_destino
            FOREIGN KEY (cuenta_destino_id) REFERENCES cuentas.cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ach_transferencias_entrantes_movimiento'
          AND conrelid = 'ach.transferencias_entrantes'::regclass
    ) THEN
        ALTER TABLE ach.transferencias_entrantes
            ADD CONSTRAINT fk_ach_transferencias_entrantes_movimiento
            FOREIGN KEY (movimiento_id) REFERENCES transacciones.movimientos(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_ach_transferencias_entrantes_tipo'
          AND conrelid = 'ach.transferencias_entrantes'::regclass
    ) THEN
        ALTER TABLE ach.transferencias_entrantes
            ADD CONSTRAINT ck_ach_transferencias_entrantes_tipo
            CHECK (tipo IS NULL OR UPPER(tipo) = 'ENTRANTE');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_ach_transferencias_entrantes_estado'
          AND conrelid = 'ach.transferencias_entrantes'::regclass
    ) THEN
        ALTER TABLE ach.transferencias_entrantes
            ADD CONSTRAINT ck_ach_transferencias_entrantes_estado
            CHECK (estado IS NULL OR UPPER(estado) IN ('PENDIENTE', 'APROBADA', 'RECHAZADA', 'ERROR'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION ach.sp_registrar_transferencia_entrante_publica(
    p_usuario_banco_externo_id uuid,
    p_banco_externo text,
    p_cuenta_externa text,
    p_numero_cuenta_destino text,
    p_monto numeric,
    p_moneda text,
    p_referencia text DEFAULT NULL,
    p_codigo_confirmacion text DEFAULT NULL,
    p_request_json jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta_id uuid;
    v_cuenta_numero text;
    v_cuenta_estado text;
    v_cuenta_saldo numeric(18,2);
    v_cuenta_moneda text;
    v_cuenta_tipo_cuenta text;
    v_moneda text;
    v_descripcion text;
    v_saldo_anterior numeric(18,2);
    v_saldo_nuevo numeric(18,2);
    v_transferencia_id uuid;
    v_movimiento_id uuid;
    v_referencia_movimiento text;
    v_cuenta_pasivo_id uuid;
    v_cuenta_puente_id uuid;
    v_codigo_pasivo text;
    v_nombre_usuario text;
    v_plan_cuentas_activa_clause text;
    v_cuentas_has_moneda boolean;
    v_cuentas_has_tipo_cuenta boolean;
    v_cuentas_has_saldo_disponible boolean;
    v_cuentas_has_updated_at boolean;
    v_cuenta_sql text;
    v_update_cuenta_sql text;
    v_fecha_procesamiento timestamptz := now();
BEGIN
    IF p_usuario_banco_externo_id IS NULL THEN
        RAISE EXCEPTION 'Usuario banco externo requerido.';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_banco_externo, '')), '') IS NULL THEN
        RAISE EXCEPTION 'Banco externo requerido.';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_cuenta_externa, '')), '') IS NULL THEN
        RAISE EXCEPTION 'Cuenta externa requerida.';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_numero_cuenta_destino, '')), '') IS NULL THEN
        RAISE EXCEPTION 'Numero de cuenta destino requerido.';
    END IF;

    IF NULLIF(BTRIM(COALESCE(p_codigo_confirmacion, '')), '') IS NULL THEN
        RAISE EXCEPTION 'Codigo de confirmacion requerido.';
    END IF;

    IF p_monto IS NULL OR p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a cero.';
    END IF;

    v_moneda := UPPER(BTRIM(COALESCE(p_moneda, '')));
    IF v_moneda = 'Q' THEN
        v_moneda := 'GTQ';
    END IF;

    IF v_moneda <> 'GTQ' THEN
        RAISE EXCEPTION 'La moneda soportada para ACH entrante es GTQ.';
    END IF;

    SELECT CASE
        WHEN EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'contabilidad'
              AND table_name = 'plan_cuentas'
              AND column_name = 'activa'
        ) THEN 'COALESCE(activa, true) = true'
        WHEN EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'contabilidad'
              AND table_name = 'plan_cuentas'
              AND column_name = 'activo'
        ) THEN 'COALESCE(activo, true) = true'
        ELSE 'TRUE'
    END
    INTO v_plan_cuentas_activa_clause;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'cuentas'
          AND table_name = 'cuentas'
          AND column_name = 'moneda'
    ) INTO v_cuentas_has_moneda;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'cuentas'
          AND table_name = 'cuentas'
          AND column_name = 'tipo_cuenta'
    ) INTO v_cuentas_has_tipo_cuenta;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'cuentas'
          AND table_name = 'cuentas'
          AND column_name = 'saldo_disponible'
    ) INTO v_cuentas_has_saldo_disponible;

    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'cuentas'
          AND table_name = 'cuentas'
          AND column_name = 'updated_at'
    ) INTO v_cuentas_has_updated_at;

    SELECT COALESCE(NULLIF(BTRIM(username), ''), NULLIF(BTRIM(email), ''), 'bancoexterno')
    INTO v_nombre_usuario
    FROM seguridad.usuarios
    WHERE id = p_usuario_banco_externo_id
    LIMIT 1;

    PERFORM pg_advisory_xact_lock(hashtext(BTRIM(p_codigo_confirmacion)));

    IF EXISTS (
        SELECT 1
        FROM ach.transferencias_entrantes
        WHERE codigo_confirmacion = BTRIM(p_codigo_confirmacion)
    ) THEN
        RAISE unique_violation USING
            MESSAGE = 'El codigo de confirmacion ya fue procesado.',
            CONSTRAINT = 'ux_ach_transferencias_entrantes_codigo_confirmacion';
    END IF;

    v_cuenta_sql := '
        SELECT
            id,
            numero_cuenta,
            estado,
            COALESCE(saldo, 0) AS saldo,
            ';

    IF v_cuentas_has_moneda THEN
        v_cuenta_sql := v_cuenta_sql || 'COALESCE(NULLIF(BTRIM(moneda), ''''), ''GTQ'')';
    ELSE
        v_cuenta_sql := v_cuenta_sql || '''GTQ''';
    END IF;

    v_cuenta_sql := v_cuenta_sql || ' AS moneda, ';

    IF v_cuentas_has_tipo_cuenta THEN
        v_cuenta_sql := v_cuenta_sql || 'COALESCE(tipo_cuenta, '''')';
    ELSE
        v_cuenta_sql := v_cuenta_sql || '''''';
    END IF;

    v_cuenta_sql := v_cuenta_sql || ' AS tipo_cuenta
        FROM cuentas.cuentas
        WHERE UPPER(numero_cuenta) = UPPER(BTRIM($1))
        FOR UPDATE';

    EXECUTE v_cuenta_sql
    INTO v_cuenta_id, v_cuenta_numero, v_cuenta_estado, v_cuenta_saldo, v_cuenta_moneda, v_cuenta_tipo_cuenta
    USING p_numero_cuenta_destino;

    -- EXECUTE ... INTO no actualiza FOUND; se valida el id leido.
    IF v_cuenta_id IS NULL THEN
        RAISE EXCEPTION 'Cuenta destino no encontrada.';
    END IF;

    IF UPPER(COALESCE(v_cuenta_estado, '')) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La cuenta destino no esta activa.';
    END IF;

    IF UPPER(COALESCE(v_cuenta_moneda, 'GTQ')) <> v_moneda THEN
        RAISE EXCEPTION 'La moneda de la transferencia no coincide con la cuenta destino.';
    END IF;

    v_descripcion := COALESCE(NULLIF(BTRIM(p_referencia), ''), 'Transferencia ACH entrante');
    v_saldo_anterior := COALESCE(v_cuenta_saldo, 0);
    v_saldo_nuevo := v_saldo_anterior + p_monto;

    INSERT INTO ach.transferencias_entrantes (
        usuario_banco_externo_id,
        banco_externo,
        cuenta_externa,
        cuenta_destino_id,
        numero_cuenta_destino,
        monto,
        moneda,
        referencia,
        tipo,
        codigo_confirmacion,
        estado,
        request_json,
        response_json,
        mensaje_error,
        fecha_procesamiento,
        created_at,
        updated_at
    )
    VALUES (
        p_usuario_banco_externo_id,
        BTRIM(p_banco_externo),
        BTRIM(p_cuenta_externa),
        v_cuenta_id,
        UPPER(BTRIM(p_numero_cuenta_destino)),
        p_monto,
        v_moneda,
        v_descripcion,
        'ENTRANTE',
        BTRIM(p_codigo_confirmacion),
        'PENDIENTE',
        COALESCE(p_request_json, '{}'::jsonb),
        NULL,
        NULL,
        NULL,
        now(),
        now()
    )
    RETURNING id INTO v_transferencia_id;

    v_update_cuenta_sql := '
        UPDATE cuentas.cuentas
        SET saldo = COALESCE(saldo, 0) + $2';

    IF v_cuentas_has_saldo_disponible THEN
        v_update_cuenta_sql := v_update_cuenta_sql || ',
        saldo_disponible = COALESCE(saldo_disponible, 0) + $2';
    END IF;

    IF v_cuentas_has_updated_at THEN
        v_update_cuenta_sql := v_update_cuenta_sql || ',
        updated_at = now()';
    END IF;

    v_update_cuenta_sql := v_update_cuenta_sql || '
        WHERE id = $1';

    EXECUTE v_update_cuenta_sql
    USING v_cuenta_id, p_monto;

    v_referencia_movimiento := 'ACHIN-' || REPLACE(gen_random_uuid()::text, '-', '');

    INSERT INTO transacciones.movimientos (
        referencia,
        cuenta_id,
        tipo,
        monto,
        saldo_anterior,
        saldo_posterior,
        cajero_id,
        caja_id,
        descripcion,
        estado,
        referencia_par,
        created_at
    )
    VALUES (
        v_referencia_movimiento,
        v_cuenta_id,
        'ACH_IN',
        p_monto,
        v_saldo_anterior,
        v_saldo_nuevo,
        NULL,
        NULL,
        v_descripcion,
        'COMPLETADA',
        BTRIM(p_codigo_confirmacion),
        now()
    )
    RETURNING id INTO v_movimiento_id;

    v_codigo_pasivo := CASE UPPER(COALESCE(v_cuenta_tipo_cuenta, ''))
        WHEN 'MONETARIA' THEN '2102'
        ELSE '2101'
    END;

    EXECUTE format(
        'SELECT id
         FROM contabilidad.plan_cuentas
         WHERE codigo = $1
           AND %s
         ORDER BY created_at
         LIMIT 1',
        v_plan_cuentas_activa_clause)
    INTO v_cuenta_puente_id
    USING '1102';

    IF v_cuenta_puente_id IS NULL THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo 1102 en contabilidad.plan_cuentas.';
    END IF;

    EXECUTE format(
        'SELECT id
         FROM contabilidad.plan_cuentas
         WHERE codigo = $1
           AND %s
         ORDER BY created_at
         LIMIT 1',
        v_plan_cuentas_activa_clause)
    INTO v_cuenta_pasivo_id
    USING v_codigo_pasivo;

    IF v_cuenta_pasivo_id IS NULL THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo % en contabilidad.plan_cuentas.', v_codigo_pasivo;
    END IF;

    INSERT INTO contabilidad.asientos (
        movimiento_id,
        cuenta_contable_id,
        tipo_asiento,
        monto,
        sp_origen,
        created_at
    )
    VALUES (
        v_movimiento_id,
        v_cuenta_puente_id,
        'DB',
        p_monto,
        'ach.sp_registrar_transferencia_entrante_publica',
        now()
    );

    INSERT INTO contabilidad.asientos (
        movimiento_id,
        cuenta_contable_id,
        tipo_asiento,
        monto,
        sp_origen,
        created_at
    )
    VALUES (
        v_movimiento_id,
        v_cuenta_pasivo_id,
        'CR',
        p_monto,
        'ach.sp_registrar_transferencia_entrante_publica',
        now()
    );

    UPDATE ach.transferencias_entrantes
    SET estado = 'APROBADA',
        movimiento_id = v_movimiento_id,
        response_json = jsonb_build_object(
            'codigo_confirmacion', BTRIM(p_codigo_confirmacion),
            'numero_cuenta_destino', UPPER(BTRIM(p_numero_cuenta_destino)),
            'monto', p_monto,
            'moneda', v_moneda,
            'estado', 'APROBADA',
            'fecha_procesamiento', v_fecha_procesamiento,
            'referencia_movimiento', v_referencia_movimiento
        ),
        mensaje_error = NULL,
        fecha_procesamiento = v_fecha_procesamiento,
        updated_at = now()
    WHERE id = v_transferencia_id;

    INSERT INTO auditoria.log_operaciones (
        modulo,
        accion,
        entidad_tipo,
        entidad_id,
        datos_antes,
        datos_despues,
        resultado,
        usuario_id,
        created_at
    )
    VALUES (
        'ACH_PUBLIC',
        'TRANSFERENCIA_ENTRANTE',
        'ACH_TRANSFERENCIA_ENTRANTE',
        v_transferencia_id,
        jsonb_build_object(
            'saldo', v_saldo_anterior,
            'estado', 'PENDIENTE'
        ),
        jsonb_build_object(
            'saldo', v_saldo_nuevo,
            'codigo_confirmacion', BTRIM(p_codigo_confirmacion),
            'cuenta_destino', UPPER(BTRIM(p_numero_cuenta_destino)),
            'movimiento_id', v_movimiento_id,
            'nombre_usuario', v_nombre_usuario,
            'rol_en_momento', 'BANCO_EXTERNO'
        ),
        'EXITOSO',
        p_usuario_banco_externo_id,
        now()
    );

    RETURN jsonb_build_object(
        'transferencia_id', v_transferencia_id,
        'codigo_confirmacion', BTRIM(p_codigo_confirmacion),
        'numero_cuenta_destino', UPPER(BTRIM(p_numero_cuenta_destino)),
        'monto', p_monto,
        'moneda', v_moneda,
        'estado', 'APROBADA',
        'fecha_procesamiento', v_fecha_procesamiento
    );
END;
$$;

