-- Production deploy - paso 004
-- Funciones auxiliares y de validacion.

CREATE OR REPLACE FUNCTION catalogos.validar_empleado_catalogos()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.cargo IS NULL OR NOT EXISTS (
        SELECT 1
        FROM catalogos.items
        WHERE grupo = 'EMPLEADO_CARGO'
          AND codigo = UPPER(BTRIM(NEW.cargo))
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Cargo invalido para rrhh.empleados: %', NEW.cargo
            USING ERRCODE = '23514';
    END IF;

    IF NEW.turno IS NULL OR NOT EXISTS (
        SELECT 1
        FROM catalogos.items
        WHERE grupo = 'EMPLEADO_TURNO'
          AND codigo = UPPER(BTRIM(NEW.turno))
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Turno invalido para rrhh.empleados: %', NEW.turno
            USING ERRCODE = '23514';
    END IF;

    IF NEW.estado IS NULL OR NOT EXISTS (
        SELECT 1
        FROM catalogos.items
        WHERE grupo = 'EMPLEADO_ESTADO'
          AND codigo = UPPER(BTRIM(NEW.estado))
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'Estado invalido para rrhh.empleados: %', NEW.estado
            USING ERRCODE = '23514';
    END IF;

    NEW.cargo := UPPER(BTRIM(NEW.cargo));
    NEW.turno := UPPER(BTRIM(NEW.turno));
    NEW.estado := UPPER(BTRIM(NEW.estado));
    RETURN NEW;
END;
$$;
