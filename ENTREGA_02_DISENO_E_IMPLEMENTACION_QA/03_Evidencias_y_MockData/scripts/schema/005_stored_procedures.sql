-- Production deploy - paso 005
-- PostgreSQL usa funciones para la logica transaccional del sistema actual.

CREATE OR REPLACE FUNCTION cuentas.sp_abrir_cuenta(
    p_cliente_id uuid,
    p_tipo_cuenta text,
    p_cajero_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo text;
    v_cliente_estado text;
    v_tipo_cuenta_id uuid;
    v_saldo_minimo numeric(18,2);
    v_limite_retiro numeric(18,2);
    v_permite_cheques boolean;
    v_tasa_interes numeric(5,4);
    v_numero_cuenta text;
    v_cuenta_id uuid := gen_random_uuid();
    v_prefijo text;
BEGIN
    IF p_cliente_id IS NULL THEN
        RAISE EXCEPTION 'Cliente requerido.';
    END IF;

    v_tipo := UPPER(BTRIM(COALESCE(p_tipo_cuenta, '')));
    IF v_tipo = '' THEN
        RAISE EXCEPTION 'Tipo de cuenta requerido.';
    END IF;

    SELECT estado
    INTO v_cliente_estado
    FROM crm.clientes
    WHERE id = p_cliente_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado.';
    END IF;

    IF UPPER(COALESCE(v_cliente_estado, '')) <> 'ACTIVO' THEN
        RAISE EXCEPTION 'El cliente no esta activo. Estado actual: %', v_cliente_estado;
    END IF;

    SELECT
        id,
        COALESCE(saldo_minimo, CASE WHEN v_tipo = 'AHORRO' THEN 100.00 ELSE 0.00 END),
        COALESCE(limite_retiro_diario, CASE WHEN v_tipo = 'AHORRO' THEN 5000.00 ELSE NULL END),
        COALESCE(permite_cheques, CASE WHEN v_tipo = 'MONETARIA' THEN true ELSE false END),
        COALESCE(tasa_interes_anual, CASE WHEN v_tipo = 'AHORRO' THEN 0.0300 ELSE 0.0100 END)
    INTO
        v_tipo_cuenta_id,
        v_saldo_minimo,
        v_limite_retiro,
        v_permite_cheques,
        v_tasa_interes
    FROM cuentas.tipos_cuenta
    WHERE UPPER(COALESCE(codigo, nombre)) = v_tipo
    ORDER BY created_at
    LIMIT 1;

    IF v_tipo_cuenta_id IS NULL AND v_tipo NOT IN ('AHORRO', 'MONETARIA') THEN
        RAISE EXCEPTION 'Tipo de cuenta no soportado: %', v_tipo;
    END IF;

    v_prefijo := CASE v_tipo
        WHEN 'AHORRO' THEN 'AH'
        WHEN 'MONETARIA' THEN 'MO'
        ELSE 'CT'
    END;

    LOOP
        v_numero_cuenta := v_prefijo || TO_CHAR(CURRENT_DATE, 'YYMMDD') || LPAD(FLOOR(RANDOM() * 1000000)::text, 6, '0');
        EXIT WHEN NOT EXISTS (
            SELECT 1
            FROM cuentas.cuentas
            WHERE numero_cuenta = v_numero_cuenta
        );
    END LOOP;

    INSERT INTO cuentas.cuentas (
        id,
        numero_cuenta,
        tipo_cuenta,
        tipo_cuenta_id,
        cliente_id,
        saldo,
        saldo_disponible,
        saldo_retenido,
        saldo_minimo,
        limite_retiro_diario,
        monto_retirado_hoy,
        permite_cheques,
        tasa_interes_anual,
        moneda,
        cajero_apertura_id,
        estado,
        fecha_apertura,
        created_at,
        updated_at
    )
    VALUES (
        v_cuenta_id,
        v_numero_cuenta,
        v_tipo,
        v_tipo_cuenta_id,
        p_cliente_id,
        0,
        0,
        0,
        COALESCE(v_saldo_minimo, 0),
        v_limite_retiro,
        0,
        COALESCE(v_permite_cheques, false),
        COALESCE(v_tasa_interes, 0),
        'GTQ',
        p_cajero_id,
        'ACTIVA',
        now(),
        now(),
        now()
    );

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
        'CUENTAS',
        'APERTURA',
        'CUENTA',
        v_cuenta_id,
        NULL,
        jsonb_build_object(
            'cliente_id', p_cliente_id,
            'numero_cuenta', v_numero_cuenta,
            'tipo_cuenta', v_tipo,
            'saldo_minimo', COALESCE(v_saldo_minimo, 0)
        ),
        'EXITOSO',
        NULL,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'cuenta_id', v_cuenta_id,
        'numero_cuenta', v_numero_cuenta,
        'tipo_cuenta', v_tipo,
        'saldo_minimo', COALESCE(v_saldo_minimo, 0)
    );
