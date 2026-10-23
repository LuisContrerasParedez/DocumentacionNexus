-- Production deploy - paso 008
-- Catalogos y datos base obligatorios no sensibles.

INSERT INTO catalogos.items (grupo, codigo, nombre, descripcion, orden, activo, created_at)
VALUES
    ('CLIENTE_ESTADO', 'PROSPECTO', 'Prospecto', 'Cliente potencial previo al expediente formal.', 10, true, now()),
    ('CLIENTE_ESTADO', 'EN_REVISION', 'En revision', 'Expediente pendiente de validacion y resolucion.', 20, true, now()),
    ('CLIENTE_ESTADO', 'ACTIVO', 'Activo', 'Cliente aprobado para operar y abrir productos.', 30, true, now()),
    ('CLIENTE_ESTADO', 'BLOQUEADO', 'Bloqueado', 'Cliente con operacion restringida temporalmente.', 40, true, now()),
    ('CLIENTE_ESTADO', 'INACTIVO', 'Inactivo', 'Cliente sin operacion habilitada.', 50, true, now()),
    ('CUENTA_TIPO', 'AHORRO', 'Ahorro', 'Cuenta de ahorro con reglas de saldo minimo y retiros diarios.', 10, true, now()),
    ('CUENTA_TIPO', 'MONETARIA', 'Monetaria', 'Cuenta monetaria orientada a operacion diaria.', 20, true, now()),
    ('CUENTA_ESTADO', 'ACTIVA', 'Activa', 'Cuenta habilitada para operar.', 10, true, now()),
    ('CUENTA_ESTADO', 'BLOQUEADA', 'Bloqueada', 'Cuenta restringida para movimientos.', 20, true, now()),
    ('CUENTA_ESTADO', 'CERRADA', 'Cerrada', 'Cuenta finalizada sin operacion disponible.', 30, true, now()),
    ('EMPLEADO_CARGO', 'GERENTE_GENERAL', 'Gerente general', 'Direccion general de la operacion.', 10, true, now()),
    ('EMPLEADO_CARGO', 'GERENTE_SUCURSAL', 'Gerente sucursal', 'Supervision operativa de sucursal.', 20, true, now()),
    ('EMPLEADO_CARGO', 'CAJERO', 'Cajero', 'Operador de caja y ventanilla.', 30, true, now()),
    ('EMPLEADO_CARGO', 'CONTADOR', 'Contador', 'Gestion contable y conciliacion.', 40, true, now()),
    ('EMPLEADO_TURNO', 'COMPLETO', 'Completo', 'Jornada completa.', 10, true, now()),
    ('EMPLEADO_TURNO', 'MATUTINO', 'Matutino', 'Cobertura en horario matutino.', 20, true, now()),
    ('EMPLEADO_TURNO', 'VESPERTINO', 'Vespertino', 'Cobertura en horario vespertino.', 30, true, now()),
    ('EMPLEADO_TURNO', 'NOCTURNO', 'Nocturno', 'Cobertura en horario nocturno.', 40, true, now()),
    ('EMPLEADO_TURNO', 'ROTATIVO', 'Rotativo', 'Turno variable segun planificacion.', 50, true, now()),
    ('EMPLEADO_ESTADO', 'ACTIVO', 'Activo', 'Empleado habilitado para operar.', 10, true, now()),
    ('EMPLEADO_ESTADO', 'INACTIVO', 'Inactivo', 'Empleado fuera de operacion.', 20, true, now()),
    ('EMPLEADO_ESTADO', 'SUSPENDIDO', 'Suspendido', 'Empleado temporalmente restringido.', 30, true, now())
ON CONFLICT (grupo, codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    orden = EXCLUDED.orden,
    activo = EXCLUDED.activo;

INSERT INTO cuentas.tipos_cuenta (
    codigo,
    nombre,
    descripcion,
    saldo_minimo,
    limite_retiro_diario,
    permite_cheques,
    tasa_interes_anual,
    activo,
    created_at,
    updated_at
)
VALUES
    ('AHORRO', 'AHORRO', 'Cuenta de ahorro base del sistema.', 100.00, 5000.00, false, 0.0300, true, now(), now()),
    ('MONETARIA', 'MONETARIA', 'Cuenta monetaria base del sistema.', 0.00, NULL, true, 0.0100, true, now(), now())
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    saldo_minimo = EXCLUDED.saldo_minimo,
    limite_retiro_diario = EXCLUDED.limite_retiro_diario,
    permite_cheques = EXCLUDED.permite_cheques,
    tasa_interes_anual = EXCLUDED.tasa_interes_anual,
    activo = EXCLUDED.activo,
    updated_at = now();

DO $$
DECLARE
    v_has_tipo boolean;
    v_has_tipo_cuenta boolean;
    v_sql text;
BEGIN
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

    v_sql := '
        INSERT INTO contabilidad.plan_cuentas (
            codigo,
            nombre,
            descripcion';

    IF v_has_tipo THEN
        v_sql := v_sql || ', tipo';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', tipo_cuenta';
    END IF;

    v_sql := v_sql || ',
            activo,
            created_at,
            updated_at
        )
        VALUES
            (''1101'', ''Caja general'', ''Cuenta base de efectivo para operaciones de ventanilla.''';

    IF v_has_tipo THEN
        v_sql := v_sql || ', ''ACTIVO''';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', ''ACTIVO''';
    END IF;

    v_sql := v_sql || ', true, now(), now()),
            (''2101'', ''Depositos de ahorro'', ''Pasivo asociado a cuentas de ahorro.''';

    IF v_has_tipo THEN
        v_sql := v_sql || ', ''PASIVO''';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', ''PASIVO''';
    END IF;

    v_sql := v_sql || ', true, now(), now()),
            (''2102'', ''Depositos monetarios'', ''Pasivo asociado a cuentas monetarias.''';

    IF v_has_tipo THEN
        v_sql := v_sql || ', ''PASIVO''';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ', ''PASIVO''';
    END IF;

    v_sql := v_sql || ', true, now(), now())
        ON CONFLICT (codigo) DO UPDATE
        SET nombre = EXCLUDED.nombre,
            descripcion = EXCLUDED.descripcion';

    IF v_has_tipo THEN
        v_sql := v_sql || ',
            tipo = EXCLUDED.tipo';
    END IF;

    IF v_has_tipo_cuenta THEN
        v_sql := v_sql || ',
            tipo_cuenta = EXCLUDED.tipo_cuenta';
    END IF;

    v_sql := v_sql || ',
            activo = EXCLUDED.activo,
            updated_at = now();';

    EXECUTE v_sql;
END $$;
