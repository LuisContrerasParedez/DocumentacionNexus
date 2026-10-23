-- Production deploy - paso 003
-- Ajusta defaults, constraints e indices sin truncar ni borrar datos.

UPDATE seguridad.usuarios
SET estado = COALESCE(estado, true),
    bloqueado = COALESCE(bloqueado, false),
    intentos_fallidos = COALESCE(intentos_fallidos, 0),
    debe_cambiar_password = COALESCE(debe_cambiar_password, false),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE seguridad.usuarios u
SET created_by = NULL
WHERE created_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = u.created_by
  );

UPDATE seguridad.usuarios u
SET updated_by = NULL
WHERE updated_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = u.updated_by
  );

UPDATE seguridad.roles
SET estado = COALESCE(estado, true),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE seguridad.permisos
SET estado = COALESCE(estado, true),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE seguridad.usuarios_roles
SET estado = COALESCE(estado, true),
    fecha_asignacion = COALESCE(fecha_asignacion, now());

UPDATE seguridad.usuarios_roles ur
SET assigned_by = NULL
WHERE assigned_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = ur.assigned_by
  );

UPDATE seguridad.roles_permisos
SET created_at = COALESCE(created_at, now());

UPDATE seguridad.roles_permisos rp
SET created_by = NULL
WHERE created_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = rp.created_by
  );

UPDATE seguridad.usuarios_permisos
SET permitido = COALESCE(permitido, true),
    fecha_asignacion = COALESCE(fecha_asignacion, now());

UPDATE seguridad.usuarios_permisos up
SET assigned_by = NULL
WHERE assigned_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = up.assigned_by
  );

UPDATE seguridad.sesiones
SET estado = COALESCE(estado, true),
    fecha_inicio = COALESCE(fecha_inicio, now());

UPDATE seguridad.tokens_recuperacion
SET usado = COALESCE(usado, false),
    created_at = COALESCE(created_at, now());

UPDATE seguridad.password_historial
SET created_at = COALESCE(created_at, now());

UPDATE seguridad.api_keys
SET estado = COALESCE(estado, true),
    created_at = COALESCE(created_at, now());

UPDATE seguridad.eventos_seguridad
SET exitoso = COALESCE(exitoso, true),
    created_at = COALESCE(created_at, now());

UPDATE catalogos.items
SET orden = COALESCE(orden, 0),
    activo = COALESCE(activo, true),
    created_at = COALESCE(created_at, now());

UPDATE catalogos.items i
SET created_by = NULL
WHERE created_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = i.created_by
  );

UPDATE catalogos.items i
SET updated_by = NULL
WHERE updated_by IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = i.updated_by
  );

UPDATE crm.clientes
SET created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now()),
    estado = COALESCE(NULLIF(BTRIM(estado), ''), 'EN_REVISION');

UPDATE crm.clientes c
SET usuario_id = NULL
WHERE usuario_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = c.usuario_id
  );

UPDATE crm.clientes c
SET creado_por = NULL
WHERE creado_por IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = c.creado_por
  );

UPDATE crm.clientes c
SET aprobado_por = NULL
WHERE aprobado_por IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = c.aprobado_por
  );

UPDATE rrhh.empleados
SET created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now()),
    estado = COALESCE(NULLIF(BTRIM(estado), ''), 'ACTIVO');

UPDATE rrhh.empleados e
SET usuario_id = NULL
WHERE usuario_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuarios x
      WHERE x.id = e.usuario_id
  );

UPDATE cuentas.tipos_cuenta
SET activo = COALESCE(activo, true),
    saldo_minimo = COALESCE(saldo_minimo, 0),
    permite_cheques = COALESCE(permite_cheques, false),
    tasa_interes_anual = COALESCE(tasa_interes_anual, 0),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE cuentas.cuentas
SET saldo = COALESCE(saldo, 0),
    saldo_disponible = COALESCE(saldo_disponible, saldo, 0),
    saldo_retenido = COALESCE(saldo_retenido, 0),
    saldo_minimo = COALESCE(saldo_minimo, 0),
    monto_retirado_hoy = COALESCE(monto_retirado_hoy, 0),
    permite_cheques = COALESCE(permite_cheques, false),
    tasa_interes_anual = COALESCE(tasa_interes_anual, 0),
    moneda = COALESCE(NULLIF(BTRIM(moneda), ''), 'GTQ'),
    estado = COALESCE(NULLIF(BTRIM(estado), ''), 'ACTIVA'),
    fecha_apertura = COALESCE(fecha_apertura, now()),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE cajas.sesiones_caja
