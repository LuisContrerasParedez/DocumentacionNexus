CREATE SEQUENCE IF NOT EXISTS ach.codigo_confirmacion_seq START WITH 1 INCREMENT BY 1;

ALTER TABLE ach.transferencias
    ADD COLUMN IF NOT EXISTS codigo_confirmacion text;

CREATE UNIQUE INDEX IF NOT EXISTS ux_ach_transferencias_codigo_confirmacion
    ON ach.transferencias (codigo_confirmacion)
    WHERE codigo_confirmacion IS NOT NULL;
