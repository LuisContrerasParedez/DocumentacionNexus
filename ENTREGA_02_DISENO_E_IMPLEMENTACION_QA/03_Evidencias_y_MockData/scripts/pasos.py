from pathlib import Path
import json,re
# Convierte los pasos genéricos de una ficha en pasos ejecutables: preparación con SQL/script exacto,
# autenticación del perfil, petición literal, verificación de respuesta y verificación en BD.
I='http://localhost:15141';P='http://localhost:15254';PWD='E2Qa2026*'
GENERIC=('Preparar y verificar las precondiciones','Restaurar y verificar el fixture indicado')
META={'perfil','intentos_previos','Authorization','User-Agent','concurrencia','maestro_inactivo','fecha_expiracion','cuentaId','pagina','tamano','numeroCuenta_path'}
EMP="(SELECT e.id FROM rrhh.empleados e JOIN seguridad.usuarios u ON u.id=e.usuario_id WHERE u.username='qa_cajero')"
UID="(SELECT id FROM seguridad.usuarios WHERE username='{u}')"
RESTAURAR='Ejecutar python3 scripts/preparar_escenario.py (AH000000000001: saldo=disponible=1000.00, mínimo 100.00, límite 500.00, retirado 0; MO000000000002: saldo 500.00; AH000000000003: saldo 1000.00).'
CERRAR_CAJAS=f"En psql-QA cerrar cajas abiertas de qa_cajero: UPDATE cajas.sesiones_caja SET estado='CERRADA', hora_cierre=now() WHERE cajero_id={EMP} AND estado='ABIERTA';"
ABRIR_CAJA=f'Abrir caja con POST {I}/api/cajas/abrir, Bearer de qa_cajero y cuerpo {{"fondoInicial": 2000.00}}; verificar HTTP 200.'
INICIO='En psql-QA registrar el instante de inicio: SELECT now();'
def reset_user(u,pwd=True):
 s=f"UPDATE seguridad.usuarios SET estado=true, bloqueado=false, bloqueado_hasta=NULL, intentos_fallidos=0"+(f", password_hash=crypt('{PWD}', gen_salt('bf',10))" if pwd else '')+f" WHERE username='{u}';"
 return 'En psql-QA restaurar el usuario: '+s
def login(u):
 if u=='qa_externo':return f'Autenticar qa_externo con POST {P}/api/external/auth/login y cuerpo {{"email":"qa_externo@example.invalid","password":"{PWD}"}}; verificar HTTP 200 y guardar accessToken como <token>.'
 return f'Autenticar {u} con POST {I}/api/auth/login y cuerpo {{"username":"{u}","password":"{PWD}"}}; verificar HTTP 200 y guardar token como <token>.'
def cuerpo(x):
 d={k:v for k,v in x['data'].items() if k not in META}
 raw=json.dumps(d,ensure_ascii=False)
 if not x['url'].startswith(P):raw=re.sub(r'("(?:monto|fondoInicial|efectivoContado)":\s*)"(-?\d+(?:\.\d+)?)"',r'\1\2',raw)
 return raw
def perfil(x):
 d=x['data'];u=x['url']
 if d.get('Authorization')=='ausente' or any(k in u for k in ['/auth/login','solicitar-recuperacion','restablecer-password','refresh-token']):return None
 if d.get('perfil'):return d['perfil']
 if x['req']=='REQ-03':return 'qa_bloqueo'
 return 'qa_externo' if u.startswith(P) else 'qa_cajero'
def peticion(x,u):
 h=[]
 if x['method'] in ('POST','PUT','PATCH'):h.append('Content-Type: application/json')
 h.append('Authorization: Bearer <token>' if u else 'sin encabezado Authorization')
 if 'User-Agent' in x['data'] or x['req']=='REQ-07':h.append('User-Agent: '+x['data'].get('User-Agent','E2-QA/2.0'))
 s=f"Enviar {x['method']} {x['url']} "+(f"con {', '.join(h)}" if h[0]!='sin encabezado Authorization' else ', '.join(h))
 if x['method'] in ('POST','PUT','PATCH'):
  b=cuerpo(x);s+=f' y cuerpo {b}'
  if x['req'] in ('REQ-19','REQ-07') and 'codigo_confirmacion' in x['data']:s+=' (en Postman se agrega el sufijo -{{runId}} al código)'
 return s+'.'
