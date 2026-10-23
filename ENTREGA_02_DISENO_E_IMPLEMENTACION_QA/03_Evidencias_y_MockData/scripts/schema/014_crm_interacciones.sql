-- Production deploy - paso 014
-- Bitacora CRM de interacciones y seguimiento por cliente.

CREATE TABLE IF NOT EXISTS crm.cliente_interacciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id uuid NOT NULL,
    tipo varchar(50) NOT NULL,
    canal varchar(50),
    asunto varchar(160),
    detalle text,
    resultado varchar(50),
    usuario_id uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS cliente_id uuid;
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS tipo varchar(50);
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS canal varchar(50);
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS asunto varchar(160);
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS detalle text;
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS resultado varchar(50);
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS usuario_id uuid;
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE crm.cliente_interacciones ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_crm_cliente_interacciones_cliente_fecha
    ON crm.cliente_interacciones (cliente_id, created_at DESC);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_crm_cliente_interacciones_cliente'
          AND conrelid = 'crm.cliente_interacciones'::regclass
    ) THEN
        ALTER TABLE crm.cliente_interacciones
            ADD CONSTRAINT fk_crm_cliente_interacciones_cliente
            FOREIGN KEY (cliente_id) REFERENCES crm.clientes(id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_crm_cliente_interacciones_usuario'
          AND conrelid = 'crm.cliente_interacciones'::regclass
    ) THEN
        ALTER TABLE crm.cliente_interacciones
            ADD CONSTRAINT fk_crm_cliente_interacciones_usuario
            FOREIGN KEY (usuario_id) REFERENCES seguridad.usuarios(id);
    END IF;
END $$;
