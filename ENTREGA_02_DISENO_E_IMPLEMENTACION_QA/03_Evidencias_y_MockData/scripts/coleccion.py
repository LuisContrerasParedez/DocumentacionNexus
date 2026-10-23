from pathlib import Path
import json,re,uuid
B=Path(__file__).resolve().parents[1];cases=json.loads((B/'Casos_Diseno.json').read_text())
items=[]
setup=[]
for title,url,body,key in [('Preparar token interno','{{baseInterna}}/api/auth/login',{'username':'qa_cajero','password':'{{qaPassword}}'},'token'),('Preparar token externo','{{basePublica}}/api/external/auth/login',{'email':'qa_externo@example.invalid','password':'{{qaPassword}}'},'accessToken')]:
 setup.append(dict(name=title,request=dict(method='POST',header=[{'key':'Content-Type','value':'application/json'}],url=url,auth={'type':'noauth'},body=dict(mode='raw',raw=json.dumps(body,indent=2))),event=[dict(listen='test',script=dict(type='text/javascript',exec=['pm.test("Login de preparación HTTP 200",()=>pm.response.to.have.status(200));',f'const j=pm.response.json(); if(j.{key}) pm.environment.set("{key}",j.{key});'+(' if(j.refreshToken) pm.environment.set("refreshTokenCajero",j.refreshToken);' if key=='token' else '')]))]))
# Logins adicionales guardan variables separadas por perfil.
for profile in ['admin','cliente_a','cliente_b','bloqueo','sin_permiso']:
 setup.append(dict(name='Preparar token '+profile,request=dict(method='POST',url='{{baseInterna}}/api/auth/login',auth={'type':'noauth'},header=[dict(key='Content-Type',value='application/json')],body=dict(mode='raw',raw=json.dumps({'username':'qa_'+profile,'password':'{{qaPassword}}'}))),event=[dict(listen='test',script=dict(type='text/javascript',exec=['pm.test("Login HTTP 200",()=>pm.response.to.have.status(200));',f'const j=pm.response.json(); if(j.token) pm.environment.set("token_{profile}",j.token);'+(' if(j.refreshToken) pm.environment.set("refreshTokenBloqueo",j.refreshToken);' if profile=='bloqueo' else '')]))]))
for resource,code,var in [('roles','CAJERO','rolCajeroId'),('permisos','transacciones.depositos.crear','permisoDepositoId')]:
 setup.append(dict(name='Resolver '+var,request=dict(method='GET',url='{{baseInterna}}/api/seguridad/'+resource,auth=dict(type='bearer',bearer=[dict(key='token',value='{{token_admin}}',type='string')])),event=[dict(listen='test',script=dict(type='text/javascript',exec=['pm.test("Catálogo HTTP 200",()=>pm.response.to.have.status(200));',f'const rows=pm.response.json(); const row=rows.find(x=>x.codigo==="{code}"); if(row) pm.environment.set("{var}",row.id);']))]))
