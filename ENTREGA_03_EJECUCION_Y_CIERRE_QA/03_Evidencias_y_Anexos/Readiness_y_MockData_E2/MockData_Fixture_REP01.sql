-- MockData_Fixture_REP01.sql — Fixture aislado para TC-REQ16-001 (reporte resumen)
-- 1) Crear BD vacía con el mismo esquema/catálogos:  createdb -h 127.0.0.1 -p 15433 -U e2qa bancoerp_e2_qa_rep01
--    psql ... -d bancoerp_e2_qa_rep01 -f scripts/init_all.sql   (esquema, catálogos, plan contable, SPs)
-- 2) Ejecutar este archivo. 3) Apuntar la InternalAPI/PublicAPI a esta BD (ConnectionStrings__DefaultConnection) y
--    ejecutar las dos operaciones de la carpeta "REP-01" de Postman. 4) GET /api/reportes/resumen y comparar con REP01_Totales_Esperados.json
\set ON_ERROR_STOP on
DO $$ BEGIN IF current_database() <> 'bancoerp_e2_qa_rep01' THEN RAISE EXCEPTION 'Solo bancoerp_e2_qa_rep01'; END IF; END $$;
BEGIN;
INSERT INTO seguridad.usuarios (id,username,email,estado,nombres,apellidos,password_hash) VALUES ('1e99735f-ed03-5b6c-b60b-455321c9507f','qa_admin','qa_admin@example.invalid',true,'Usuario QA REP01','qa_admin',crypt('QaNexus2026',gen_salt('bf'))) ON CONFLICT (id) DO NOTHING;
INSERT INTO seguridad.usuarios_roles(usuario_id,rol_id,estado) SELECT '1e99735f-ed03-5b6c-b60b-455321c9507f', id, true FROM seguridad.roles WHERE codigo='ADMIN' ON CONFLICT(usuario_id,rol_id) DO NOTHING;
INSERT INTO seguridad.usuarios (id,username,email,estado,nombres,apellidos,password_hash) VALUES ('b6b6a2f5-73e0-58b6-8f78-d50f97d583ba','qa_cajero','qa_cajero@example.invalid',true,'Usuario QA REP01','qa_cajero',crypt('QaNexus2026',gen_salt('bf'))) ON CONFLICT (id) DO NOTHING;
INSERT INTO seguridad.usuarios_roles(usuario_id,rol_id,estado) SELECT 'b6b6a2f5-73e0-58b6-8f78-d50f97d583ba', id, true FROM seguridad.roles WHERE codigo='CAJERO' ON CONFLICT(usuario_id,rol_id) DO NOTHING;
INSERT INTO seguridad.usuarios (id,username,email,estado,nombres,apellidos,password_hash) VALUES ('ee25b0a2-90a7-588a-8564-3a7e47c7adb2','qa_banco_externo','qa.banco.externo@nexus.test',true,'Usuario QA REP01','qa_banco_externo',crypt('QaNexus2026',gen_salt('bf'))) ON CONFLICT (id) DO NOTHING;
INSERT INTO seguridad.usuarios_roles(usuario_id,rol_id,estado) SELECT 'ee25b0a2-90a7-588a-8564-3a7e47c7adb2', id, true FROM seguridad.roles WHERE codigo='BANCO_EXTERNO' ON CONFLICT(usuario_id,rol_id) DO NOTHING;
INSERT INTO rrhh.empleados (id,primer_nombre,primer_apellido,cargo,turno,estado,usuario_id,fecha_ingreso) VALUES ('8a2f1475-dbaf-5de5-8b61-66c4eb2c5c96','Operador','Rep01','Cajero','COMPLETO','ACTIVO','b6b6a2f5-73e0-58b6-8f78-d50f97d583ba','2026-01-01') ON CONFLICT (id) DO NOTHING;
INSERT INTO crm.clientes (id,tipo_cliente,nombre_completo,dpi,primer_nombre,primer_apellido,fecha_nacimiento,email,estado) VALUES ('d04c9c95-815b-50ce-939c-3fc600670939','NATURAL','Rita Reporte','2999999990301','Rita','Reporte','1990-01-01','rita.rep01@nexus.test','ACTIVO') ON CONFLICT (id) DO NOTHING;
INSERT INTO crm.clientes (id,tipo_cliente,nombre_completo,dpi,primer_nombre,primer_apellido,fecha_nacimiento,email,estado) VALUES ('1c406a74-5f1b-5e59-a2f6-530e7ebbc5e6','NATURAL','Raul Reporte','2999999990302','Raul','Reporte','1990-01-01','raul.rep01@nexus.test','EN_REVISION') ON CONFLICT (id) DO NOTHING;
INSERT INTO cuentas.cuentas (id,numero_cuenta,cliente_id,tipo_cuenta,saldo,saldo_disponible,saldo_minimo,limite_retiro_diario,monto_retirado_hoy,estado,moneda) VALUES ('4cdaf3d0-4349-591a-b8ae-1ccd268354ef','AH261002000301','d04c9c95-815b-50ce-939c-3fc600670939','AHORRO','2475.00','2475.00','100.00','5000.00','0.00','ACTIVA','GTQ') ON CONFLICT (id) DO NOTHING;
INSERT INTO cuentas.cuentas (id,numero_cuenta,cliente_id,tipo_cuenta,saldo,saldo_disponible,saldo_minimo,limite_retiro_diario,monto_retirado_hoy,estado,moneda) VALUES ('49839e41-269c-5fa4-a689-32cd0a1e21d6','MO261002000302','d04c9c95-815b-50ce-939c-3fc600670939','MONETARIA','1500.00','1500.00','0.00',NULL,'0.00','ACTIVA','GTQ') ON CONFLICT (id) DO NOTHING;
INSERT INTO cuentas.cuentas (id,numero_cuenta,cliente_id,tipo_cuenta,saldo,saldo_disponible,saldo_minimo,limite_retiro_diario,monto_retirado_hoy,estado,moneda) VALUES ('b698e080-2bba-5377-81df-553b7a9b5437','AH261002000303','d04c9c95-815b-50ce-939c-3fc600670939','AHORRO','0.00','0.00','0.00','5000.00','0.00','CERRADA','GTQ') ON CONFLICT (id) DO NOTHING;
COMMIT;
