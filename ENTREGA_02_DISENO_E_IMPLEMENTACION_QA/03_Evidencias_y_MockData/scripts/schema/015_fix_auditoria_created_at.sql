-- Production deploy - paso 015
-- Normaliza auditoria.log_operaciones para usar created_at en registros nuevos,
-- sin modificar historicos porque el log es inmutable.

ALTER TABLE auditoria.log_operaciones
    ADD COLUMN IF NOT EXISTS created_at timestamptz;

ALTER TABLE auditoria.log_operaciones
    ALTER COLUMN created_at SET DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_auditoria_log_operaciones_created_at
    ON auditoria.log_operaciones (created_at DESC);
