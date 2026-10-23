-- =====================================================================
-- QA_Readiness_Check_Nexus.sql — Checklist de SOLO LECTURA del entorno QA (Documento E2, sección 7)
-- Ejecutar después de MockData_Sintetica.sql + MockData_Fixtures_Nexus.sql:
--   psql -h 127.0.0.1 -p 15433 -U e2qa -d bancoerp_e2_qa -f QA_Readiness_Check_Nexus.sql > Capturas_Readiness_Entorno/Checklist_DB_Nexus.txt
-- Cada consulta devuelve la columna "ok" (true = condición cumplida).
-- =====================================================================
\set ON_ERROR_STOP on
\pset footer off
BEGIN READ ONLY;

\echo '== C-01 Base de datos QA aislada'
SELECT current_database() AS base, current_database() = 'bancoerp_e2_qa' AS ok;

\echo '== C-02 Volumen de la carga base (RD-05: 8 / 1000 / 2000 / 10000 + capa Nexus)'
SELECT (SELECT count(*) FROM seguridad.usuarios)        AS usuarios,
       (SELECT count(*) FROM crm.clientes)              AS clientes,
       (SELECT count(*) FROM cuentas.cuentas)           AS cuentas,
       (SELECT count(*) FROM transacciones.movimientos) AS movimientos,
       (SELECT count(*) FROM crm.clientes) >= 1000 AND (SELECT count(*) FROM cuentas.cuentas) >= 2000
         AND (SELECT count(*) FROM transacciones.movimientos) >= 10000 AS ok;

\echo '== C-03 Usuarios de los casos (TD-01..TD-04, TD-21)'
SELECT u.username, u.estado, u.bloqueado, u.intentos_fallidos, string_agg(r.codigo, ',') AS roles,
       CASE u.username WHEN 'qa_inactivo' THEN u.estado = false
                       WHEN 'qa_bloqueado' THEN u.bloqueado = true
                       ELSE u.estado = true AND u.bloqueado = false END AS ok
FROM seguridad.usuarios u
LEFT JOIN seguridad.usuarios_roles ur ON ur.usuario_id = u.id AND ur.estado
LEFT JOIN seguridad.roles r ON r.id = ur.rol_id
WHERE u.username IN ('qa_admin','qa_cajero','qa_cajero2','qa_inactivo','qa_bloqueo','qa_bloqueado','qa_sin_empleado','qa_cliente_ana','qa_cliente_bruno','qa_banco_externo')
GROUP BY u.username, u.estado, u.bloqueado, u.intentos_fallidos ORDER BY u.username;

\echo '== C-04 Empleados: qa_cajero y qa_cajero2 con empleado ACTIVO; qa_sin_empleado sin empleado'
SELECT u.username, e.estado AS empleado,
       CASE WHEN u.username = 'qa_sin_empleado' THEN e.id IS NULL ELSE e.estado = 'ACTIVO' END AS ok
FROM seguridad.usuarios u LEFT JOIN rrhh.empleados e ON e.usuario_id = u.id
WHERE u.username IN ('qa_cajero','qa_cajero2','qa_sin_empleado') ORDER BY 1;

\echo '== C-05 Clientes Nexus (TD-05, TC-REQ05-002, TC-REQ06-002)'
SELECT dpi, nombre_completo, estado,
       estado = CASE dpi WHEN '2999999990103' THEN 'EN_REVISION' WHEN '2999999990104' THEN 'EN_REVISION' ELSE 'ACTIVO' END AS ok
FROM crm.clientes WHERE dpi IN ('2999999990101','2999999990102','2999999990103','2999999990104') ORDER BY dpi;

\echo '== C-06 DPIs que crean los casos NO deben existir antes de ejecutar (TC-REQ04-001/002, TC-REQ05-001)'
SELECT count(*) AS existentes, count(*) = 0 AS ok
FROM crm.clientes WHERE dpi IN ('2999999990199','2999999990198','2999999990197','2999999990196','2999999990195','2999999990194');

