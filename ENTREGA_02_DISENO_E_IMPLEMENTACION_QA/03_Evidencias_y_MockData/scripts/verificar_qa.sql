-- Solo lectura; base exclusiva de esta entrega.
DO $$ BEGIN IF current_database()<>'bancoerp_e2_qa' THEN
  RAISE EXCEPTION 'Solo QA'; END IF; END $$;
SELECT current_database(), current_user, version();

-- Saldos antes/después: ajustar números a la ficha.
SELECT id,numero_cuenta,estado,saldo,saldo_disponible,saldo_minimo,
       limite_retiro_diario,monto_retirado_hoy
FROM cuentas.cuentas
WHERE numero_cuenta IN ('AH000000000001','MO000000000002');

-- Idempotencia: ajustar al código EXACTO del caso y runId.
SELECT codigo_confirmacion,count(*) AS veces,sum(monto) AS monto
FROM ach.transferencias_entrantes
WHERE codigo_confirmacion LIKE 'E2-%'
GROUP BY codigo_confirmacion;

-- Verificar partida doble SOLO de nuevas operaciones, no del histórico mock.
SELECT m.referencia,m.tipo,count(a.id) AS asientos,
 sum(CASE WHEN a.tipo_asiento='DB' THEN a.monto ELSE 0 END) AS debe,
 sum(CASE WHEN a.tipo_asiento='CR' THEN a.monto ELSE 0 END) AS haber
FROM transacciones.movimientos m
LEFT JOIN contabilidad.asientos a ON a.movimiento_id=m.id
WHERE m.referencia NOT LIKE 'E2-HIST-%'
  AND m.referencia NOT LIKE 'E2-PAG-%'
GROUP BY m.referencia,m.tipo ORDER BY m.referencia;

SELECT username,estado,bloqueado,intentos_fallidos,bloqueado_hasta
FROM seguridad.usuarios WHERE username LIKE 'qa_%';
SELECT u.username,count(*) FILTER(WHERE s.estado) AS sesiones_activas
FROM seguridad.usuarios u LEFT JOIN seguridad.sesiones s
 ON s.usuario_id=u.id GROUP BY u.username;

SELECT evento,username_intentado,ip_address,user_agent,exitoso,created_at
FROM seguridad.eventos_seguridad ORDER BY created_at DESC LIMIT 30;
SELECT estado,fondo_inicial,total_depositos,total_retiros,
 efectivo_contado,diferencia,hora_cierre FROM cajas.sesiones_caja;
SELECT codigo,activo FROM contabilidad.plan_cuentas
WHERE codigo IN ('1101','2101');


-- ACH saliente: contrastar estado y saldo con D-08; código del request real.
SELECT id,banco_codigo,codigo_confirmacion,estado,monto,mensaje_error,
 cuenta_origen_id,fecha_creacion,fecha_actualizacion
FROM ach.transferencias WHERE banco_codigo LIKE 'E2_QA_%'
ORDER BY fecha_creacion DESC;

-- Catálogo de eventos ejecutados; el diseño usa 20 códigos reconciliados.
SELECT evento,count(*) FROM seguridad.eventos_seguridad GROUP BY evento;