# Cláusulas del oráculo que se comprueban en base de datos; el resto se comprueba en la respuesta HTTP.
DB=['saldo final','saldo permanece','saldos','saldo destino','saldo local','saldo intacto','delta','movimiento','asiento','partida','sesión','sesiones','sesion activa','bloqueado=','bloqueado_hasta','intentos_fallidos','hash','caja ','una caja','acumulador','monto_retirado_hoy','retirado hoy','conteo','registros financieros','disponible permanece','hora_cierre','contraseña sin cambios','transferencia persist','ninguna cuenta nueva','cuenta ACTIVA del cliente','saldoMinimo coincide','una transferencia','una sola transferencia','ACH_IN','ACH_OUT','sin acreditación','acreditación','estado persistido','usado=','suma de saldos','ip_address','user_agent','created_at','usuario_id','exitoso=','justificación persistida','dos movimientos','se crea sesión','sin débito','ninguna sesión','no sesión']
def separar(expected):
 partes=[p.strip() for p in re.split(r';\s*',expected) if p.strip()]
 resp,bd=[],[]
 for p in partes:
  (bd if any(k.lower() in p.lower() for k in DB) and not p.startswith(('HTTP','Login HTTP','message=')) else resp).append(p)
 return resp,bd
def cuenta(x):
 for k in ('numeroCuenta','numeroCuentaOrigen','numeroCuentaDestino'):
  if k in x['data']:return x['data'][k]
 return 'AH000000000001'
def consulta(x):
 u=x['url'];d=x['data'];r=x['req']
 if r=='REQ-07':
  ev=x['title'].split()[-1]
  return f"SELECT count(*), bool_and(ip_address IS NOT NULL), max(user_agent), bool_and(exitoso) FROM seguridad.eventos_seguridad WHERE evento='{ev}' AND created_at>=<inicio>;"
 if '/cajas/' in u:return f"SELECT estado, fondo_inicial, total_depositos, total_retiros, efectivo_contado, diferencia, justificacion, hora_cierre FROM cajas.sesiones_caja WHERE cajero_id={EMP} AND fecha=CURRENT_DATE ORDER BY hora_apertura DESC;"
 if 'external/ach/transferencias' in u:
  return f"SELECT c.saldo, (SELECT count(*) FROM ach.transferencias_entrantes t WHERE t.codigo_confirmacion LIKE '{d.get('codigo_confirmacion','')}%'), (SELECT count(*) FROM transacciones.movimientos m WHERE m.cuenta_id=c.id AND m.tipo='ACH_IN' AND m.created_at>=<inicio>) FROM cuentas.cuentas c WHERE c.numero_cuenta='{d.get('numeroCuentaDestino','AH000000000001')}';"
 if '/ach/transferencias/enviar' in u:return "SELECT estado, mensaje_error, codigo_confirmacion FROM ach.transferencias WHERE fecha_creacion>=<inicio>; SELECT saldo, monto_retirado_hoy FROM cuentas.cuentas WHERE numero_cuenta='AH000000000001'; y GET http://localhost:18081/stats."
 if any(k in u for k in ['/transacciones/deposito','/transacciones/retiro','/transacciones/transferencia','/portal/transferencias']):
  return "SELECT c.numero_cuenta, c.saldo, c.saldo_disponible, c.monto_retirado_hoy, (SELECT count(*) FROM transacciones.movimientos m WHERE m.cuenta_id=c.id AND m.created_at>=<inicio>) AS movs, (SELECT count(*) FROM contabilidad.asientos a JOIN transacciones.movimientos m ON m.id=a.movimiento_id WHERE m.cuenta_id=c.id AND a.created_at>=<inicio>) AS asientos FROM cuentas.cuentas c WHERE c.numero_cuenta IN ('AH000000000001','MO000000000002','AH000000000003') ORDER BY 1;"
 if '/api/cuentas' in u:return f"SELECT numero_cuenta, tipo_cuenta, estado, saldo_minimo, limite_retiro_diario FROM cuentas.cuentas WHERE cliente_id='{d.get('clienteId')}' AND created_at>=<inicio>; y SELECT codigo, saldo_minimo, limite_retiro_diario FROM cuentas.tipos_cuenta WHERE codigo='{d.get('tipoCuenta')}';"
 if 'cambiar-password' in u or 'restablecer-password' in u:return "SELECT password_hash=<hash_previo> AS sin_cambio, (SELECT count(*) FROM seguridad.sesiones s WHERE s.usuario_id=u.id AND s.estado) AS sesiones_activas FROM seguridad.usuarios u WHERE username='qa_bloqueo';"
 if 'external/auth/login' in u:return f"SELECT count(*) FROM seguridad.sesiones s JOIN seguridad.usuarios u ON u.id=s.usuario_id WHERE u.email='{d.get('email')}' AND s.estado AND s.fecha_inicio>=<inicio>;"
 if '/auth/login' in u:
  usr=d.get('username') or 'qa_cajero'
  return f"SELECT bloqueado, bloqueado_hasta, intentos_fallidos, (SELECT count(*) FROM seguridad.sesiones s WHERE s.usuario_id=u.id AND s.estado AND s.fecha_inicio>=<inicio>) AS sesiones_nuevas FROM seguridad.usuarios u WHERE username='{usr}';"
 return ''