END;
$$;

CREATE OR REPLACE FUNCTION transacciones.sp_deposito(
    p_cuenta_id uuid,
    p_monto numeric,
    p_cajero_id uuid,
    p_caja_id uuid,
    p_descripcion text DEFAULT 'Deposito en ventanilla'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta record;
    v_caja record;
    v_referencia text;
    v_saldo_ant numeric(18,2);
    v_movimiento_id uuid;
    v_cuenta_cont uuid;
    v_codigo_plan text;
BEGIN
    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a cero. Monto recibido: %', p_monto;
    END IF;

    SELECT *
    INTO v_caja
    FROM cajas.sesiones_caja
    WHERE id = p_caja_id
      AND cajero_id = p_cajero_id
      AND estado = 'ABIERTA'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesion de caja abierta con ese ID';
    END IF;

    SELECT *
    INTO v_cuenta
    FROM cuentas.cuentas
    WHERE id = p_cuenta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta no encontrada';
    END IF;

    IF UPPER(COALESCE(v_cuenta.estado, '')) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La cuenta % no esta activa. Estado actual: %',
            v_cuenta.numero_cuenta, v_cuenta.estado;
    END IF;

    v_saldo_ant := COALESCE(v_cuenta.saldo, 0);
    v_referencia := 'DEP-' || REPLACE(gen_random_uuid()::text, '-', '');

    UPDATE cuentas.cuentas
    SET saldo = COALESCE(saldo, 0) + p_monto,
        saldo_disponible = COALESCE(saldo_disponible, 0) + p_monto,
        updated_at = now()
    WHERE id = p_cuenta_id;

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
        created_at,
        updated_at
    )
    VALUES (
        v_referencia,
        p_cuenta_id,
        'DEPOSITO',
        p_monto,
        v_saldo_ant,
        v_saldo_ant + p_monto,
        p_cajero_id,
        p_caja_id,
        p_descripcion,
        'COMPLETADA',
        now(),
        now()
    )
    RETURNING id INTO v_movimiento_id;

    UPDATE cajas.sesiones_caja
    SET total_depositos = COALESCE(total_depositos, 0) + p_monto
    WHERE id = p_caja_id;

    v_codigo_plan := CASE UPPER(COALESCE(v_cuenta.tipo_cuenta, ''))
        WHEN 'AHORRO' THEN '2101'
        WHEN 'MONETARIA' THEN '2102'
        ELSE '2101'
    END;

    SELECT id
    INTO v_cuenta_cont
    FROM contabilidad.plan_cuentas
    WHERE codigo = v_codigo_plan
      AND COALESCE(activo, true) = true
    ORDER BY created_at
    LIMIT 1;

    IF v_cuenta_cont IS NULL THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo % en contabilidad.plan_cuentas.', v_codigo_plan;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM contabilidad.plan_cuentas
        WHERE codigo = '1101'
          AND COALESCE(activo, true) = true
    ) THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo 1101 en contabilidad.plan_cuentas.';
    END IF;

    INSERT INTO contabilidad.asientos (
        movimiento_id,
        cuenta_contable_id,
        tipo_asiento,
        monto,
        sp_origen,
        created_at
    )
    SELECT v_movimiento_id, id, 'DB', p_monto, 'sp_deposito', now()
    FROM contabilidad.plan_cuentas
    WHERE codigo = '1101'
      AND COALESCE(activo, true) = true
    ORDER BY created_at
    LIMIT 1;

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
        v_cuenta_cont,
        'CR',
        p_monto,
        'sp_deposito',
        now()
    );

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
        'TRANSACCIONES',
        'DEPOSITO',
        'CUENTA',
        p_cuenta_id,
        jsonb_build_object('saldo', v_saldo_ant),
        jsonb_build_object('saldo', v_saldo_ant + p_monto, 'referencia', v_referencia),
        'EXITOSO',
        NULL,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'referencia', v_referencia,
        'saldo_nuevo', v_saldo_ant + p_monto,
        'monto', p_monto
    );
