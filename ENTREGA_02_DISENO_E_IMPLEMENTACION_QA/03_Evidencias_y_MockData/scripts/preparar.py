from pathlib import Path
import json,uuid,csv,hashlib
BASE=Path(__file__).resolve().parents[1]; ROOT=BASE.parents[0].parent
NS=uuid.UUID('8d8c1be6-7b83-4e00-b7a1-6cae2f1a2c02')
def uid(t,i):return str(uuid.uuid5(NS,f'{t}:{i}'))
def save(n,v): (BASE/n).write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf-8')
clients=[];accounts=[];movements=[]
for i in range(1,1001):
 clients.append(dict(id=uid('cliente',i),tipo_cliente='NATURAL',nombre_completo=f'Persona Sintetica QA {i:04}',dpi=f'9900{i:09}',primer_nombre='Persona',primer_apellido=f'QA{i:04}',fecha_nacimiento='1995-01-15',email=f'persona{i:04}@example.invalid',estado='ACTIVO' if i!=1000 else 'INACTIVO',usuario_id=uid('usuario','cliente_a') if i==1 else uid('usuario','cliente_b') if i==2 else None))
 for j in range(2):
  k=(i-1)*2+j+1;tipo='AHORRO' if j==0 else 'MONETARIA';saldo='1000.00' if j==0 else '500.00'
  accounts.append(dict(id=uid('cuenta',k),numero_cuenta=f'{"AH" if j==0 else "MO"}{k:012}',cliente_id=uid('cliente',i),tipo_cuenta=tipo,saldo=saldo,saldo_disponible=saldo,saldo_minimo='100.00' if j==0 else '0.00',limite_retiro_diario='500.00' if j==0 else None,monto_retirado_hoy='0.00',estado='BLOQUEADA' if k==1999 else 'CERRADA' if k==2000 else 'ACTIVA',moneda='GTQ'))
 for j in range(10):
  k=(i-1)*10+j+1
  movements.append(dict(id=uid('movimiento',k),cuenta_id=uid('cuenta',(i-1)*2+1),tipo='DEPOSITO',monto='1.00',saldo_anterior=f'{990+j}.00',saldo_posterior=f'{991+j}.00',referencia=f'E2-HIST-{k:06}',created_at=f'2026-10-{1+j//5:02}T{j%5+8:02}:00:00Z'))