def preparacion(x):
 u=x['url'];d=x['data'];r=x['req'];pre=[]
 if r=='REQ-07':
  ev=x['title'].split()[-1]
  pre.append(reset_user('qa_bloqueo')+" También UPDATE seguridad.usuarios SET intentos_fallidos=0 WHERE username='qa_externo';")
  if 'transferencias' in u:pre.append(RESTAURAR)
  if ev=='ACH_PUBLIC_TRX_IN_ERR':pre.append("En psql-QA (solo QA) forzar el desbordamiento: UPDATE cuentas.cuentas SET saldo=9999999999999999.99, saldo_disponible=9999999999999999.99 WHERE numero_cuenta='AH000000000001';")
  if ev=='ACH_PUBLIC_TRX_IN_DUP':pre.append(f'Enviar una primera vez POST {u} con el mismo cuerpo del paso de ejecución y verificar HTTP 201 (crea el código).')
  if ev in ('USUARIO_DESBLOQUEADO',):pre.append("En psql-QA: UPDATE seguridad.usuarios SET bloqueado=true WHERE username='qa_bloqueo';")
  if ev=='LOGOUT':pre.append(login('qa_bloqueo').replace('guardar token como <token>','guardar token como <token> y refreshToken como {{refreshTokenBloqueo}}'))
  if ev=='USUARIO_CREADO':pre.append("En psql-QA confirmar que no existe: SELECT count(*) FROM seguridad.usuarios WHERE username='qa_evento_nuevo'; esperar 0.")
  if ev in ('ASIGNACION_ROL','ASIGNACION_PERMISO'):pre.append("Resolver el UUID: SELECT id FROM seguridad.roles WHERE codigo='CAJERO'; o SELECT id FROM seguridad.permisos WHERE codigo='transacciones.depositos.crear'; y asignarlo a la variable indicada en el cuerpo.")
  pre.append(INICIO+f" Conteo previo: SELECT count(*) FROM seguridad.eventos_seguridad WHERE evento='{ev}';")
  return pre
 if '/auth/login' in u and 'external' not in u:
  usr=d.get('username') or ('qa_cliente_a' if 'email' in d else 'qa_cajero')
  if r=='REQ-02':
   if 'intentos_previos' in d:pre.append(f"En psql-QA: UPDATE seguridad.usuarios SET estado=true, bloqueado=false, bloqueado_hasta=NULL, intentos_fallidos={d['intentos_previos']} WHERE username='qa_bloqueo';")
   elif x['id']=='TC-REQ02-003':pre.append("En psql-QA: UPDATE seguridad.usuarios SET bloqueado=true, intentos_fallidos=5, bloqueado_hasta=now()+interval '30 minutes' WHERE username='qa_bloqueo';")
   else:pre.append("En psql-QA: UPDATE seguridad.usuarios SET bloqueado=true, intentos_fallidos=5, bloqueado_hasta=now()+interval '5 minutes' WHERE username='qa_bloqueo'; (vence después de la petición).")
  else:pre.append(reset_user(usr,False))
  pre.append(INICIO);return pre
 if 'external/auth/login' in u:
  pre.append("En psql-QA confirmar el perfil: SELECT u.estado, r.codigo FROM seguridad.usuarios u LEFT JOIN seguridad.usuarios_roles ur ON ur.usuario_id=u.id LEFT JOIN seguridad.roles r ON r.id=ur.rol_id WHERE u.email='"+d.get('email','')+"';");pre.append(INICIO);return pre
 if 'cambiar-password' in u:
  pre.append(reset_user('qa_bloqueo')+" DELETE FROM seguridad.password_historial WHERE usuario_id="+UID.format(u='qa_bloqueo')+';')
  if 'Anterior8*' in json.dumps(d):pre.append("En psql-QA sembrar el historial: INSERT INTO seguridad.password_historial(id,usuario_id,password_hash,created_at) VALUES (gen_random_uuid(),"+UID.format(u='qa_bloqueo')+",crypt('Anterior8*', gen_salt('bf',10)),now());")
  pre.append("Guardar <hash_previo>: SELECT password_hash FROM seguridad.usuarios WHERE username='qa_bloqueo';");return pre
 if 'restablecer-password' in u:
  pre.append(reset_user('qa_bloqueo'));pre.append(f'Solicitar token con POST {I}/api/auth/solicitar-recuperacion-password y cuerpo {{"identificador":"qa_bloqueo@example.invalid"}}; guardar tokenRecuperacion.')
  if 'fecha_expiracion' in d:pre.append("En psql-QA vencer el token: UPDATE seguridad.tokens_recuperacion SET fecha_expiracion=now()-interval '1 second' WHERE usuario_id="+UID.format(u='qa_bloqueo')+" AND usado=false;")
  pre.append("Guardar <hash_previo>: SELECT password_hash FROM seguridad.usuarios WHERE username='qa_bloqueo';");return pre
 if '/cajas/abrir' in u:
  pre.append(CERRAR_CAJAS)
  pre.append(login('qa_cajero'))
  if x['id']=='TC-REQ08-005':pre.append(ABRIR_CAJA)
  pre.append(INICIO);return pre
 if '/cajas/cerrar' in u:return [CERRAR_CAJAS,login('qa_cajero'),ABRIR_CAJA+' Confirmar total_depositos=0 y total_retiros=0 (sin operaciones en la caja).']
 if x['id']=='TC-REQ08-004':return [RESTAURAR,CERRAR_CAJAS,INICIO]
 if any(k in u for k in ['/transacciones/deposito','/transacciones/retiro','/transacciones/transferencia']):
  pre.append(RESTAURAR)
  extra={'TC-REQ11-004':"UPDATE cuentas.cuentas SET limite_retiro_diario=NULL WHERE numero_cuenta='AH000000000001';",'TC-REQ11-005':"UPDATE cuentas.cuentas SET limite_retiro_diario=NULL WHERE numero_cuenta='AH000000000001';",'TC-REQ11-006':"UPDATE cuentas.cuentas SET limite_retiro_diario=NULL WHERE numero_cuenta='AH000000000001';",'TC-REQ11-007':"UPDATE cuentas.cuentas SET saldo_disponible=200.00, saldo_retenido=800.00 WHERE numero_cuenta='AH000000000001';",'TC-REQ21-002':"UPDATE contabilidad.plan_cuentas SET activo=false WHERE codigo='1101';"}.get(x['id'])
  if extra:pre.append('En psql-QA ajustar la precondición: '+extra)
  if d.get('perfil','qa_cajero')=='qa_cajero':pre+=[CERRAR_CAJAS,login('qa_cajero'),ABRIR_CAJA]
  pre.append(INICIO);return pre
 if '/portal/transferencias' in u or 'external/ach/transferencias' in u:
  pre.append(RESTAURAR)
  if 'codigo_confirmacion' in d:pre.append(f"En psql-QA confirmar código nuevo: SELECT count(*) FROM ach.transferencias_entrantes WHERE codigo_confirmacion LIKE '{d['codigo_confirmacion']}%'; esperar 0.")
  pre.append(INICIO);return pre
 if '/ach/transferencias/enviar' in u:return [RESTAURAR,'Ejecutar python3 scripts/configurar_banco_mock.py y POST http://localhost:18081/reset; registrar GET http://localhost:18081/stats.',INICIO]
 if '/api/cuentas' in u and x['method']=='POST':return [f"En psql-QA confirmar el estado del cliente: SELECT estado FROM crm.clientes WHERE id='{d.get('clienteId')}';",INICIO]
 if '/historial/' in u:return ['Ejecutar python3 scripts/preparar_escenario.py --paginacion (la cuenta AH000000000001 queda con 120 movimientos).',f"En psql-QA confirmar: SELECT count(*) FROM transacciones.movimientos WHERE cuenta_id='{d.get('cuentaId')}'; esperar 120."]
 return []