SET fondo_inicial = COALESCE(fondo_inicial, 0),
    total_depositos = COALESCE(total_depositos, 0),
    total_retiros = COALESCE(total_retiros, 0),
    estado = COALESCE(NULLIF(BTRIM(estado), ''), 'ABIERTA'),
    hora_apertura = COALESCE(hora_apertura, now());

UPDATE transacciones.movimientos
SET created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now()),
    estado = COALESCE(NULLIF(BTRIM(estado), ''), 'COMPLETADA');

UPDATE transacciones.transferencias
SET fecha_transferencia = COALESCE(fecha_transferencia, now());

UPDATE ach.transferencias
SET request_json = COALESCE(request_json, '{}'::jsonb),
    fecha_creacion = COALESCE(fecha_creacion, now()),
    fecha_actualizacion = COALESCE(fecha_actualizacion, now());

UPDATE contabilidad.plan_cuentas
SET activo = COALESCE(activo, true),
    created_at = COALESCE(created_at, now()),
    updated_at = COALESCE(updated_at, now());

UPDATE contabilidad.asientos
SET created_at = COALESCE(created_at, now());

UPDATE auditoria.log_operaciones
SET created_at = COALESCE(created_at, now());

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'empleados_cargo_check'
          AND conrelid = 'rrhh.empleados'::regclass
    ) THEN
        ALTER TABLE rrhh.empleados DROP CONSTRAINT empleados_cargo_check;
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'empleados_turno_check'
          AND conrelid = 'rrhh.empleados'::regclass
    ) THEN
        ALTER TABLE rrhh.empleados DROP CONSTRAINT empleados_turno_check;
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'empleados_estado_check'
          AND conrelid = 'rrhh.empleados'::regclass
    ) THEN
        ALTER TABLE rrhh.empleados DROP CONSTRAINT empleados_estado_check;
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_usuarios_username ON seguridad.usuarios (username);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_usuarios_email ON seguridad.usuarios (email);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_roles_codigo ON seguridad.roles (codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_roles_nombre ON seguridad.roles (nombre);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_permisos_codigo ON seguridad.permisos (codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_usuarios_roles ON seguridad.usuarios_roles (usuario_id, rol_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_roles_permisos ON seguridad.roles_permisos (rol_id, permiso_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_seguridad_usuarios_permisos ON seguridad.usuarios_permisos (usuario_id, permiso_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_catalogos_items_grupo_codigo ON catalogos.items (grupo, codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cuentas_tipos_cuenta_codigo ON cuentas.tipos_cuenta (codigo);
CREATE UNIQUE INDEX IF NOT EXISTS uq_contabilidad_plan_cuentas_codigo ON contabilidad.plan_cuentas (codigo);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'crm'
          AND indexname = 'uq_crm_clientes_dpi'
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM crm.clientes
            WHERE NULLIF(BTRIM(dpi), '') IS NOT NULL
            GROUP BY dpi
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'No se crea uq_crm_clientes_dpi porque existen DPI duplicados.';
        ELSE
            CREATE UNIQUE INDEX uq_crm_clientes_dpi ON crm.clientes (dpi);
        END IF;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'cuentas'
          AND indexname = 'uq_cuentas_numero_cuenta'
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM cuentas.cuentas
            WHERE NULLIF(BTRIM(numero_cuenta), '') IS NOT NULL
            GROUP BY numero_cuenta
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'No se crea uq_cuentas_numero_cuenta porque existen numeros de cuenta duplicados.';
        ELSE
            CREATE UNIQUE INDEX uq_cuentas_numero_cuenta ON cuentas.cuentas (numero_cuenta);
        END IF;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'transacciones'
          AND indexname = 'uq_transacciones_transferencias_referencia'
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM transacciones.transferencias
            WHERE NULLIF(BTRIM(referencia), '') IS NOT NULL
            GROUP BY referencia
            HAVING COUNT(*) > 1
        ) THEN
            RAISE NOTICE 'No se crea uq_transacciones_transferencias_referencia porque existen referencias duplicadas.';
        ELSE
            CREATE UNIQUE INDEX uq_transacciones_transferencias_referencia ON transacciones.transferencias (referencia);
        END IF;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_seguridad_usuarios_estado ON seguridad.usuarios (estado);
CREATE INDEX IF NOT EXISTS idx_seguridad_usuarios_bloqueado ON seguridad.usuarios (bloqueado);
CREATE INDEX IF NOT EXISTS idx_seguridad_sesiones_usuario_id ON seguridad.sesiones (usuario_id);
CREATE INDEX IF NOT EXISTS idx_seguridad_sesiones_refresh_token_hash ON seguridad.sesiones (refresh_token_hash);
CREATE INDEX IF NOT EXISTS idx_seguridad_tokens_usuario_id ON seguridad.tokens_recuperacion (usuario_id);
CREATE INDEX IF NOT EXISTS idx_seguridad_tokens_hash ON seguridad.tokens_recuperacion (token_hash);
CREATE INDEX IF NOT EXISTS idx_seguridad_password_historial_usuario_id ON seguridad.password_historial (usuario_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_seguridad_eventos_usuario_id ON seguridad.eventos_seguridad (usuario_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_seguridad_api_keys_hash ON seguridad.api_keys (api_key_hash);
CREATE INDEX IF NOT EXISTS idx_catalogos_items_grupo_activo ON catalogos.items (grupo, activo, orden, nombre);
CREATE INDEX IF NOT EXISTS idx_crm_clientes_estado ON crm.clientes (estado);
CREATE INDEX IF NOT EXISTS idx_crm_clientes_usuario_id ON crm.clientes (usuario_id);
CREATE INDEX IF NOT EXISTS idx_rrhh_empleados_estado ON rrhh.empleados (estado);
CREATE INDEX IF NOT EXISTS idx_rrhh_empleados_usuario_id ON rrhh.empleados (usuario_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_cliente_id ON cuentas.cuentas (cliente_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_estado ON cuentas.cuentas (estado);
CREATE INDEX IF NOT EXISTS idx_cuentas_tipo_cuenta ON cuentas.cuentas (tipo_cuenta);
CREATE INDEX IF NOT EXISTS idx_cajas_sesiones_cajero_fecha ON cajas.sesiones_caja (cajero_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_cajas_sesiones_usuario_fecha ON cajas.sesiones_caja (usuario_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_transacciones_movimientos_cuenta_fecha ON transacciones.movimientos (cuenta_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transacciones_movimientos_referencia ON transacciones.movimientos (referencia);
CREATE INDEX IF NOT EXISTS idx_transferencias_fecha_transferencia ON transacciones.transferencias (fecha_transferencia DESC);
CREATE INDEX IF NOT EXISTS idx_transferencias_cuenta_origen_id ON transacciones.transferencias (cuenta_origen_id);
CREATE INDEX IF NOT EXISTS idx_transferencias_cuenta_destino_id ON transacciones.transferencias (cuenta_destino_id);
CREATE INDEX IF NOT EXISTS idx_ach_transferencias_fecha ON ach.transferencias (fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS idx_ach_transferencias_cuenta_origen ON ach.transferencias (cuenta_origen_id);
CREATE INDEX IF NOT EXISTS idx_ach_transferencias_estado ON ach.transferencias (estado);
CREATE INDEX IF NOT EXISTS idx_ach_transferencias_banco_codigo ON ach.transferencias (banco_codigo);
CREATE UNIQUE INDEX IF NOT EXISTS ux_ach_transferencias_codigo_confirmacion ON ach.transferencias (codigo_confirmacion) WHERE codigo_confirmacion IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contabilidad_plan_cuentas_codigo ON contabilidad.plan_cuentas (codigo);
CREATE INDEX IF NOT EXISTS idx_contabilidad_asientos_movimiento_id ON contabilidad.asientos (movimiento_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_log_operaciones_entidad ON auditoria.log_operaciones (entidad_tipo, entidad_id, created_at DESC);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_created_by'
          AND conrelid = 'seguridad.usuarios'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios
            ADD CONSTRAINT fk_seguridad_usuarios_created_by
            FOREIGN KEY (created_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_updated_by'
          AND conrelid = 'seguridad.usuarios'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios
            ADD CONSTRAINT fk_seguridad_usuarios_updated_by
            FOREIGN KEY (updated_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_roles_created_by'
          AND conrelid = 'seguridad.roles'::regclass
    ) THEN
        ALTER TABLE seguridad.roles
            ADD CONSTRAINT fk_seguridad_roles_created_by
            FOREIGN KEY (created_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_roles_updated_by'
          AND conrelid = 'seguridad.roles'::regclass
    ) THEN
        ALTER TABLE seguridad.roles
            ADD CONSTRAINT fk_seguridad_roles_updated_by
            FOREIGN KEY (updated_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_roles_usuario'
          AND conrelid = 'seguridad.usuarios_roles'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_roles
            ADD CONSTRAINT fk_seguridad_usuarios_roles_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_roles_rol'
          AND conrelid = 'seguridad.usuarios_roles'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_roles
            ADD CONSTRAINT fk_seguridad_usuarios_roles_rol
            FOREIGN KEY (rol_id) REFERENCES seguridad.roles(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_roles_assigned_by'
          AND conrelid = 'seguridad.usuarios_roles'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_roles
            ADD CONSTRAINT fk_seguridad_usuarios_roles_assigned_by
            FOREIGN KEY (assigned_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_roles_permisos_rol'
          AND conrelid = 'seguridad.roles_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.roles_permisos
            ADD CONSTRAINT fk_seguridad_roles_permisos_rol
            FOREIGN KEY (rol_id) REFERENCES seguridad.roles(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_roles_permisos_permiso'
          AND conrelid = 'seguridad.roles_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.roles_permisos
            ADD CONSTRAINT fk_seguridad_roles_permisos_permiso
            FOREIGN KEY (permiso_id) REFERENCES seguridad.permisos(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_roles_permisos_created_by'
          AND conrelid = 'seguridad.roles_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.roles_permisos
            ADD CONSTRAINT fk_seguridad_roles_permisos_created_by
            FOREIGN KEY (created_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_permisos_usuario'
          AND conrelid = 'seguridad.usuarios_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_permisos
            ADD CONSTRAINT fk_seguridad_usuarios_permisos_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_permisos_permiso'
          AND conrelid = 'seguridad.usuarios_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_permisos
            ADD CONSTRAINT fk_seguridad_usuarios_permisos_permiso
            FOREIGN KEY (permiso_id) REFERENCES seguridad.permisos(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_usuarios_permisos_assigned_by'
          AND conrelid = 'seguridad.usuarios_permisos'::regclass
    ) THEN
        ALTER TABLE seguridad.usuarios_permisos
            ADD CONSTRAINT fk_seguridad_usuarios_permisos_assigned_by
            FOREIGN KEY (assigned_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_sesiones_usuario'
          AND conrelid = 'seguridad.sesiones'::regclass
    ) THEN
        ALTER TABLE seguridad.sesiones
            ADD CONSTRAINT fk_seguridad_sesiones_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_tokens_usuario'
          AND conrelid = 'seguridad.tokens_recuperacion'::regclass
    ) THEN
        ALTER TABLE seguridad.tokens_recuperacion
            ADD CONSTRAINT fk_seguridad_tokens_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_password_historial_usuario'
          AND conrelid = 'seguridad.password_historial'::regclass
    ) THEN
        ALTER TABLE seguridad.password_historial
            ADD CONSTRAINT fk_seguridad_password_historial_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_api_keys_usuario'
          AND conrelid = 'seguridad.api_keys'::regclass
    ) THEN
        ALTER TABLE seguridad.api_keys
            ADD CONSTRAINT fk_seguridad_api_keys_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_seguridad_eventos_usuario'
          AND conrelid = 'seguridad.eventos_seguridad'::regclass
    ) THEN
        ALTER TABLE seguridad.eventos_seguridad
            ADD CONSTRAINT fk_seguridad_eventos_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_catalogos_items_created_by'
          AND conrelid = 'catalogos.items'::regclass
    ) THEN
        ALTER TABLE catalogos.items
            ADD CONSTRAINT fk_catalogos_items_created_by
            FOREIGN KEY (created_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_catalogos_items_updated_by'
          AND conrelid = 'catalogos.items'::regclass
    ) THEN
        ALTER TABLE catalogos.items
            ADD CONSTRAINT fk_catalogos_items_updated_by
            FOREIGN KEY (updated_by) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_crm_clientes_usuario'
          AND conrelid = 'crm.clientes'::regclass
    ) THEN
        ALTER TABLE crm.clientes
            ADD CONSTRAINT fk_crm_clientes_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_crm_clientes_creado_por'
          AND conrelid = 'crm.clientes'::regclass
    ) THEN
        ALTER TABLE crm.clientes
            ADD CONSTRAINT fk_crm_clientes_creado_por
            FOREIGN KEY (creado_por) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_crm_clientes_aprobado_por'
          AND conrelid = 'crm.clientes'::regclass
    ) THEN
        ALTER TABLE crm.clientes
            ADD CONSTRAINT fk_crm_clientes_aprobado_por
            FOREIGN KEY (aprobado_por) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_rrhh_empleados_usuario'
          AND conrelid = 'rrhh.empleados'::regclass
    ) THEN
        ALTER TABLE rrhh.empleados
            ADD CONSTRAINT fk_rrhh_empleados_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_cuentas_cuentas_cliente'
          AND conrelid = 'cuentas.cuentas'::regclass
    ) THEN
        ALTER TABLE cuentas.cuentas
            ADD CONSTRAINT fk_cuentas_cuentas_cliente
            FOREIGN KEY (cliente_id) REFERENCES crm.clientes(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_cuentas_cuentas_tipo_cuenta_id'
          AND conrelid = 'cuentas.cuentas'::regclass
    ) THEN
        ALTER TABLE cuentas.cuentas
            ADD CONSTRAINT fk_cuentas_cuentas_tipo_cuenta_id
            FOREIGN KEY (tipo_cuenta_id) REFERENCES cuentas.tipos_cuenta(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_cuentas_cuentas_cajero_apertura'
          AND conrelid = 'cuentas.cuentas'::regclass
    ) THEN
        ALTER TABLE cuentas.cuentas
            ADD CONSTRAINT fk_cuentas_cuentas_cajero_apertura
            FOREIGN KEY (cajero_apertura_id) REFERENCES rrhh.empleados(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_cajas_sesiones_cajero'
          AND conrelid = 'cajas.sesiones_caja'::regclass
    ) THEN
        ALTER TABLE cajas.sesiones_caja
            ADD CONSTRAINT fk_cajas_sesiones_cajero
            FOREIGN KEY (cajero_id) REFERENCES rrhh.empleados(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_cajas_sesiones_usuario'
          AND conrelid = 'cajas.sesiones_caja'::regclass
    ) THEN
        ALTER TABLE cajas.sesiones_caja
            ADD CONSTRAINT fk_cajas_sesiones_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'movimientos_caja_id_fkey'
          AND conrelid = 'transacciones.movimientos'::regclass
    ) THEN
        ALTER TABLE transacciones.movimientos DROP CONSTRAINT movimientos_caja_id_fkey;
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_movimientos_cuenta'
          AND conrelid = 'transacciones.movimientos'::regclass
    ) THEN
        ALTER TABLE transacciones.movimientos
            ADD CONSTRAINT fk_transacciones_movimientos_cuenta
            FOREIGN KEY (cuenta_id) REFERENCES cuentas.cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_movimientos_cajero'
          AND conrelid = 'transacciones.movimientos'::regclass
    ) THEN
        ALTER TABLE transacciones.movimientos
            ADD CONSTRAINT fk_transacciones_movimientos_cajero
            FOREIGN KEY (cajero_id) REFERENCES rrhh.empleados(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_movimientos_operador'
          AND conrelid = 'transacciones.movimientos'::regclass
    ) THEN
        ALTER TABLE transacciones.movimientos
            ADD CONSTRAINT fk_transacciones_movimientos_operador
            FOREIGN KEY (operador_id) REFERENCES rrhh.empleados(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_movimientos_caja'
          AND conrelid = 'transacciones.movimientos'::regclass
    ) THEN
        ALTER TABLE transacciones.movimientos
            ADD CONSTRAINT fk_transacciones_movimientos_caja
            FOREIGN KEY (caja_id) REFERENCES cajas.sesiones_caja(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_transferencias_cuenta_origen'
          AND conrelid = 'transacciones.transferencias'::regclass
    ) THEN
        ALTER TABLE transacciones.transferencias
            ADD CONSTRAINT fk_transacciones_transferencias_cuenta_origen
            FOREIGN KEY (cuenta_origen_id) REFERENCES cuentas.cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_transferencias_cuenta_destino'
          AND conrelid = 'transacciones.transferencias'::regclass
    ) THEN
        ALTER TABLE transacciones.transferencias
            ADD CONSTRAINT fk_transacciones_transferencias_cuenta_destino
            FOREIGN KEY (cuenta_destino_id) REFERENCES cuentas.cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_transacciones_transferencias_operador'
          AND conrelid = 'transacciones.transferencias'::regclass
    ) THEN
        ALTER TABLE transacciones.transferencias
            ADD CONSTRAINT fk_transacciones_transferencias_operador
            FOREIGN KEY (operador_id) REFERENCES rrhh.empleados(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ach_transferencias_cuenta_origen'
          AND conrelid = 'ach.transferencias'::regclass
    ) THEN
        ALTER TABLE ach.transferencias
            ADD CONSTRAINT fk_ach_transferencias_cuenta_origen
            FOREIGN KEY (cuenta_origen_id) REFERENCES cuentas.cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_ach_transferencias_usuario'
          AND conrelid = 'ach.transferencias'::regclass
    ) THEN
        ALTER TABLE ach.transferencias
            ADD CONSTRAINT fk_ach_transferencias_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_contabilidad_asientos_movimiento'
          AND conrelid = 'contabilidad.asientos'::regclass
    ) THEN
        ALTER TABLE contabilidad.asientos
            ADD CONSTRAINT fk_contabilidad_asientos_movimiento
            FOREIGN KEY (movimiento_id) REFERENCES transacciones.movimientos(id)
            ON UPDATE CASCADE ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_contabilidad_asientos_cuenta_contable'
          AND conrelid = 'contabilidad.asientos'::regclass
    ) THEN
        ALTER TABLE contabilidad.asientos
            ADD CONSTRAINT fk_contabilidad_asientos_cuenta_contable
            FOREIGN KEY (cuenta_contable_id) REFERENCES contabilidad.plan_cuentas(id)
            ON UPDATE CASCADE ON DELETE RESTRICT;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_auditoria_log_operaciones_usuario'
          AND conrelid = 'auditoria.log_operaciones'::regclass
    ) THEN
        ALTER TABLE auditoria.log_operaciones
            ADD CONSTRAINT fk_auditoria_log_operaciones_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id)
            ON UPDATE CASCADE ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_crm_clientes_tipo_cliente'
          AND conrelid = 'crm.clientes'::regclass
    ) THEN
        ALTER TABLE crm.clientes
            ADD CONSTRAINT ck_crm_clientes_tipo_cliente
            CHECK (tipo_cliente IS NULL OR UPPER(tipo_cliente) IN ('NATURAL', 'JURIDICA'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_crm_clientes_estado'
          AND conrelid = 'crm.clientes'::regclass
    ) THEN
        ALTER TABLE crm.clientes
            ADD CONSTRAINT ck_crm_clientes_estado
            CHECK (estado IS NULL OR UPPER(estado) IN ('PROSPECTO', 'EN_REVISION', 'ACTIVO', 'BLOQUEADO', 'INACTIVO'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_cuentas_cuentas_estado'
          AND conrelid = 'cuentas.cuentas'::regclass
    ) THEN
        ALTER TABLE cuentas.cuentas
            ADD CONSTRAINT ck_cuentas_cuentas_estado
            CHECK (estado IS NULL OR UPPER(estado) IN ('ACTIVA', 'BLOQUEADA', 'CERRADA'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_cajas_sesiones_estado'
          AND conrelid = 'cajas.sesiones_caja'::regclass
    ) THEN
        ALTER TABLE cajas.sesiones_caja
            ADD CONSTRAINT ck_cajas_sesiones_estado
            CHECK (estado IS NULL OR UPPER(estado) IN ('ABIERTA', 'CERRADA'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_ach_transferencias_estado'
          AND conrelid = 'ach.transferencias'::regclass
    ) THEN
        ALTER TABLE ach.transferencias
            ADD CONSTRAINT ck_ach_transferencias_estado
            CHECK (estado IS NULL OR UPPER(estado) IN ('PENDIENTE', 'ENVIADA', 'CONFIRMADA', 'RECHAZADA', 'ERROR'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_contabilidad_asientos_tipo'
          AND conrelid = 'contabilidad.asientos'::regclass
    ) THEN
        ALTER TABLE contabilidad.asientos
            ADD CONSTRAINT ck_contabilidad_asientos_tipo
            CHECK (tipo_asiento IS NULL OR UPPER(tipo_asiento) IN ('DB', 'CR'));
    END IF;
END $$;
