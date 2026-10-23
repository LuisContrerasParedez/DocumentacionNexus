-- Production deploy - paso 002
-- Crea tablas base y agrega columnas faltantes sin borrar datos.

CREATE TABLE IF NOT EXISTS seguridad.usuarios (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    username varchar(50),
    email varchar(150),
    password_hash text,
    nombres varchar(100),
    apellidos varchar(100),
    telefono varchar(20),
    fotografia_url text,
    estado boolean DEFAULT true,
    bloqueado boolean DEFAULT false,
    intentos_fallidos integer DEFAULT 0,
    bloqueado_hasta timestamptz,
    debe_cambiar_password boolean DEFAULT false,
    ultimo_login timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS username varchar(50);
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS email varchar(150);
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS password_hash text;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS nombres varchar(100);
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS apellidos varchar(100);
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS telefono varchar(20);
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS fotografia_url text;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS bloqueado boolean DEFAULT false;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS intentos_fallidos integer DEFAULT 0;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS bloqueado_hasta timestamptz;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS debe_cambiar_password boolean DEFAULT false;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS ultimo_login timestamptz;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE seguridad.usuarios ADD COLUMN IF NOT EXISTS updated_by uuid;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'seguridad'
          AND table_name = 'usuarios'
          AND column_name = 'correo'
    ) AND NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'seguridad'
          AND table_name = 'usuarios'
          AND column_name = 'email'
    ) THEN
        ALTER TABLE seguridad.usuarios RENAME COLUMN correo TO email;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS seguridad.roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo varchar(50),
    nombre varchar(100),
    descripcion varchar(255),
    estado boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS codigo varchar(50);
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS nombre varchar(100);
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS descripcion varchar(255);
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE seguridad.roles ADD COLUMN IF NOT EXISTS updated_by uuid;

CREATE TABLE IF NOT EXISTS seguridad.permisos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo varchar(100),
    nombre varchar(150),
    descripcion varchar(255),
    modulo varchar(100),
    accion varchar(50),
    estado boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS codigo varchar(100);
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS nombre varchar(150);
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS descripcion varchar(255);
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS modulo varchar(100);
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS accion varchar(50);
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE seguridad.permisos ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS seguridad.usuarios_roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    rol_id uuid,
    estado boolean DEFAULT true,
    fecha_asignacion timestamptz DEFAULT now(),
    assigned_by uuid
);

ALTER TABLE seguridad.usuarios_roles ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.usuarios_roles ADD COLUMN IF NOT EXISTS rol_id uuid;
ALTER TABLE seguridad.usuarios_roles ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.usuarios_roles ADD COLUMN IF NOT EXISTS fecha_asignacion timestamptz DEFAULT now();
ALTER TABLE seguridad.usuarios_roles ADD COLUMN IF NOT EXISTS assigned_by uuid;

CREATE TABLE IF NOT EXISTS seguridad.roles_permisos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rol_id uuid,
    permiso_id uuid,
    created_at timestamptz DEFAULT now(),
    created_by uuid
);

ALTER TABLE seguridad.roles_permisos ADD COLUMN IF NOT EXISTS rol_id uuid;
ALTER TABLE seguridad.roles_permisos ADD COLUMN IF NOT EXISTS permiso_id uuid;
ALTER TABLE seguridad.roles_permisos ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE seguridad.roles_permisos ADD COLUMN IF NOT EXISTS created_by uuid;

CREATE TABLE IF NOT EXISTS seguridad.usuarios_permisos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    permiso_id uuid,
    permitido boolean DEFAULT true,
    fecha_asignacion timestamptz DEFAULT now(),
    assigned_by uuid
);

ALTER TABLE seguridad.usuarios_permisos ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.usuarios_permisos ADD COLUMN IF NOT EXISTS permiso_id uuid;
ALTER TABLE seguridad.usuarios_permisos ADD COLUMN IF NOT EXISTS permitido boolean DEFAULT true;
ALTER TABLE seguridad.usuarios_permisos ADD COLUMN IF NOT EXISTS fecha_asignacion timestamptz DEFAULT now();
ALTER TABLE seguridad.usuarios_permisos ADD COLUMN IF NOT EXISTS assigned_by uuid;