\echo '== C-07 Cuentas Nexus con saldos/estados del fixture (TD-10..TD-15)'
SELECT numero_cuenta, tipo_cuenta, estado, saldo, saldo_minimo, limite_retiro_diario, monto_retirado_hoy,
       (numero_cuenta, estado, saldo, monto_retirado_hoy) IN (
         ('AH261002000101','ACTIVA',7000.00,0.00), ('MO261002000102','ACTIVA',1500.00,0.00), ('AH261002000103','BLOQUEADA',500.00,0.00),
         ('AH261002000104','ACTIVA',6000.00,4900.00), ('AH261002000105','ACTIVA',8000.00,4990.00), ('AH261002000201','ACTIVA',3000.00,0.00),
         ('MO261002000202','ACTIVA',800.00,0.00), ('AH261002000203','ACTIVA',500.00,0.00), ('AH261002000204','ACTIVA',0.00,0.00),
         ('AH261002000205','CERRADA',0.00,0.00), ('AH261002000206','ACTIVA',2500.00,0.00), ('AH261002000207','ACTIVA',12000.00,0.00),
         ('AH261002000208','ACTIVA',3000.00,0.00), ('AH261002000209','ACTIVA',500.00,0.00), ('AH261002000210','ACTIVA',1000.00,0.00),
         ('AH261002000211','ACTIVA',1000.00,0.00)) AS ok
FROM cuentas.cuentas WHERE numero_cuenta LIKE 'AH2610020001%' OR numero_cuenta LIKE 'MO2610020001%'
                        OR numero_cuenta LIKE 'AH2610020002%' OR numero_cuenta LIKE 'MO2610020002%'
ORDER BY numero_cuenta;

\echo '== C-08 Plan contable 1101 / 2101 / 2102 activo (TD-24, TC-REQ18-002)'
SELECT codigo, activo, activo AS ok FROM contabilidad.plan_cuentas WHERE codigo IN ('1101','2101','2102') ORDER BY codigo;

\echo '== C-09 Tipos de cuenta AHORRO / MONETARIA (TC-REQ06-001)'
SELECT codigo, saldo_minimo, limite_retiro_diario, true AS ok FROM cuentas.tipos_cuenta WHERE codigo IN ('AHORRO','MONETARIA') ORDER BY codigo;

\echo '== C-10 Permisos públicos del rol BANCO_EXTERNO (TD-21 / TC-REQ17-001..003)'
SELECT p.codigo, true AS ok FROM seguridad.roles_permisos rp
JOIN seguridad.roles r ON r.id = rp.rol_id JOIN seguridad.permisos p ON p.id = rp.permiso_id
WHERE r.codigo = 'BANCO_EXTERNO' ORDER BY p.codigo;

\echo '== C-11 reportes.ver: CAJERO no lo tiene, ADMIN sí (TC-REQ16-002)'
SELECT r.codigo AS rol, EXISTS (SELECT 1 FROM seguridad.roles_permisos rp JOIN seguridad.permisos p ON p.id = rp.permiso_id
                                 WHERE rp.rol_id = r.id AND p.codigo = 'reportes.ver') AS tiene_reportes_ver,
       CASE r.codigo WHEN 'CAJERO' THEN NOT EXISTS (SELECT 1 FROM seguridad.roles_permisos rp JOIN seguridad.permisos p ON p.id = rp.permiso_id
                                                  WHERE rp.rol_id = r.id AND p.codigo = 'reportes.ver')
                     ELSE true END AS ok
FROM seguridad.roles r WHERE r.codigo IN ('ADMIN','CAJERO') ORDER BY 1;

\echo '== C-12 Datos sintéticos: sin correos fuera de dominios reservados en la capa Nexus'
SELECT count(*) AS correos_no_reservados, count(*) = 0 AS ok FROM seguridad.usuarios
WHERE email NOT LIKE '%.test' AND email NOT LIKE '%.invalid';

\echo '== C-13 Cajas abiertas de los operadores QA (debe ser 0 antes de TC-REQ08-001)'
SELECT count(*) AS abiertas, count(*) = 0 AS ok FROM cajas.sesiones_caja s
JOIN rrhh.empleados e ON e.id = s.cajero_id JOIN seguridad.usuarios u ON u.id = e.usuario_id
WHERE s.estado = 'ABIERTA' AND u.username IN ('qa_cajero','qa_cajero2');

COMMIT;
