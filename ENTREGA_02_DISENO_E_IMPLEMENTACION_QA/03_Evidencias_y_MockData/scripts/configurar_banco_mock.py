from pathlib import Path
import json,subprocess
B=Path(__file__).resolve().parents[1]
lines=["const d=db.getSiblingDB('bancoerp_e2_qa');"]
for i,scenario in enumerate(['success','http500','invalid','timeout','duplicate'],1):
 doc=dict(nombre='Banco Sintetico '+scenario,codigo='E2_QA_'+scenario.upper(),descripcion='Fixture exclusivamente QA; sin integración real.',activo=True,api_base_url='http://mock-bank:8081',api_endpoint='/'+scenario+'/transferencias',http_method='POST',auth_login_endpoint=None,auth_email=None,auth_password=None,headers={},estructura_json_formulario={'numeroCuentaDestino':'EXT-QA-0001'},estructura_json_payload={},lookup_cuenta_endpoint='/cuentas/search/{numeroCuenta}',lookup_cuentas_disponibles_endpoint=None)
 lines.append(f"d.ach_banks_configurations.updateOne({{_id:ObjectId('e2000000000000000000000{i}')}},{{$set:{json.dumps(doc)},$setOnInsert:{{fecha_creacion:new Date()}},$currentDate:{{fecha_actualizacion:true}}}},{{upsert:true}});")
lines.append("print(JSON.stringify({database:d.getName(),bancos_mock:d.ach_banks_configurations.countDocuments({codigo:/^E2_QA_/})}));")
s='\n'.join(lines);(B/'scripts/seed_banco_mock.js').write_text(s)
r=subprocess.run(['docker','compose','-f',str(B/'docker-compose.qa.yml'),'exec','-T','mongo','mongosh','--quiet'],input=s,text=True,capture_output=True);print(r.stdout or r.stderr);raise SystemExit(r.returncode)