def verificacion_bd(x,bd):
 q=consulta(x)
 if '/historial/' in x['url']:
  t=x['data'];size=t['tamano'];size=20 if size<=0 else min(size,100);page=max(t['pagina'],1)
  return [f"En psql-QA comparar los IDs devueltos con: SELECT id FROM transacciones.movimientos WHERE cuenta_id='{t['cuentaId']}' ORDER BY created_at DESC LIMIT {size} OFFSET {(page-1)*size}; deben coincidir en orden."]
 if x['url'].endswith('/api/portal/cuentas'):return ["En psql-QA comparar con: SELECT numero_cuenta FROM cuentas.cuentas WHERE cliente_id=(SELECT cliente_id FROM cuentas.cuentas WHERE numero_cuenta='AH000000000001') ORDER BY 1; la respuesta debe contener exactamente esas cuentas."]
 if '/portal/movimientos' in x['url']:return [f"En psql-QA confirmar que la cuenta es ajena: SELECT cliente_id FROM cuentas.cuentas WHERE id='{x['data'].get('cuentaId')}'; debe diferir del cliente de qa_cliente_a."]
 if not q:return []
 if bd:return [f'En psql-QA ejecutar: {q} Comprobar: '+'; '.join(bd).rstrip('.')+'.']
 return [f'En psql-QA ejecutar: {q} Comprobar que no hay registros nuevos ni cambios respecto al estado del paso 1.']