setup.append(dict(name='Solicitar token de recuperación QA',request=dict(method='POST',url='{{baseInterna}}/api/auth/solicitar-recuperacion-password',auth={'type':'noauth'},header=[dict(key='Content-Type',value='application/json')],body=dict(mode='raw',raw=json.dumps({'identificador':'qa_bloqueo@example.invalid'}))),event=[dict(listen='test',script=dict(type='text/javascript',exec=['pm.test("Recuperación HTTP 200",()=>pm.response.to.have.status(200));','const j=pm.response.json(); if(j.tokenRecuperacion) pm.environment.set("tokenRecuperacion",j.tokenRecuperacion);']))]))
# Guard impide consumir URLs ajenas al QA local declarado.
guard=['for (const k of ["baseInterna","basePublica"]) {','  const v=pm.variables.get(k);','  if (!["http://localhost:15141","http://localhost:15254"].includes(v)) {','    pm.execution.skipRequest(); throw new Error("Solo URLs del QA E2 aislado");','  }','}']
meta={'perfil','intentos_previos','Authorization','User-Agent','concurrencia','maestro_inactivo','fecha_expiracion'}
for req in sorted({x['req'] for x in cases}):
 rows=[]
 for c in cases:
  if c['req']!=req or not c['url'] or c['blocker'] or ':13000' in c['url']:continue
  url=c['url'].replace('http://localhost:15141','{{baseInterna}}').replace('http://localhost:15254','{{basePublica}}')
  data={k:v for k,v in c['data'].items() if k not in meta}
  if c['method']=='GET':data={}
  external='basePublica' in url
  profile=c['data'].get('perfil')
  if not profile and c['req'] in ['REQ-03','REQ-04']:profile='qa_bloqueo'
  auth='accessToken' if external else ('token_'+profile[3:] if profile and profile not in ['qa_cajero','qa_externo'] else 'token')
  request=dict(method=c['method'],url=url,description='\n'.join([c['id']+' → '+c['req']+' → '+c['condition'],'Técnica: '+c['technique'],'Precondiciones: '+c['preconditions'],'\nPasos:']+[f'{i}. {s}' for i,s in enumerate(c['steps'],1)]+['\nResultado esperado: '+c['expected'],'\nLa petición es una plantilla individual. Los casos compuestos requieren todos los pasos, reposición de fixtures y verificaciones SQL; el Runner no automatiza esa secuencia.']),header=[],auth=dict(type='bearer',bearer=[dict(key='token',value='{{'+auth+'}}',type='string')]))
  if c['method'] in ['POST','PUT','PATCH']:
   request['header']=[dict(key='Content-Type',value='application/json')]
   if c['req']=='REQ-19' or (c['req']=='REQ-07' and 'codigo_confirmacion' in data):
    data['codigo_confirmacion']=data.get('codigo_confirmacion',c['id'])+'-{{runId}}'
   # Importes se conservan como strings para no perder precisión en límites numeric(18,2).
   raw=json.dumps(data,ensure_ascii=False,indent=2)
   if not external:
    raw=re.sub(r'(\"(?:monto|fondoInicial|efectivoContado)\"\s*:\s*)\"(-?\d+(?:\.\d+)?)\"',r'\1\2',raw)
   if c['req']=='REQ-07':request['header'].append(dict(key='User-Agent',value=c['data'].get('User-Agent','E2-QA/2.0')))
   request['body']=dict(mode='raw',raw=raw,options={'raw':{'language':'json'}})
  if c['method']=='OPTIONS':request['header']=[dict(key=k,value=str(v)) for k,v in c['data'].items()];request['auth']={'type':'noauth'}
  if c['req']=='REQ-07' and not any(h['key']=='User-Agent' for h in request['header']):request['header'].append(dict(key='User-Agent',value=c['data'].get('User-Agent','E2-QA/2.0')))
  if c['data'].get('Authorization')=='ausente' or '/auth/login' in url:request['auth']={'type':'noauth'}
  expect=re.match(r'HTTP (\d+);',c['expected']);events=[]
  if expect:events=[dict(listen='test',script=dict(type='text/javascript',exec=[f'pm.test("{c["id"]}: HTTP {expect[1]}",()=>pm.response.to.have.status({expect[1]}));','// Verificar además el cuerpo y los efectos detallados en la descripción y SQL.']))]
  rows.append(dict(name=c['id']+' · '+c['title'],request=request,event=events))
 if rows:items.append(dict(name=req,item=rows))
collection=dict(info=dict(_postman_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'bancoerp-e2-qa')),name='BancoERP · E2 Diseño e Implementación QA',schema='https://schema.getpostman.com/json/collection/v2.1.0/collection.json',description='Plantillas trazables del diseño. No equivale a suite ejecutada. Importar Environment QA; preparar perfil/fixture por caso. No usar Run All: los perfiles y estados varían.'),variable=[dict(key=k,value=v) for k,v in {'baseInterna':'http://localhost:15141','basePublica':'http://localhost:15254','qaPassword':'E2Qa2026*','token':'','accessToken':'','runId':'RUN-NUEVO','token_admin':'','token_cliente_a':'','token_cliente_b':'','token_bloqueo':'','token_sin_permiso':'','refreshTokenBloqueo':'','rolCajeroId':'','permisoDepositoId':'','tokenRecuperacion':'','refreshTokenCajero':''}.items()],event=[dict(listen='prerequest',script=dict(type='text/javascript',exec=guard))],item=[dict(name='00 · Preparación',item=setup)]+items)
(B/'Postman_Collection_QA.json').write_text(json.dumps(collection,ensure_ascii=False,indent=2))
env=dict(id=str(uuid.uuid5(uuid.NAMESPACE_URL,'bancoerp-e2-qa-env')),name='BancoERP-E2-QA-LOCAL',values=[dict(key=k,value=v,enabled=True,type='secret' if k in ['qaPassword','token','accessToken','refreshTokenBloqueo','tokenRecuperacion','refreshTokenCajero'] or k.startswith('token_') else 'default') for k,v in {'baseInterna':'http://localhost:15141','basePublica':'http://localhost:15254','qaPassword':'E2Qa2026*','token':'','accessToken':'','runId':'RUN-NUEVO','token_admin':'','token_cliente_a':'','token_cliente_b':'','token_bloqueo':'','token_sin_permiso':'','refreshTokenBloqueo':'','rolCajeroId':'','permisoDepositoId':'','tokenRecuperacion':'','refreshTokenCajero':''}.items()],_postman_variable_scope='environment')
(B/'Postman_Environment_QA.json').write_text(json.dumps(env,ensure_ascii=False,indent=2));print('Peticiones',sum(len(x['item']) for x in collection['item']))
