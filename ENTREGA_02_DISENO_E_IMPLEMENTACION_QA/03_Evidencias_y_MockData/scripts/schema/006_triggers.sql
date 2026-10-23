-- Production deploy - paso 006
-- Triggers requeridos por el codigo actual.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'rrhh'
          AND table_name = 'empleados'
    ) THEN
        DROP TRIGGER IF EXISTS tr_rrhh_empleados_validar_catalogos ON rrhh.empleados;
        CREATE TRIGGER tr_rrhh_empleados_validar_catalogos
        BEFORE INSERT OR UPDATE OF cargo, turno, estado
        ON rrhh.empleados
        FOR EACH ROW
        EXECUTE FUNCTION catalogos.validar_empleado_catalogos();
    END IF;
END $$;