def restauracion(x):
 u=x['url'];r=x['req']
 if x['method']=='GET' or 'OPTIONS'==x['method']:return []
 if x['id']=='TC-REQ21-002':return ["Restaurar: UPDATE contabilidad.plan_cuentas SET activo=true WHERE codigo='1101'; y ejecutar python3 scripts/preparar_escenario.py."]
 if any(k in u for k in ['/transacciones/','/portal/transferencias','external/ach/transferencias','/ach/transferencias/enviar']):return ['Restaurar la línea base con python3 scripts/preparar_escenario.py.']
 if r in ('REQ-02','REQ-03','REQ-04') or (r=='REQ-07' and 'qa_bloqueo' in json.dumps(x['data'])+u) or '/seguridad/usuarios/' in u:return ['Restaurar: '+reset_user('qa_bloqueo')[len('En psql-QA restaurar el usuario: '):]]
 if r=='REQ-01' and 'Incorrecta' in json.dumps(x['data']):return ['Restaurar: '+reset_user('qa_cajero',False)[len('En psql-QA restaurar el usuario: '):]]
 if '/cajas/' in u:return [CERRAR_CAJAS.replace('En psql-QA cerrar','Al terminar cerrar')]
 return []
def especificar(C):
 for x in C:
  if x['id'] in DETALLE:x['steps']=DETALLE[x['id']](x);continue
  if not x['steps'] or not x['steps'][0].startswith(GENERIC):continue
  u=perfil(x);resp,bd=separar(x['expected'])
  pasos=preparacion(x)
  if u and not any(p.startswith('Autenticar') for p in pasos):pasos.append(login(u))
  pasos.append(peticion(x,u))
  pasos.append('Verificar en la respuesta: '+'; '.join(resp).rstrip('.')+'.')
  pasos+=verificacion_bd(x,bd)
  pasos+=restauracion(x)
  x['steps']=pasos
 return C

# Casos compuestos con secuencias propias: pasos explícitos con endpoints, cuerpos y consultas exactas.
LI=f'POST {I}/api/auth/login';REC=f'POST {I}/api/auth/solicitar-recuperacion-password';RES=f'POST {I}/api/auth/restablecer-password'
SALDO_EXT="SELECT saldo FROM cuentas.cuentas WHERE numero_cuenta='AH000000000001';"
ACH_SQL="SELECT count(*), sum(monto) FROM ach.transferencias_entrantes WHERE codigo_confirmacion LIKE '{c}%'; y SELECT count(*) FROM transacciones.movimientos m JOIN cuentas.cuentas c ON c.id=m.cuenta_id WHERE c.numero_cuenta='AH000000000001' AND m.tipo='ACH_IN' AND m.created_at>=<inicio>;"
def _ach(x):return cuerpo(x)
def _salida(x,mock):
 return [RESTAURAR,'Ejecutar python3 scripts/configurar_banco_mock.py; enviar POST http://localhost:18081/reset y registrar GET http://localhost:18081/stats (intentos=0).',login('qa_cliente_a'),INICIO,
  f"Enviar POST {x['url']} con Content-Type: application/json, Authorization: Bearer <token> y cuerpo {cuerpo(x)}; medir el tiempo con reloj monotónico.",
  'Verificar en la respuesta: '+'; '.join(separar(x['expected'])[0]).rstrip('.')+'.',
  "En psql-QA ejecutar: SELECT estado, mensaje_error, codigo_confirmacion FROM ach.transferencias WHERE fecha_creacion>=<inicio>; y "+SALDO_EXT+" Consultar GET http://localhost:18081/stats"+(' después de esperar 30 s adicionales' if mock=='timeout' else '')+'.',
  'Comprobar: '+'; '.join(separar(x['expected'])[1]).rstrip('.')+'.','Restaurar la línea base con python3 scripts/preparar_escenario.py.']
def _ui(vp,tema,completo=True):
 w,h=vp.split('x')
 s=[f'Abrir Google Chrome en http://localhost:13000/login; en DevTools > Toggle device toolbar fijar el viewport en {w}x{h}.',
  f'Seleccionar el tema {tema} con el botón de tema (title "Cambiar a modo {tema}"); verificar en la consola localStorage.getItem("nexus-theme-preference") = "{"dark" if tema=="oscuro" else "light"}".',
  'En la consola ejecutar document.documentElement.scrollWidth <= window.innerWidth; esperar true. Verificar que los campos de usuario, contraseña y el botón de ingreso están completos dentro del viewport.',
  'Iniciar sesión con qa_cajero / E2Qa2026*; en el dashboard abrir el menú principal (en 390 px, el menú móvil) y navegar a Clientes y Cuentas.',
  'En cada pantalla repetir la comprobación de scrollWidth, verificar que ningún control se superpone y que el tema seleccionado se mantiene; guardar captura de login y dashboard.']
 return s
