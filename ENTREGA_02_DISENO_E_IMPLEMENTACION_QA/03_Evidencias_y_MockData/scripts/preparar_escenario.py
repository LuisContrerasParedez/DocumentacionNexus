from pathlib import Path
import json,subprocess,argparse,uuid
B=Path(__file__).resolve().parents[1];d=json.loads((B/'MockData_Sintetica.json').read_text());parser=argparse.ArgumentParser();parser.add_argument('--paginacion',action='store_true');a=parser.parse_args()
q=["DO $$ BEGIN IF current_database()<>'bancoerp_e2_qa' THEN RAISE EXCEPTION 'Solo QA'; END IF; END $$;",'BEGIN;']
for x in d['cuentas'][:3]:
 q.append(f"UPDATE cuentas.cuentas SET saldo={x['saldo']},saldo_disponible={x['saldo_disponible']},saldo_minimo={x['saldo_minimo']},limite_retiro_diario={x['limite_retiro_diario'] or 'NULL'},monto_retirado_hoy=0,saldo_retenido=0,estado='ACTIVA' WHERE id='{x['id']}';")
if a.paginacion:
 for i in range(11,121):
  id=str(uuid.uuid5(uuid.NAMESPACE_URL,f'E2-paginacion-{i}'))
  q.append(f"INSERT INTO transacciones.movimientos(id,cuenta_id,tipo,monto,saldo_anterior,saldo_posterior,referencia,created_at) VALUES('{id}','{d['cuentas'][0]['id']}','DEPOSITO',1,999,1000,'E2-PAG-{i:03}',TIMESTAMPTZ '2026-10-03 00:00:00+00'+INTERVAL '{i} seconds') ON CONFLICT(id) DO NOTHING;")
q.append('COMMIT;');sql='\n'.join(q)
r=subprocess.run(['docker','compose','-f',str(B/'docker-compose.qa.yml'),'exec','-T','postgres','psql','-U','e2qa','-d','bancoerp_e2_qa','-v','ON_ERROR_STOP=1','-q'],input=sql,text=True,capture_output=True);print(r.stdout or r.stderr or 'Fixture preparado');raise SystemExit(r.returncode)