users=[]
roles={'admin':'ADMIN','cajero':'CAJERO','cliente_a':'CLIENTE','cliente_b':'CLIENTE','externo':'BANCO_EXTERNO','bloqueo':'CAJERO','inactivo':'CAJERO','sin_permiso':'CLIENTE'}
for n,r in roles.items():users.append(dict(id=uid('usuario',n),username='qa_'+n,email='qa_'+n+'@example.invalid',rol=r,estado=n!='inactivo',password='E2Qa2026*'))
data=dict(metadata=dict(origen='Generación determinista UUIDv5; sin copia de producción',semilla=str(NS),fecha='2026-10-06',moneda='GTQ',password='Solo QA aislado',movimientos='Histórico sintético de consulta; no representa un libro contable inicial completo'),usuarios=users,clientes=clients,cuentas=accounts,movimientos=movements)
save('MockData_Sintetica.json',data)
with (BASE/'MockData_Cuentas.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.DictWriter(f,fieldnames=accounts[0].keys());w.writeheader();w.writerows(accounts)
sql=["\\set ON_ERROR_STOP on", "DO $$ BEGIN IF current_database() <> 'bancoerp_e2_qa' THEN RAISE EXCEPTION 'Solo bancoerp_e2_qa'; END IF; END $$;",'BEGIN;']
def ins(table,rows):
 for x in rows:
  def val(v):
   if v is None:return 'NULL'
   if isinstance(v,bool):return 'true' if v else 'false'
   return "'"+str(v).replace("'","''")+"'"
  sql.append('INSERT INTO '+table+' ('+','.join(x.keys())+') VALUES ('+','.join(val(v) for v in x.values())+') ON CONFLICT (id) DO NOTHING;')
for u in users:
 x={k:v for k,v in u.items() if k not in ['rol','password']};x.update(nombres='Usuario QA',apellidos=u['username'],password_hash='PLACEHOLDER')
 ins('seguridad.usuarios',[x]);sql[-1]=sql[-1].replace("'PLACEHOLDER'","crypt('E2Qa2026*',gen_salt('bf'))")
 sql.append(f"INSERT INTO seguridad.usuarios_roles(usuario_id,rol_id,estado) SELECT '{u['id']}', id, true FROM seguridad.roles WHERE codigo='{u['rol']}' ON CONFLICT(usuario_id,rol_id) DO NOTHING;")
ins('crm.clientes',clients);ins('cuentas.cuentas',accounts);ins('transacciones.movimientos',movements)
ins('rrhh.empleados',[dict(id=uid('empleado',1),primer_nombre='Operador',primer_apellido='Sintetico',cargo='Cajero',turno='COMPLETO',estado='ACTIVO',usuario_id=uid('usuario','cajero'),fecha_ingreso='2026-01-01')])
sql.append('COMMIT;');(BASE/'MockData_Sintetica.sql').write_text('\n'.join(sql)+'\n')
# Sólo esquema, catálogos y permisos. Se elimina el seed del usuario externo de 013.
schema=BASE/'scripts'/'schema';schema.mkdir(exist_ok=True)
for n in ['001','002','003','004','005','006','007','008','012','013','014','015','016']:
 src=next((ROOT/'Backend/database/deploy/production').glob(n+'_*.sql'));s=src.read_text()
 if n=='013':s=s.split('WITH usuario_externo_seed AS (')[0]
 (schema/src.name).write_text(s)
init='''#!/bin/sh
set -eu
for file in /qa/scripts/schema/*.sql; do
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q -1 -f "$file"
done
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q -f /qa/MockData_Sintetica.sql
'''
(BASE/'scripts/init_qa.sh').write_text(init)
compose='''name: bancoerp-e2-qa
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: e2qa
      POSTGRES_PASSWORD: E2SoloQALocal2026
      POSTGRES_DB: bancoerp_e2_qa
    ports: ["127.0.0.1:15433:5432"]
    volumes:
      - e2-pg:/var/lib/postgresql/data
      - ./:/qa:ro
      - ./scripts/init_all.sql:/docker-entrypoint-initdb.d/01_qa.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U e2qa -d bancoerp_e2_qa"]
      interval: 3s
      retries: 40
  mongo:
    image: mongo:8.0
    ports: ["127.0.0.1:17017:27017"]
    volumes: ["e2-mongo:/data/db"]
  internal-api:
    image: bancoerp-dev-internal-api:latest
    working_dir: /src/BancoERP.InternalAPI
    command: ["dotnet", "run", "--property:NuGetAudit=false", "--no-launch-profile", "--urls", "http://0.0.0.0:8080"]
    environment: &qaenv
      ASPNETCORE_ENVIRONMENT: QA
      DOTNET_RUNNING_IN_CONTAINER: "true"
      DOTNET_ARTIFACTS_ROOT: /tmp/e2-artifacts
      ConnectionStrings__DefaultConnection: Host=postgres;Port=5432;Database=bancoerp_e2_qa;Username=e2qa;Password=E2SoloQALocal2026
      MongoDb__ConnectionString: mongodb://mongo:27017
      MongoDb__DatabaseName: bancoerp_e2_qa
      MongoDb__BanksCollectionName: ach_banks_configurations
      Jwt__SecretKey: E2_Clave_Solo_QA_2026_No_Produccion_123456789
      Jwt__Issuer: BancoERP-E2-QA
      Jwt__Audience: BancoERP-E2-QA
      Jwt__ExpirationHours: "1"
      Jwt__RefreshTokenDays: "7"
      Security__RecoveryTokenHours: "2"
      Security__MaxFailedAccessAttempts: "5"
      Security__PasswordHistoryLimit: "5"
      CORS_ALLOWED_ORIGINS: http://localhost:13000
    ports: ["127.0.0.1:15141:8080"]
    volumes: ["../../Backend:/src:ro"]
    depends_on:
      postgres: {condition: service_healthy}
      mongo: {condition: service_started}
  public-api:
    image: bancoerp-dev-public-api:latest
    working_dir: /src/BancoERP.PublicAPI
    command: ["dotnet", "run", "--property:NuGetAudit=false", "--no-launch-profile", "--urls", "http://0.0.0.0:8080"]
    environment: *qaenv
    ports: ["127.0.0.1:15254:8080"]
    volumes: ["../../Backend:/src:ro"]
    depends_on:
      postgres: {condition: service_healthy}
  mock-bank:
    image: bancoerp-dev-frontend:latest
    command: ["node", "/qa/scripts/mock_bank.cjs"]
    ports: ["127.0.0.1:18081:8081"]
    volumes: ["./:/qa:ro"]
  frontend:
    image: bancoerp-dev-frontend:latest
    environment:
      VITE_API_URL: http://internal-api:8080
      VITE_APP_HOST: 0.0.0.0
      VITE_APP_PORT: "3000"
    ports: ["127.0.0.1:13000:3000"]
    volumes: ["../../Frontend:/app:ro", "e2-node:/app/node_modules"]
    depends_on: [internal-api]
volumes:
  e2-pg:
  e2-mongo:
  e2-node:
'''
# Backend y Frontend se montan sólo para lectura. Los artefactos .NET son temporales.
(BASE/'docker-compose.qa.yml').write_text(compose)
print('Generados:',len(users),'usuarios,',len(clients),'clientes,',len(accounts),'cuentas,',len(movements),'movimientos')

(BASE/'scripts/init_all.sql').write_text('\n'.join(p.read_text() for p in sorted(schema.glob('*.sql'))) + '\n' + (BASE/'MockData_Sintetica.sql').read_text())