END;
$$;

CREATE OR REPLACE FUNCTION transacciones.sp_retiro(
    p_cuenta_id uuid,
    p_monto numeric,
    p_cajero_id uuid,
    p_caja_id uuid,
    p_descripcion text DEFAULT 'Retiro en ventanilla'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta record;
    v_caja record;
    v_referencia text;
    v_saldo_ant numeric(18,2);
    v_movimiento_id uuid;
    v_cuenta_cont uuid;
    v_codigo_plan text;
BEGIN
    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a cero';
    END IF;

    SELECT *
    INTO v_caja
    FROM cajas.sesiones_caja
    WHERE id = p_caja_id
      AND cajero_id = p_cajero_id
      AND estado = 'ABIERTA'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesion de caja abierta con ese ID';
    END IF;

    SELECT *
    INTO v_cuenta
    FROM cuentas.cuentas
    WHERE id = p_cuenta_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cuenta no encontrada';
    END IF;

    IF UPPER(COALESCE(v_cuenta.estado, '')) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La cuenta % no esta activa', v_cuenta.numero_cuenta;
    END IF;

    IF COALESCE(v_cuenta.saldo_disponible, 0) < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente. Disponible: Q%. Solicitado: Q%',
            v_cuenta.saldo_disponible, p_monto;
    END IF;

    IF COALESCE(v_cuenta.saldo, 0) - p_monto < COALESCE(v_cuenta.saldo_minimo, 0) THEN
        RAISE EXCEPTION 'El retiro dejaria el saldo en Q%, por debajo del minimo requerido de Q%',
            COALESCE(v_cuenta.saldo, 0) - p_monto, COALESCE(v_cuenta.saldo_minimo, 0);
    END IF;

    IF UPPER(COALESCE(v_cuenta.tipo_cuenta, '')) = 'AHORRO'
       AND v_cuenta.limite_retiro_diario IS NOT NULL
       AND COALESCE(v_cuenta.monto_retirado_hoy, 0) + p_monto > v_cuenta.limite_retiro_diario THEN
        RAISE EXCEPTION 'Limite diario excedido. Retirado hoy: Q%. Limite: Q%. Puede retirar maximo: Q%',
            COALESCE(v_cuenta.monto_retirado_hoy, 0),
            v_cuenta.limite_retiro_diario,
            v_cuenta.limite_retiro_diario - COALESCE(v_cuenta.monto_retirado_hoy, 0);
    END IF;

    v_saldo_ant := COALESCE(v_cuenta.saldo, 0);
    v_referencia := 'RET-' || REPLACE(gen_random_uuid()::text, '-', '');

    UPDATE cuentas.cuentas
    SET saldo = COALESCE(saldo, 0) - p_monto,
        saldo_disponible = COALESCE(saldo_disponible, 0) - p_monto,
        monto_retirado_hoy = COALESCE(monto_retirado_hoy, 0) + p_monto,
        updated_at = now()
    WHERE id = p_cuenta_id;

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
        created_at,
        updated_at
    )
    VALUES (
        v_referencia,
        p_cuenta_id,
        'RETIRO',
        p_monto,
        v_saldo_ant,
        v_saldo_ant - p_monto,
        p_cajero_id,
        p_caja_id,
        p_descripcion,
        'COMPLETADA',
        now(),
        now()
    )
    RETURNING id INTO v_movimiento_id;

    UPDATE cajas.sesiones_caja
    SET total_retiros = COALESCE(total_retiros, 0) + p_monto
    WHERE id = p_caja_id;

    v_codigo_plan := CASE UPPER(COALESCE(v_cuenta.tipo_cuenta, ''))
        WHEN 'AHORRO' THEN '2101'
        WHEN 'MONETARIA' THEN '2102'
        ELSE '2101'
    END;

    SELECT id
    INTO v_cuenta_cont
    FROM contabilidad.plan_cuentas
    WHERE codigo = v_codigo_plan
      AND COALESCE(activo, true) = true
    ORDER BY created_at
    LIMIT 1;

    IF v_cuenta_cont IS NULL THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo % en contabilidad.plan_cuentas.', v_codigo_plan;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM contabilidad.plan_cuentas
        WHERE codigo = '1101'
          AND COALESCE(activo, true) = true
    ) THEN
        RAISE EXCEPTION 'No existe cuenta contable activa con codigo 1101 en contabilidad.plan_cuentas.';
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
        v_cuenta_cont,
        'DB',
        p_monto,
        'sp_retiro',
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
    SELECT v_movimiento_id, id, 'CR', p_monto, 'sp_retiro', now()
    FROM contabilidad.plan_cuentas
    WHERE codigo = '1101'
      AND COALESCE(activo, true) = true
    ORDER BY created_at
    LIMIT 1;

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
        'TRANSACCIONES',
        'RETIRO',
        'CUENTA',
        p_cuenta_id,
        jsonb_build_object('saldo', v_saldo_ant),
        jsonb_build_object('saldo', v_saldo_ant - p_monto, 'referencia', v_referencia),
        'EXITOSO',
        NULL,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'referencia', v_referencia,
        'saldo_nuevo', v_saldo_ant - p_monto,
        'monto', p_monto
    );
