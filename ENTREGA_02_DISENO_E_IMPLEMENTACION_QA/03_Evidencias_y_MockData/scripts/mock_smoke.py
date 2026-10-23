from pathlib import Path
import json,urllib.request,urllib.error,time,subprocess,socket,datetime
B=Path(__file__).resolve().parents[1];OUT=B/'Capturas_Readiness_Entorno';BASE='http://localhost:18081';tests=[]
def http(path,body=None,timeout=4):
 req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers={'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=timeout) as r:return r.status,r.read().decode()
 except urllib.error.HTTPError as e:return e.code,e.read().decode()
def ck(id,ok,observed):tests.append(dict(id=id,resultado='OK' if ok else 'ERROR',observado=observed))
http('/reset',{})
s,b=http('/health');ck('MOCK-01',s==200 and json.loads(b)['synthetic'],json.loads(b))
s,b=http('/cuentas/search/EXT-QA-0001');ck('MOCK-02',s==200 and json.loads(b)['data']['estado'],json.loads(b))
body={'codigo_confirmacion':'E2-SMOKE-0001','monto':'100.00'}
s,b=http('/success/transferencias',body);ck('MOCK-03',s==201,dict(HTTP=s,response=json.loads(b)))
s,b=http('/success/transferencias',body);ck('MOCK-04',s==409,dict(HTTP=s,response=json.loads(b)))
s,b=http('/http500/transferencias',{'codigo_confirmacion':'E2-SMOKE-0002','monto':'100.00'});ck('MOCK-05',s==500,dict(HTTP=s,response=json.loads(b)))
s,b=http('/invalid/transferencias',{'codigo_confirmacion':'E2-SMOKE-0003','monto':'100.00'})
try:json.loads(b);invalid=False
except json.JSONDecodeError:invalid=True
ck('MOCK-06',s==200 and invalid,dict(HTTP=s,cuerpo_JSON_invalido=invalid))
t=time.monotonic()
try:http('/timeout/transferencias',{'codigo_confirmacion':'E2-SMOKE-0004','monto':'100.00'},timeout=.5);timed=False
except (TimeoutError,socket.timeout):timed=True
ck('MOCK-07',timed,dict(timeout_cliente_fixture_segundos=.5,demora_mock_segundos=20,observado=round(time.monotonic()-t,3),nota='Verifica demora del fixture, no el timeout de 15 s del producto.'))
s,b=http('/stats');stats=json.loads(b);ck('MOCK-08',stats['processed']==['E2-SMOKE-0001'],stats)
for sev,fn,code,decision in [('ALTA','Alta',1,'RECHAZADO'),('CRITICA','Critica',1,'RECHAZADO'),('MEDIA','Media',0,'APROBADO_CON_SEGUIMIENTO'),('BAJA','Baja',0,'APROBADO')]:
 r=subprocess.run(['python3',str(B/'scripts/compuerta_vulnerabilidades.py'),str(B/f'Vulnerabilidades_QA_{fn}.json')],capture_output=True,text=True);j=json.loads(r.stdout);ck('GATE-'+sev,r.returncode==code and j['decision']==decision,dict(exit_code=r.returncode,**j))
http('/reset',{})
report=dict(fecha_hora_Guatemala=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=-6))).isoformat(timespec='seconds'),alcance='Comprobación del banco simulado y de la compuerta LOCAL. No equivale a ejecución integral del sistema ni a una corrida CI remota.',controles=tests,errores=sum(x['resultado']!='OK' for x in tests));(OUT/'Mock_y_Compuerta_Resultados.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(dict(controles=len(tests),errores=report['errores']),indent=2));raise SystemExit(bool(report['errores']))
