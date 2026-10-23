-- Preparacion de datos QA para el Plan de Pruebas de la Public API ACH.
-- Idempotente: se puede ejecutar varias veces sobre la base local (docker compose).
-- Uso: docker exec -i bancoerp-dev-postgres-1 psql -U bancoerp -d bancoerp < 01_preparar_datos_qa.sql
--
-- Crea tres usuarios de prueba (la contrasena se entrega por variable QA_PASSWORD, no se documenta):
--   qa.externo.bloqueo@test.com  -> rol BANCO_EXTERNO, activo  (prueba de bloqueo por intentos)
--   qa.externo.inactivo@test.com -> rol BANCO_EXTERNO, inactivo (prueba 403 usuario inactivo)
--   qa.sin.rol@test.com          -> activo, sin rol BANCO_EXTERNO (prueba 403 no autorizado)

BEGIN;

INSERT INTO seguridad.usuarios (username, email, password_hash, nombres, apellidos, estado, bloqueado, intentos_fallidos)
VALUES
    ('qa_externo_bloqueo',  'qa.externo.bloqueo@test.com',  '$2y$10$puyAOfJ.m8SOE5kisPA7r.WN2cP/DPA/klSGUUhDicFZ/aBcOR0Fy', 'QA', 'Bloqueo',  TRUE,  FALSE, 0),
    ('qa_externo_inactivo', 'qa.externo.inactivo@test.com', '$2y$10$puyAOfJ.m8SOE5kisPA7r.WN2cP/DPA/klSGUUhDicFZ/aBcOR0Fy', 'QA', 'Inactivo', FALSE, FALSE, 0),
    ('qa_sin_rol',          'qa.sin.rol@test.com',          '$2y$10$puyAOfJ.m8SOE5kisPA7r.WN2cP/DPA/klSGUUhDicFZ/aBcOR0Fy', 'QA', 'SinRol',   TRUE,  FALSE, 0)
ON CONFLICT (email) DO UPDATE
SET password_hash = EXCLUDED.password_hash,
    estado = EXCLUDED.estado,
    bloqueado = FALSE,
    bloqueado_hasta = NULL,
    intentos_fallidos = 0,
    updated_at = NOW();

INSERT INTO seguridad.usuarios_roles (usuario_id, rol_id, estado, fecha_asignacion, assigned_by)
SELECT u.id, r.id, TRUE, NOW(), NULL
FROM seguridad.usuarios u
CROSS JOIN seguridad.roles r
WHERE u.email IN ('qa.externo.bloqueo@test.com', 'qa.externo.inactivo@test.com')
  AND r.codigo = 'BANCO_EXTERNO'
ON CONFLICT (usuario_id, rol_id) DO UPDATE SET estado = TRUE;

-- El usuario tecnico oficial inicia cada corrida sin intentos fallidos ni bloqueo.
UPDATE seguridad.usuarios
SET bloqueado = FALSE, bloqueado_hasta = NULL, intentos_fallidos = 0, updated_at = NOW()
WHERE email = 'bancoexterno@nexus.com';

COMMIT;

-- Cuentas destino usadas por los casos (creadas por seeds/demo_data_seed.sql):
SELECT numero_cuenta, estado, moneda, saldo
FROM cuentas.cuentas
ORDER BY estado, numero_cuenta;