END;
$$;

CREATE OR REPLACE FUNCTION transacciones.sp_transferir_fondos(
    p_origen_id uuid,
    p_destino_id uuid,
    p_monto numeric,
    p_cajero_id uuid,
    p_caja_id uuid,
    p_concepto text DEFAULT 'Transferencia entre cuentas'
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_caja record;
    v_primero_id uuid;
    v_segundo_id uuid;
    v_origen_saldo numeric;
    v_origen_disp numeric;
    v_origen_min numeric;
    v_origen_num text;
    v_origen_estado text;
    v_destino_saldo numeric;
    v_destino_estado text;
    v_referencia text;
    v_mov_out_id uuid;
    v_mov_in_id uuid;
BEGIN
    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto debe ser mayor a cero';
    END IF;

    IF p_origen_id = p_destino_id THEN
        RAISE EXCEPTION 'La cuenta origen y destino no pueden ser la misma';
    END IF;

    SELECT *
    INTO v_caja
    FROM cajas.sesiones_caja
    WHERE id = p_caja_id
      AND cajero_id = p_cajero_id
      AND estado = 'ABIERTA'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe una sesion de caja abierta con ese ID';
    END IF;

    v_primero_id := LEAST(p_origen_id, p_destino_id);
    v_segundo_id := GREATEST(p_origen_id, p_destino_id);

    PERFORM id FROM cuentas.cuentas WHERE id = v_primero_id FOR UPDATE;
    PERFORM id FROM cuentas.cuentas WHERE id = v_segundo_id FOR UPDATE;

    SELECT saldo, saldo_disponible, saldo_minimo, numero_cuenta, estado
    INTO v_origen_saldo, v_origen_disp, v_origen_min, v_origen_num, v_origen_estado
    FROM cuentas.cuentas
    WHERE id = p_origen_id;

    SELECT saldo, estado
    INTO v_destino_saldo, v_destino_estado
    FROM cuentas.cuentas
    WHERE id = p_destino_id;

    IF UPPER(COALESCE(v_origen_estado, '')) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La cuenta origen % no esta activa', v_origen_num;
    END IF;

    IF UPPER(COALESCE(v_destino_estado, '')) <> 'ACTIVA' THEN
        RAISE EXCEPTION 'La cuenta destino no esta activa';
    END IF;

    IF COALESCE(v_origen_disp, 0) < p_monto THEN
        RAISE EXCEPTION 'Saldo insuficiente en cuenta origen. Disponible: Q%', v_origen_disp;
    END IF;

    IF COALESCE(v_origen_saldo, 0) - p_monto < COALESCE(v_origen_min, 0) THEN
        RAISE EXCEPTION 'El retiro dejaria el saldo por debajo del minimo requerido';
    END IF;

    v_referencia := 'TRF-' || REPLACE(gen_random_uuid()::text, '-', '');

    UPDATE cuentas.cuentas
    SET saldo = COALESCE(saldo, 0) - p_monto,
        saldo_disponible = COALESCE(saldo_disponible, 0) - p_monto,
        updated_at = now()
    WHERE id = p_origen_id;

    UPDATE cuentas.cuentas
    SET saldo = COALESCE(saldo, 0) + p_monto,
        saldo_disponible = COALESCE(saldo_disponible, 0) + p_monto,
        updated_at = now()
    WHERE id = p_destino_id;

    INSERT INTO transacciones.transferencias (
        referencia,
        cuenta_origen_id,
        cuenta_destino_id,
        monto,
        descripcion,
        operador_id,
        fecha_transferencia
    )
    VALUES (
        v_referencia,
        p_origen_id,
        p_destino_id,
        p_monto,
        p_concepto,
        p_cajero_id,
        now()
    );

    INSERT INTO transacciones.movimientos (
        referencia,
        referencia_par,
        cuenta_id,
        tipo,
        monto,
        saldo_anterior,
        saldo_posterior,
        cajero_id,
        caja_id,
        descripcion,
        estado,
        created_at,
        updated_at
    )
    VALUES (
        v_referencia || '-OUT',
        v_referencia || '-IN',
        p_origen_id,
        'TRF_OUT',
        p_monto,
        v_origen_saldo,
        COALESCE(v_origen_saldo, 0) - p_monto,
        p_cajero_id,
        p_caja_id,
        p_concepto,
        'COMPLETADA',
        now(),
        now()
    )
    RETURNING id INTO v_mov_out_id;

    INSERT INTO transacciones.movimientos (
        referencia,
        referencia_par,
        cuenta_id,
        tipo,
        monto,
        saldo_anterior,
        saldo_posterior,
        cajero_id,
        caja_id,
        descripcion,
        estado,
        created_at,
        updated_at
    )
    VALUES (
        v_referencia || '-IN',
        v_referencia || '-OUT',
        p_destino_id,
        'TRF_IN',
        p_monto,
        v_destino_saldo,
        COALESCE(v_destino_saldo, 0) + p_monto,
        p_cajero_id,
        p_caja_id,
        p_concepto,
        'COMPLETADA',
        now(),
        now()
    )
    RETURNING id INTO v_mov_in_id;

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
        'TRANSACCIONES',
        'TRANSFERENCIA',
        'CUENTA',
        p_origen_id,
        jsonb_build_object('saldo_origen', v_origen_saldo, 'saldo_destino', v_destino_saldo),
        jsonb_build_object(
            'saldo_origen', COALESCE(v_origen_saldo, 0) - p_monto,
            'saldo_destino', COALESCE(v_destino_saldo, 0) + p_monto,
            'referencia', v_referencia
        ),
        'EXITOSO',
        NULL,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'referencia', v_referencia,
        'saldo_origen', COALESCE(v_origen_saldo, 0) - p_monto,
        'saldo_destino', COALESCE(v_destino_saldo, 0) + p_monto,
        'monto', p_monto
    );
END;
$$;