DETALLE={
 'TC-REQ02-004':lambda x:[reset_user('qa_bloqueo'),f'Enviar 5 veces {LI} con cuerpo {{"username":"qa_bloqueo","password":"Erronea9*"}}; la quinta respuesta informa el bloqueo (HTTP 401).',"En psql-QA verificar: SELECT bloqueado, bloqueado_hasta-now() FROM seguridad.usuarios WHERE username='qa_bloqueo'; esperar bloqueado=true e intervalo de 30 min ± 2 s.","En psql-QA (solo QA) adelantar el vencimiento: UPDATE seguridad.usuarios SET bloqueado_hasta=now()-interval '1 second' WHERE username='qa_bloqueo';",f'Enviar {LI} con cuerpo {{"username":"qa_bloqueo","password":"E2Qa2026*"}}.','Verificar en la respuesta: HTTP 200; token y refreshToken no vacíos.',"En psql-QA ejecutar: SELECT bloqueado, bloqueado_hasta, intentos_fallidos FROM seguridad.usuarios WHERE username='qa_bloqueo'; esperar false, NULL y 0.",'Restaurar: '+reset_user('qa_bloqueo')[33:]],
 'TC-REQ04-001':lambda x:[reset_user('qa_bloqueo'),f'Enviar {REC} con cuerpo {{"identificador":"qa_bloqueo@example.invalid"}}; verificar HTTP 200 y guardar tokenRecuperacion como <tokenRecuperacion> (sin registrarlo en evidencia).',f'Enviar {RES} con cuerpo {{"token":"<tokenRecuperacion>","passwordNueva":"Recupera9*"}}; verificar HTTP 200.',f'Enviar de nuevo {RES} con el mismo cuerpo; verificar HTTP 400 y message="Token invalido o expirado.".',"En psql-QA ejecutar: SELECT usado FROM seguridad.tokens_recuperacion WHERE usuario_id="+UID.format(u='qa_bloqueo')+" ORDER BY created_at DESC LIMIT 1; esperar true. Comprobar con un login usando Recupera9* (HTTP 200) que solo hubo una actualización.",'Restaurar: '+reset_user('qa_bloqueo')[33:]],
 'TC-REQ04-003':lambda x:[reset_user('qa_bloqueo'),INICIO,f'Enviar {REC} sin Authorization y cuerpo {{"identificador":"qa_bloqueo@example.invalid"}}.','Verificar en la respuesta: HTTP 200; tokenRecuperacion no vacío; expiraEn entre <inicio>+2 h y <fin>+2 h (tolerancia 2 s).',"En psql-QA ejecutar: SELECT token_hash<>'<tokenRecuperacion>' AS hash_distinto, usado, fecha_expiracion FROM seguridad.tokens_recuperacion WHERE usuario_id="+UID.format(u='qa_bloqueo')+" ORDER BY created_at DESC LIMIT 1; esperar hash_distinto=true y usado=false.",f'Enviar {RES} con {{"token":"<tokenRecuperacion>","passwordNueva":"Recupera9*"}}; verificar HTTP 200 (el segundo uso se cubre en TC-REQ04-001).','Restaurar: '+reset_user('qa_bloqueo')[33:]],
 'TC-REQ05-001':lambda x:[reset_user('qa_cajero',False),f'Enviar {LI} con cuerpo {{"username":"qa_cajero","password":"E2Qa2026*"}}; guardar refreshToken como R1.',f'Enviar POST {I}/api/auth/refresh-token con cuerpo {{"refreshToken":"<R1>"}}; verificar HTTP 200 y guardar el nuevo refreshToken como R2.','Comprobar que R2 es distinto de R1.',f'Enviar POST {I}/api/auth/refresh-token con cuerpo {{"refreshToken":"<R1>"}}.','Verificar en la respuesta: HTTP 401; message="Refresh token invalido o expirado.". No registrar R1 ni R2 en la evidencia.'],
 'TC-REQ05-002':lambda x:[reset_user('qa_bloqueo')+" DELETE FROM seguridad.password_historial WHERE usuario_id="+UID.format(u='qa_bloqueo')+';',f'Enviar dos veces {LI} con cuerpo {{"username":"qa_bloqueo","password":"E2Qa2026*"}}; guardar los JWT como J1 y J2.',"En psql-QA verificar: SELECT count(*) FROM seguridad.sesiones WHERE usuario_id="+UID.format(u='qa_bloqueo')+" AND estado; esperar 2.",f'Enviar POST {I}/api/auth/cambiar-password con Authorization: Bearer <J1> y cuerpo {{"passwordActual":"E2Qa2026*","passwordNueva":"SesionNueva9*"}}; verificar HTTP 200.',"En psql-QA repetir la consulta de sesiones activas; esperar 0.",f'Enviar GET {I}/api/auth/me con Authorization: Bearer <J1> y luego con <J2>; verificar HTTP 401 en ambos.','Restaurar: '+reset_user('qa_bloqueo')[33:]],
 'TC-REQ07-003':lambda x:['Desde la raíz del repositorio ejecutar: grep -c "public const string" Backend/BancoERP.Domain/Constants/EventosSeguridad.cs; esperar 20.','Listar los usos: grep -rn "EventosSeguridad\\." Backend/BancoERP.Application/Services; cada una de las 20 constantes debe aparecer al menos una vez.','Abrir 03_Evidencias_y_MockData/Catalogo_Eventos_QA.json y comprobar que eventos_vigentes=20, que los 20 códigos son únicos y que cada uno tiene un ID de caso existente y al menos un punto de emisión.','Ejecutar python3 scripts/validar.py y verificar el control "20 eventos únicos con casos y puntos de emisión" = OK.'],
 'TC-REQ12-003':lambda x:[RESTAURAR,CERRAR_CAJAS,login('qa_cajero'),ABRIR_CAJA,INICIO,f'Enviar POST {I}/api/transacciones/transferencia con Authorization: Bearer <token> y cuerpo {{"numeroCuentaOrigen":"AH000000000001","numeroCuentaDestino":"MO000000000002","monto":500.01,"concepto":"E2 QA"}}.','Verificar en la respuesta: HTTP 422; message="La transferencia supera el limite diario de la cuenta origen.".',"En psql-QA ejecutar: SELECT numero_cuenta, saldo, monto_retirado_hoy FROM cuentas.cuentas WHERE numero_cuenta IN ('AH000000000001','MO000000000002'); esperar 1000.00/0.00 y 500.00; sin movimientos desde <inicio>.",RESTAURAR,login('qa_cliente_a'),f'Enviar POST {I}/api/portal/transferencias con el mismo cuerpo y el token de qa_cliente_a; verificar el mismo HTTP 422, mensaje y ausencia de efectos con la consulta anterior. Un HTTP 200 por ventanilla se registra como defecto H-03.'],
 'TC-REQ17-002':lambda x:[login('qa_admin'),f'Enviar POST {I}/api/ach/bancos con Authorization: Bearer <token> y cuerpo {{"nombre":"Banco QA Mock","codigo":"QA-MOCK","descripcion":"Fixture QA","activo":true,"apiBaseUrl":"http://mock-bank:8081","apiEndpoint":"/success/transferencias","httpMethod":"POST","authLoginEndpoint":null,"authEmail":"qa@example.invalid","authPassword":"SoloMock9*","headers":{{}},"estructuraJsonFormulario":{{}},"estructuraJsonPayload":{{}},"lookupCuentaEndpoint":null,"lookupCuentasDisponiblesEndpoint":null}}; guardar el id.',f'Enviar GET {I}/api/ach/bancos y GET {I}/api/ach/bancos/<id> con el mismo token; verificar HTTP 200 y que ninguna respuesta contiene authPassword, auth_password ni el texto SoloMock9*.',"En Mongo QA ejecutar: docker compose -f docker-compose.qa.yml exec -T mongo mongosh --quiet --eval \"db.getSiblingDB('bancoerp_e2_qa').ach_banks_configurations.findOne({codigo:'QA-MOCK'},{auth_password:1})\"; el valor no debe ser SoloMock9* ni su base64.",'Revisar docker-compose.qa.yml y appsettings: la clave de cifrado debe provenir de una variable de entorno externa a la base y al repositorio. Si se almacena texto plano, registrar defecto H-05.'],
 'TC-REQ18-001':lambda x:_salida(x,'timeout'),
 'TC-REQ18-002':lambda x:_salida(x,'duplicate'),
 'TC-REQ19-002':lambda x:[RESTAURAR,login('qa_externo'),INICIO,f"Enviar POST {x['url']} con Authorization: Bearer <token> y cuerpo {_ach(x)} (en Postman con sufijo -{{{{runId}}}}); verificar HTTP 201.",'Enviar exactamente la misma petición una segunda vez.','Verificar en la segunda respuesta: HTTP 409; message="La transferencia ya fue procesada."; errors.codigo_confirmacion=["El codigo de confirmacion ya existe."].','En psql-QA ejecutar: '+SALDO_EXT+' y '+ACH_SQL.format(c=x['data']['codigo_confirmacion'])+' Esperar saldo=1100.00, una transferencia de 100.00 y un ACH_IN.','Restaurar la línea base con python3 scripts/preparar_escenario.py.'],
 'TC-REQ19-003':lambda x:[RESTAURAR,login('qa_externo'),INICIO,f"Lanzar 5 POST simultáneos a {x['url']} con Authorization: Bearer <token> y el cuerpo {_ach(x)}, por ejemplo con Promise.all en Node.js o 5 instancias de curl en segundo plano.",'Registrar los 5 códigos HTTP; verificar exactamente un 201 y cuatro 409.','En psql-QA ejecutar: '+SALDO_EXT+' y '+ACH_SQL.format(c=x['data']['codigo_confirmacion'])+" Esperar saldo=1100.00, una transferencia, un ACH_IN y asientos DB=CR=100.00.",'Restaurar la línea base con python3 scripts/preparar_escenario.py.'],
 'TC-REQ22-001':lambda x:[f"Enviar OPTIONS {x['url']} con encabezados Origin: http://localhost:13000 y Access-Control-Request-Method: GET (sin Authorization).",'Registrar el código HTTP y los encabezados Access-Control-*.','Verificar HTTP 204 y Access-Control-Allow-Origin=http://localhost:13000.'],
 'TC-REQ22-002':lambda x:[f"Enviar OPTIONS {x['url']} con encabezados Origin: http://origen-no-permitido.invalid y Access-Control-Request-Method: GET (sin Authorization).",'Registrar el código HTTP y los encabezados Access-Control-*.','Verificar HTTP 204 y que no existe Access-Control-Allow-Origin; el navegador bloquea la lectura (CORS no exige 403 en el servidor).'],
 'TC-REQ23-001':lambda x:['Desde la raíz del repositorio ejecutar en orden: python3 ENTREGA_02_DISENO_E_IMPLEMENTACION_QA/03_Evidencias_y_MockData/scripts/preparar.py, disenar.py y coleccion.py.','Ejecutar docker compose -f ENTREGA_02_DISENO_E_IMPLEMENTACION_QA/03_Evidencias_y_MockData/docker-compose.qa.yml up -d y esperar a que postgres reporte (healthy) en docker compose ps.','Ejecutar python3 …/scripts/configurar_banco_mock.py y python3 …/scripts/readiness.py.','Verificar en Readiness_Resultados.json: dictamen APTO CON RESTRICCIONES, RD-01 con 6 servicios running, RD-02 a RD-04 HTTP 200 y RD-05 con usuarios=8, clientes=1000, cuentas=2000, movimientos=10000.'],
 'TC-REQ23-002':lambda x:['Desde 03_Evidencias_y_MockData ejecutar: python3 scripts/compuerta_vulnerabilidades.py Vulnerabilidades_QA_Alta.json; echo "exit=$?".','Verificar en la salida JSON: decision="RECHAZADO", altas=1, criticas=0; y exit=1.','Revisar .github/workflows/ci.yml: si no invoca la compuerta, registrar defecto H-09 (la liberación no queda bloqueada en CI).'],
 'TC-REQ23-003':lambda x:['Desde 03_Evidencias_y_MockData ejecutar: python3 scripts/compuerta_vulnerabilidades.py Vulnerabilidades_QA_Critica.json; echo "exit=$?".','Verificar en la salida JSON: decision="RECHAZADO", criticas=1; y exit=1.','Guardar la salida como evidencia local.'],
 'TC-REQ23-004':lambda x:['Desde 03_Evidencias_y_MockData ejecutar: python3 scripts/compuerta_vulnerabilidades.py Vulnerabilidades_QA_Media.json; echo "exit=$?".','Verificar en la salida JSON: decision="APROBADO_CON_SEGUIMIENTO", medias=1; y exit=0.','Guardar la salida como evidencia local.'],
 'TC-REQ23-005':lambda x:['Desde 03_Evidencias_y_MockData ejecutar: python3 scripts/compuerta_vulnerabilidades.py Vulnerabilidades_QA_Baja.json; echo "exit=$?".','Verificar en la salida JSON: decision="APROBADO", bajas=1; y exit=0.','Guardar la salida como evidencia local.'],
 'TC-REQ24-001':lambda x:_ui('1366x768','claro'),
 'TC-REQ24-002':lambda x:_ui('390x844','oscuro'),
 'TC-REQ24-003':lambda x:_ui('1366x768','oscuro'),
 'TC-REQ24-004':lambda x:_ui('390x844','claro'),
}
