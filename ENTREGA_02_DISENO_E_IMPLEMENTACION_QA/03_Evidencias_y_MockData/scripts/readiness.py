from pathlib import Path
import json,subprocess,datetime,urllib.request,urllib.error,hashlib,re
B=Path(__file__).resolve().parents[1];OUT=B/'Capturas_Readiness_Entorno';OUT.mkdir(exist_ok=True)
CMD=['docker','compose','-f',str(B/'docker-compose.qa.yml')]
def run(args):return subprocess.run(args,text=True,capture_output=True,check=True).stdout.strip()
def sql(q):return run(CMD+['exec','-T','postgres','psql','-U','e2qa','-d','bancoerp_e2_qa','-Atc',q])
def http(url,body=None,headers=None,method=None):
 req=urllib.request.Request(url,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json',**(headers or {})},method=method)
 try:
  with urllib.request.urlopen(req,timeout=20) as r:return r.status,dict(r.headers),r.read().decode()
 except urllib.error.HTTPError as e:return e.code,dict(e.headers),e.read().decode()
def slim_json(text):
 try:return json.loads(text)
 except:return text[:100]
checks=[]
def check(id,title,ok,observed):checks.append(dict(id=id,title=title,estado='APTO' if ok else 'NO APTO',observado=observed))
services=run(CMD+['ps','--format','json']);objects=[json.loads(s) for s in services.splitlines() if s]
check('RD-01','Seis servicios QA activos',len(objects)==6 and all(x['State']=='running' for x in objects),[{k:x.get(k) for k in ['Service','Name','State','Health','Publishers']} for x in objects])
for id,url in [('RD-02','http://localhost:13000/login'),('RD-03','http://localhost:15141/swagger/v1/swagger.json'),('RD-04','http://localhost:15254/swagger/v1/swagger.json')]:
 s,h,b=http(url);obs={'url':url,'HTTP':s,'content_type':h.get('Content-Type'),'bytes':len(b)}
 if 'swagger.json' in url:
  j=slim_json(b);obs['rutas']=len(j.get('paths',{}));(OUT/('OpenAPI_Interna.json' if '15141' in url else 'OpenAPI_Publica.json')).write_text(json.dumps(j,ensure_ascii=False,indent=2))
 check(id,'Accesibilidad '+url,s==200,obs)
counts=json.loads(sql("SELECT json_build_object('database',current_database(),'usuarios',(SELECT count(*) FROM seguridad.usuarios),'clientes',(SELECT count(*) FROM crm.clientes),'cuentas',(SELECT count(*) FROM cuentas.cuentas),'movimientos',(SELECT count(*) FROM transacciones.movimientos),'plan_activo',(SELECT count(*) FROM contabilidad.plan_cuentas WHERE codigo IN ('1101','2101') AND activo))"))
check('RD-05','Base QA y datos masivos cargados',counts['database']=='bancoerp_e2_qa' and [counts[k] for k in ['usuarios','clientes','cuentas','movimientos']]==[8,1000,2000,10000] and counts['plan_activo']==2,counts)
private=[]
for service in ['internal-api','public-api']:
 cid=run(CMD+['ps','-q',service]);j=json.loads(run(['docker','inspect',cid]))[0];env=dict(v.split('=',1) for v in j['Config']['Env'] if '=' in v)
 conn=env.get('ConnectionStrings__DefaultConnection','');host=re.search(r'Host=([^;]+)',conn);db=re.search(r'Database=([^;]+)',conn)
 private.append(dict(service=service,postgres_host=host.group(1) if host else None,database=db.group(1) if db else None,environment=env.get('ASPNETCORE_ENVIRONMENT'),image_id=j['Image'],networks=list(j['NetworkSettings']['Networks']),volumes=[m['Name'] for m in j['Mounts'] if m['Type']=='volume'],binds=[dict(destino=m['Destination'],escritura=m['RW']) for m in j['Mounts'] if m['Type']=='bind']))
net=json.loads(run(['docker','network','inspect','bancoerp-e2-qa_default']))[0]
check('RD-06','Aislamiento: destinos internos, red y montajes',all(x['postgres_host']=='postgres' and x['database']=='bancoerp_e2_qa' and x['environment']=='QA' and all(not m['escritura'] for m in x['binds']) for x in private) and net['Name']=='bancoerp-e2-qa_default',dict(apis=private,red=net['Name'],internal=net['Internal'],egreso_produccion='Sin destinos productivos configurados; red/volúmenes exclusivos y puertos solo 127.0.0.1. Egreso no bloqueado por firewall.'))
check('RD-07','MongoDB QA accesible', 'ok' in run(CMD+['exec','-T','mongo','mongosh','--quiet','--eval',"JSON.stringify(db.getSiblingDB('bancoerp_e2_qa').runCommand({ping:1}))"]),dict(database='bancoerp_e2_qa',host='mongo',uso='Configuración ACH; cinco bancos simulados locales, sin bancos reales'))
for id,url,body,key in [('RD-08','http://localhost:15141/api/auth/login',{'username':'qa_cajero','password':'E2Qa2026*'},'token'),('RD-09','http://localhost:15254/api/external/auth/login',{'email':'qa_externo@example.invalid','password':'E2Qa2026*'},'accessToken')]:
 s,h,b=http(url,body);j=slim_json(b);ok=s==200 and bool(j.get(key));check(id,'Login de preparación '+('interno' if key=='token' else 'externo'),ok,dict(HTTP=s,token_presente=bool(j.get(key)),token='[ENMASCARADO]',usuario=body.get('username') or body.get('email')))
 if key=='accessToken' and ok: ext=j[key]
s,h,b=http('http://localhost:15254/api/external/ach/cuentas/search/AH000000000001',headers={'Authorization':'Bearer '+ext});check('RD-10','Cuenta destino sintética consultable',s==200 and slim_json(b).get('data',{}).get('estado')=='ACTIVA',dict(HTTP=s,response=slim_json(b)))
s,h,b=http('http://localhost:15141/api/clientes');check('RD-11','Control de autenticación representativo',s==401,dict(HTTP=s,ruta='/api/clientes',token='ausente'))
for id,origin in [('RD-12','http://localhost:13000'),('RD-13','http://origen-no-permitido.invalid')]:
 s,h,b=http('http://localhost:15141/api/clientes',headers={'Origin':origin,'Access-Control-Request-Method':'GET'},method='OPTIONS');allow=h.get('Access-Control-Allow-Origin');check(id,'CORS '+origin,s==204 and (allow==origin if id=='RD-12' else allow is None),dict(HTTP=s,Origin=origin,allow_origin=allow))
s,h,b=http('http://localhost:18081/health');check('RD-15','Banco simulado QA accesible',s==200 and slim_json(b).get('synthetic') is True,dict(HTTP=s,response=slim_json(b)))
# Observación de seguridad heredada; no forma parte del gate de disponibilidad.
s,h,b=http('http://localhost:15141/api/ach/bancos')
observations=[dict(id='OBS-01',reqs=['REQ-06','REQ-17'],HTTP=s,ruta='/api/ach/bancos',sin_token=True,observacion='El catálogo ACH permanece accesible sin token.' if s==200 else 'Registrar comportamiento de acceso.',response=slim_json(b))]
collection=json.loads((B/'Postman_Collection_QA.json').read_text());check('RD-14','Colección Postman disponible',bool(collection.get('item')),dict(archivo='Postman_Collection_QA.json',schema=collection['info']['schema'],sha256=hashlib.sha256((B/'Postman_Collection_QA.json').read_bytes()).hexdigest()))
when=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=-6))).isoformat(timespec='seconds')
report=dict(fecha_hora_Guatemala=when,checks=checks,observaciones=observations,dictamen='APTO CON RESTRICCIONES' if all(x['estado']=='APTO' for x in checks) else 'NO APTO',restricciones=['No se declara ejecución de la suite formal completa. Se ejecutaron solo comprobaciones de preparación.','Diseño sin bloqueos por definición: reglas aprobadas; banco simulado preparado. El código actual debe contrastarse con los nuevos oráculos.','OBS-01: H-05 persiste; priorizar autorización antes de aceptación integral.','No se ejecutó CI remoto ni pruebas TLS/carga.'])
(OUT/'Readiness_Resultados.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
(OUT/'Readiness_Log.txt').write_text('\n'.join([when,'DICTAMEN: '+report['dictamen']]+[f"{x['id']} | {x['estado']} | {x['title']} | {json.dumps(x['observado'],ensure_ascii=False)}" for x in checks]+[json.dumps(x,ensure_ascii=False) for x in observations]))
print(json.dumps(dict(dictamen=report['dictamen'],checks=len(checks),aptos=sum(x['estado']=='APTO' for x in checks),observaciones=[{k:v for k,v in x.items() if k!='response'} for x in observations]),ensure_ascii=False,indent=2))
