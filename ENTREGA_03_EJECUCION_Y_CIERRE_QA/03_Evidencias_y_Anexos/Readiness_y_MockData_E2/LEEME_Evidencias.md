# 03_Evidencias_y_MockData — BancoERP Nexus · Entrega 2

Esta carpeta respalda el documento **E2_Documento_Diseno_Implementacion_Nexus** (18 requerimientos, 46 casos) y la matriz **E2_Matrices_y_CasosPrueba_Nexus.xlsx**. Cada archivo se cita en las secciones 6, 7 y 8 del documento.

## Contenido

| Archivo | Qué es | Sección del Word |
|---|---|---|
| `MockData_Sintetica.json` / `.sql` / `MockData_Cuentas.csv` | Carga base de volumen: 8 usuarios, 1 000 clientes, 2 000 cuentas, 10 000 movimientos (sintéticos, `.invalid`). Cargada y observada el 06/10/2026 (RD-05). | 6.1, 7 |
| `MockData_Sintetica_Nexus.json` | Capa de datos exacta de los 46 casos: usuarios, clientes, cuentas, banco ACH, valores frontera, REP-01 y matriz TD-01..TD-25. | 6, 6.1 |
| `MockData_Fixtures_Nexus.sql` | Script idempotente que crea o normaliza esa capa en `bancoerp_e2_qa`. Volver a ejecutarlo = "reiniciar fixture". Incluye bloques por caso (TC-REQ01-002, 08-002, 17-002, 18-002). | 6, 6.1 |
| `TestData_Matrix_Nexus.csv` / `MockData_Cuentas_Nexus.csv` | Matriz de datos con valores exactos y casos que la usan; cuentas del fixture. | 6 |
| `MockData_Fixture_REP01.sql` / `REP01_Totales_Esperados.json` | BD aislada `bancoerp_e2_qa_rep01` y totales esperados para TC-REQ16-001. | 4, 6 |
| `Postman_Collection_QA_Nexus.json` / `Postman_Environment_QA_Nexus.json` | 125 peticiones: preparación de tokens + una subcarpeta por cada caso TC-REQxx-xxx, con tests de código HTTP y mensaje. Guard que solo permite `localhost:15141/15254`. | 7, 8 |
| `QA_Readiness_Check_Nexus.sql` | Checklist de solo lectura C-01..C-13 (BD, usuarios, cuentas, plan contable, permisos). | 7 (RD-16) |
| `docker-compose.qa.yml` | Entorno QA aislado (frontend 13000, InternalAPI 15141, PublicAPI 15254, PostgreSQL 15433, Mongo 17017, banco simulado 18081; solo 127.0.0.1). | 1.1, 7 |
| `Reset_ACH_QA_NEXUS.js` | Borra el banco QA_NEXUS para volver a ejecutar TC-REQ13-001. | 4 |
| `Capturas_Readiness_Entorno/` | Evidencia observada del 06/10/2026 18:42: capturas 01–04, `Readiness_Log.txt`, `Readiness_Resultados.json`, `Readiness_Observado.html`, `OpenAPI_Interna.json`, `OpenAPI_Publica.json`. **No modificadas.** | 7 |

Los scripts de apoyo del entorno (`scripts/`: `init_all.sql`, `mock_bank.cjs`, `readiness.py`) se conservan como estaban.

## Orden de uso antes de la Entrega 3

1. `docker compose -f docker-compose.qa.yml up -d`
2. Si la BD es nueva: `scripts/init_all.sql` (lo hace el compose) y `MockData_Sintetica.sql`.
3. `psql -h 127.0.0.1 -p 15433 -U e2qa -d bancoerp_e2_qa -f MockData_Fixtures_Nexus.sql`
4. `psql ... -f QA_Readiness_Check_Nexus.sql > Capturas_Readiness_Entorno/Checklist_DB_Nexus.txt`. Todas las filas deben tener `ok = t` (esto completa RD-16).
5. Importar la colección y el ambiente en Postman y ejecutar primero la carpeta **00 · Preparación**.
6. Ejecutar cada caso según su descripción. Los pre-requisitos SQL están en la descripción de la subcarpeta.

## Notas de trazabilidad

- **Contraseña de los casos:** `QaNexus2026`. La carga base se generó con otra contraseña. El fixture Nexus la normaliza para todos los usuarios que usan los casos.
- **Readiness del 06/10/2026:** se ejecutó con la carga base. En `Readiness_Resultados.json`, RD-14 registra la huella SHA-256 de la colección vigente ese día. La colección Nexus de 46 casos se generó después, a partir del documento.
- **Numeración en OBS-01:** en `Readiness_Resultados.json`, OBS-01 menciona "REQ-06, REQ-17" según la numeración interna del script. En este documento corresponde a **REQ-13 (configuración ACH)** y **REQ-03 / H-05 (autorización)**.
- **Texto de restricciones de la captura 04:** el texto "Diseño sin bloqueos por definición: reglas aprobadas" es salida literal del script de readiness. En este documento, **H-01 y H-04 siguen abiertos** (sección 5). Prevalece lo que dice el documento.
- **Edad frontera (TC-REQ04-001):** usa fecha base 2026-10-02. Si se ejecuta otro día, la fecha de nacimiento debe ser exactamente la fecha de ejecución menos 18 años.
- **Validación:** los SQL se ejecutaron sin errores, dos veces seguidas (idempotencia), contra una réplica mínima del esquema en PostgreSQL 16. La colección se recorrió completa con Newman (125 peticiones, 0 errores de script). No se ejecutó contra el entorno real del equipo.