CREATE TABLE IF NOT EXISTS seguridad.sesiones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    refresh_token_hash text,
    ip_address varchar(100),
    user_agent text,
    estado boolean DEFAULT true,
    fecha_inicio timestamptz DEFAULT now(),
    fecha_expiracion timestamptz,
    fecha_cierre timestamptz
);

ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS refresh_token_hash text;
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS ip_address varchar(100);
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS user_agent text;
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS fecha_inicio timestamptz DEFAULT now();
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS fecha_expiracion timestamptz;
ALTER TABLE seguridad.sesiones ADD COLUMN IF NOT EXISTS fecha_cierre timestamptz;

CREATE TABLE IF NOT EXISTS seguridad.tokens_recuperacion (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    token_hash text,
    usado boolean DEFAULT false,
    fecha_expiracion timestamptz,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE seguridad.tokens_recuperacion ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.tokens_recuperacion ADD COLUMN IF NOT EXISTS token_hash text;
ALTER TABLE seguridad.tokens_recuperacion ADD COLUMN IF NOT EXISTS usado boolean DEFAULT false;
ALTER TABLE seguridad.tokens_recuperacion ADD COLUMN IF NOT EXISTS fecha_expiracion timestamptz;
ALTER TABLE seguridad.tokens_recuperacion ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS seguridad.password_historial (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    password_hash text,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE seguridad.password_historial ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.password_historial ADD COLUMN IF NOT EXISTS password_hash text;
ALTER TABLE seguridad.password_historial ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS seguridad.api_keys (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre varchar(100),
    api_key_hash text,
    usuario_id uuid,
    estado boolean DEFAULT true,
    ultimo_uso timestamptz,
    fecha_expiracion timestamptz,
    created_at timestamptz DEFAULT now(),
    revoked_at timestamptz
);

ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS nombre varchar(100);
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS api_key_hash text;
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS estado boolean DEFAULT true;
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS ultimo_uso timestamptz;
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS fecha_expiracion timestamptz;
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE seguridad.api_keys ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

CREATE TABLE IF NOT EXISTS seguridad.eventos_seguridad (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id uuid,
    username_intentado varchar(100),
    evento varchar(50),
    descripcion text,
    ip_address varchar(100),
    user_agent text,
    exitoso boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS username_intentado varchar(100);
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS evento varchar(50);
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS descripcion text;
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS ip_address varchar(100);
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS user_agent text;
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS exitoso boolean DEFAULT true;
ALTER TABLE seguridad.eventos_seguridad ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS catalogos.items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    grupo varchar(80),
    codigo varchar(80),
    nombre varchar(120),
    descripcion varchar(255),
    orden integer DEFAULT 0,
    activo boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz,
    created_by uuid,
    updated_by uuid
);

ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS grupo varchar(80);
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS codigo varchar(80);
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS nombre varchar(120);
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS descripcion varchar(255);
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS orden integer DEFAULT 0;
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS updated_at timestamptz;
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE catalogos.items ADD COLUMN IF NOT EXISTS updated_by uuid;

CREATE TABLE IF NOT EXISTS crm.clientes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_cliente varchar(20),
    nombre_completo varchar(255),
    dpi varchar(20),
    primer_nombre varchar(100),
    segundo_nombre varchar(100),
    primer_apellido varchar(100),
    segundo_apellido varchar(100),
    fecha_nacimiento date,
    email varchar(150),
    telefono varchar(20),
    estado varchar(50),
    observaciones text,
    usuario_id uuid,
    creado_por uuid,
    aprobado_por uuid,
    fecha_aprobacion timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS tipo_cliente varchar(20);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS nombre_completo varchar(255);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS dpi varchar(20);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS primer_nombre varchar(100);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS segundo_nombre varchar(100);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS primer_apellido varchar(100);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS segundo_apellido varchar(100);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS fecha_nacimiento date;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS email varchar(150);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS telefono varchar(20);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS estado varchar(50);
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS observaciones text;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS creado_por uuid;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS aprobado_por uuid;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS fecha_aprobacion timestamptz;
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE crm.clientes ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS rrhh.empleados (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    primer_nombre varchar(100),
    segundo_nombre varchar(100),
    primer_apellido varchar(100),
    segundo_apellido varchar(100),
    cargo varchar(120),
    turno varchar(50),
    estado varchar(50),
    usuario_id uuid,
    fecha_ingreso date,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS primer_nombre varchar(100);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS segundo_nombre varchar(100);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS primer_apellido varchar(100);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS segundo_apellido varchar(100);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS cargo varchar(120);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS turno varchar(50);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS estado varchar(50);
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS fecha_ingreso date;
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE rrhh.empleados ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS cuentas.tipos_cuenta (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo varchar(50),
    nombre varchar(100),
    descripcion varchar(255),
    saldo_minimo numeric(18,2) DEFAULT 0,
    limite_retiro_diario numeric(18,2),
    permite_cheques boolean DEFAULT false,
    tasa_interes_anual numeric(5,4) DEFAULT 0,
    activo boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS codigo varchar(50);
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS nombre varchar(100);
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS descripcion varchar(255);
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS saldo_minimo numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS limite_retiro_diario numeric(18,2);
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS permite_cheques boolean DEFAULT false;
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS tasa_interes_anual numeric(5,4) DEFAULT 0;
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE cuentas.tipos_cuenta ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS cuentas.cuentas (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_cuenta varchar(50),
    tipo_cuenta varchar(50),
    tipo_cuenta_id uuid,
    cliente_id uuid,
    saldo numeric(18,2) DEFAULT 0,
    saldo_disponible numeric(18,2) DEFAULT 0,
    saldo_retenido numeric(18,2) DEFAULT 0,
    saldo_minimo numeric(18,2) DEFAULT 0,
    limite_retiro_diario numeric(18,2),
    monto_retirado_hoy numeric(18,2) DEFAULT 0,
    permite_cheques boolean DEFAULT false,
    tasa_interes_anual numeric(5,4) DEFAULT 0,
    moneda varchar(10) DEFAULT 'GTQ',
    cajero_apertura_id uuid,
    estado varchar(50) DEFAULT 'ACTIVA',
    fecha_apertura timestamptz DEFAULT now(),
    fecha_cierre timestamptz,
    motivo_cierre text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS numero_cuenta varchar(50);
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS tipo_cuenta varchar(50);
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS tipo_cuenta_id uuid;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS cliente_id uuid;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS saldo numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS saldo_disponible numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS saldo_retenido numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS saldo_minimo numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS limite_retiro_diario numeric(18,2);
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS monto_retirado_hoy numeric(18,2) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS permite_cheques boolean DEFAULT false;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS tasa_interes_anual numeric(5,4) DEFAULT 0;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS moneda varchar(10) DEFAULT 'GTQ';
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS cajero_apertura_id uuid;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS estado varchar(50) DEFAULT 'ACTIVA';
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS fecha_apertura timestamptz DEFAULT now();
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS fecha_cierre timestamptz;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS motivo_cierre text;
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE cuentas.cuentas ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS cajas.sesiones_caja (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cajero_id uuid,
    usuario_id uuid,
    fecha date,
    fondo_inicial numeric(18,2) DEFAULT 0,
    efectivo_contado numeric(18,2),
    total_depositos numeric(18,2) DEFAULT 0,
    total_retiros numeric(18,2) DEFAULT 0,
    diferencia numeric(18,2),
    justificacion text,
    estado varchar(20) DEFAULT 'ABIERTA',
    hora_apertura timestamptz DEFAULT now(),
    hora_cierre timestamptz
);

ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS cajero_id uuid;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS fecha date;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS fondo_inicial numeric(18,2) DEFAULT 0;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS efectivo_contado numeric(18,2);
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS total_depositos numeric(18,2) DEFAULT 0;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS total_retiros numeric(18,2) DEFAULT 0;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS diferencia numeric(18,2);
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS justificacion text;
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS estado varchar(20) DEFAULT 'ABIERTA';
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS hora_apertura timestamptz DEFAULT now();
ALTER TABLE cajas.sesiones_caja ADD COLUMN IF NOT EXISTS hora_cierre timestamptz;

CREATE TABLE IF NOT EXISTS transacciones.movimientos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    referencia varchar(100),
    referencia_par varchar(100),
    cuenta_id uuid,
    tipo varchar(50),
    monto numeric(18,2),
    saldo_anterior numeric(18,2),
    saldo_posterior numeric(18,2),
    cajero_id uuid,
    operador_id uuid,
    caja_id uuid,
    descripcion text,
    estado varchar(50),
    canal varchar(50),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS referencia varchar(100);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS referencia_par varchar(100);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS cuenta_id uuid;
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS tipo varchar(50);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS monto numeric(18,2);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS saldo_anterior numeric(18,2);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS saldo_posterior numeric(18,2);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS cajero_id uuid;
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS operador_id uuid;
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS caja_id uuid;
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS descripcion text;
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS estado varchar(50);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS canal varchar(50);
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE transacciones.movimientos ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS transacciones.transferencias (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    referencia varchar(100),
    cuenta_origen_id uuid,
    cuenta_destino_id uuid,
    monto numeric(18,2),
    descripcion text,
    operador_id uuid,
    fecha_transferencia timestamptz DEFAULT now()
);

ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS referencia varchar(100);
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS cuenta_origen_id uuid;
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS cuenta_destino_id uuid;
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS monto numeric(18,2);
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS descripcion text;
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS operador_id uuid;
ALTER TABLE transacciones.transferencias ADD COLUMN IF NOT EXISTS fecha_transferencia timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS ach.transferencias (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    banco_ach_id text,
    banco_codigo text,
    cuenta_origen_id uuid,
    monto numeric(18,2),
    descripcion text,
    codigo_confirmacion text,
    estado text,
    request_json jsonb DEFAULT '{}'::jsonb,
    response_json jsonb,
    mensaje_error text,
    usuario_id uuid,
    fecha_creacion timestamptz DEFAULT now(),
    fecha_actualizacion timestamptz DEFAULT now()
);

ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS banco_ach_id text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS banco_codigo text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS cuenta_origen_id uuid;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS monto numeric(18,2);
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS descripcion text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS codigo_confirmacion text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS estado text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS request_json jsonb DEFAULT '{}'::jsonb;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS response_json jsonb;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS mensaje_error text;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS fecha_creacion timestamptz DEFAULT now();
ALTER TABLE ach.transferencias ADD COLUMN IF NOT EXISTS fecha_actualizacion timestamptz DEFAULT now();

CREATE SEQUENCE IF NOT EXISTS ach.codigo_confirmacion_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS contabilidad.plan_cuentas (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo varchar(20),
    nombre varchar(150),
    descripcion varchar(255),
    tipo_cuenta varchar(20),
    activo boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS codigo varchar(20);
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS nombre varchar(150);
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS descripcion varchar(255);
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS tipo_cuenta varchar(20);
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE contabilidad.plan_cuentas ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS contabilidad.asientos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    movimiento_id uuid,
    cuenta_contable_id uuid,
    tipo_asiento varchar(5),
    monto numeric(18,2),
    sp_origen varchar(100),
    created_at timestamptz DEFAULT now()
);

ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS movimiento_id uuid;
ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS cuenta_contable_id uuid;
ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS tipo_asiento varchar(5);
ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS monto numeric(18,2);
ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS sp_origen varchar(100);
ALTER TABLE contabilidad.asientos ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

CREATE TABLE IF NOT EXISTS auditoria.log_operaciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    modulo varchar(100),
    accion varchar(100),
    entidad_tipo varchar(100),
    entidad_id uuid,
    datos_antes jsonb,
    datos_despues jsonb,
    resultado varchar(50),
    usuario_id uuid,
    created_at timestamptz DEFAULT now()
);

ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS modulo varchar(100);
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS accion varchar(100);
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS entidad_tipo varchar(100);
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS entidad_id uuid;
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS datos_antes jsonb;
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS datos_despues jsonb;
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS resultado varchar(50);
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE auditoria.log_operaciones ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
