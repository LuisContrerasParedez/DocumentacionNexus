# Guía de ejecución — Entrega 3 · BancoERP Nexus

Objetivo: ejecutar los 46 casos del Documento E2 sobre el entorno QA real, registrar el resultado obtenido por cada especialista y documentar cada fallo con evidencia. **Nada se registra como Pass o Fail sin haberlo ejecutado.**

## 0. Preparación (una vez, antes de empezar)

| Paso | Responsable | Acción | Evidencia que se guarda |
|---|---|---|---|
| 1 | Anderson | `docker compose -f docker-compose.qa.yml up -d` (carpeta `Readiness_y_MockData_E2`) | Captura de `docker compose ps` → `Logs_Consola_Servidor/compose_ps.png` |
| 2 | Sergio | `psql -h 127.0.0.1 -p 15433 -U e2qa -d bancoerp_e2_qa -f MockData_Fixtures_Nexus.sql` | Salida en consola |
| 3 | Sergio | `psql ... -f QA_Readiness_Check_Nexus.sql > ../Logs_Consola_Servidor/Checklist_DB_Nexus.txt`. Todas las filas deben tener `ok = t` | `Checklist_DB_Nexus.txt` (cierra RD-16) |
| 4 | Anderson | Importar en Postman la colección y el ambiente; ejecutar la carpeta **00 · Preparación (tokens)** | Captura del Runner en verde |
| 5 | Anderson | **BUG-NEX-01:** en Postman, sin Authorization, `GET http://localhost:15141/api/ach/bancos`. Capturar código y cuerpo | `Capturas_Bugs/Evidencia_BUG01_Anderson.png` |

## 1. Reparto de casos

| Especialista | Carpetas de Postman | Casos |
|---|---|---|
| Anderson Ariana (QA Técnico) | REQ-01, 02, 03, 13, 14, 17 | 15 |
| Walter Rosales (QA Funcional) | REQ-04, 05, 06, 07, 12 | 13 |
| Sergio Och (QA Datos) | REQ-08, 09, 10, 11, 18 | 14 |
| Luis Contreras (Líder QA) | REQ-15, 16 + caracterización BC-01 (H-01) + regresión P1 final | 4 |

**Orden recomendado:** Walter (clientes/cuentas) → Sergio (caja/transacciones) → Anderson (seguridad/ACH) → Luis. Así las cuentas y la caja quedan en el estado que esperan los casos siguientes.

## 2. Cómo ejecutar cada caso

1. En Postman, abrir la subcarpeta del caso (`TC-REQxx-xxx · ...`) y leer su descripción: precondiciones, datos y resultado esperado.
2. Si dice **PRE-REQUISITO**, ejecutar primero ese paso SQL (ver tabla de la sección 3).
3. Ejecutar sus peticiones en orden (Runner de la subcarpeta) y revisar los tests de código y mensaje.
4. Ejecutar las verificaciones SQL que indique la descripción (saldos, movimientos, caja).
5. Registrar en `02_Matrices_y_Logs/E3_Matriz_Ejecucion_y_Bugs_Nexus.xlsx`, hoja **Log_Ejecucion** (celdas amarillas): Fecha, Resultado_Obtenido (código HTTP, mensaje y efecto real), Estado, ID_Defecto y Evidencia.
6. Las métricas, los criterios de salida y el veredicto se calculan solos.

Alternativa automática: `.\Ejecutar_Newman.ps1 -Especialista <Nombre>` corre las carpetas del especialista y guarda un JSON en `Resultados_Newman`. Sirve como evidencia del Log. Los casos con PRE-REQUISITO se ejecutan y se registran a mano.

## 3. Casos que requieren pasos manuales

| Caso | Especialista | Paso manual |
|---|---|---|
| TC-REQ01-002, TC-REQ15-001 | Anderson / Luis | Antes: `UPDATE seguridad.usuarios SET estado=true, bloqueado=false, bloqueado_hasta=NULL, intentos_fallidos=0 WHERE username='qa_bloqueo';` |
| TC-REQ08-001 | Sergio | Antes: sección 5 de `MockData_Fixtures_Nexus.sql` (cerrar cajas abiertas) |
| TC-REQ10-003, TC-REQ12-003, TC-REQ14-003 | Sergio / Walter / Anderson | Entre la 1.ª y la 2.ª petición: volver a ejecutar las secciones 4 y 5 del fixture (reinicia el acumulado diario) |
| TC-REQ13-001 | Anderson | Si se repite: `mongosh "mongodb://127.0.0.1:17017/bancoerp_e2_qa" Reset_ACH_QA_NEXUS.js` |
| TC-REQ17-002 | Anderson | Bloque [TC-REQ17-002] del fixture: retirar los permisos, ejecutar y luego restaurar |
| TC-REQ18-002 | Sergio | Desactivar la cuenta contable 1101 antes de la 3.ª petición y restaurarla al terminar |
| TC-REQ16-001 | Luis | Usar la BD aislada `bancoerp_e2_qa_rep01` (`MockData_Fixture_REP01.sql`) |

## 4. Cuando un caso falla (Fail)

1. Captura de pantalla de Postman con la petición y la respuesta visibles (código, cuerpo y URL) → `Capturas_Bugs/Evidencia_BUG0X_<Nombre>.png`.
2. Si hay error de servidor, guardar el log del contenedor: `docker compose -f docker-compose.qa.yml logs internal-api --since 10m > ../Logs_Consola_Servidor/BUG0X_internal-api.log`.
3. Agregar una fila en **Bug_Tracker** (ID consecutivo BUG-NEX-02, 03…): caso, módulo, título, quién reporta, severidad, prioridad, estado Abierto y evidencia.
4. Copiar la ficha de BUG-NEX-01 en **Fichas_Defectos** y llenarla: pasos para reproducir, esperado vs. obtenido.
5. En el Log poner Estado = Fail e ID_Defecto = BUG-NEX-0X.

**Severidad:** Crítica = dinero o saldo inconsistente, o acceso no autorizado a una operación financiera. Alta = regla de negocio o de seguridad incumplida sin pérdida directa. Media = validación o mensaje incorrecto con alternativa. Baja = cosmético.

**Blocked:** el entorno se cae, un defecto previo impide el caso, o la regla no está definida (H-01/H-04). Se registra el motivo en Resultado_Obtenido.

## 5. Qué enviar para completar el documento final

- El Excel con el Log y el Bug Tracker llenos (o los JSON de `Resultados_Newman`).
- Las capturas de `Capturas_Bugs` y los logs de `Logs_Consola_Servidor`.
- La fecha de ejecución y, si un caso no se ejecutó, el motivo.

Con eso se completan el Log del documento, las fichas de cada bug, las métricas del TSR, la evaluación de criterios de salida y el veredicto Go / No-Go.

## 6. Ciclo 2 — Re-prueba y regresión tras la corrección (22/10/2026)

Cuando el equipo de desarrollo entrega una corrección, el ciclo se repite completo sobre la build nueva, con scripts para que sea reproducible:

| Paso | Acción | Evidencia |
|---|---|---|
| 1 | `sh Preparar_Entorno_Re_Prueba.sh <E2 compose> <E3 evidencias> <Backend>`: entorno nuevo (`bancoerp-e3-retest`), carga base, capa Nexus, `009_ach_seed.sql`, Mongo, checklist y verificación | `Re_Prueba_Cierre_E3/01_Entorno` |
| 2 | `python3 -I Generar_Coleccion_Re_Prueba.py`: colección v2 (fila P7-ACH, oráculo de 11 totales en TC-REQ16-001, carpeta RT) | `Postman_Collection_QA_Nexus_v2_Re_Prueba.json` |
| 3 | `python3 -I Ejecutar_Re_Prueba_E3.py`: smoke → re-prueba de defectos → regresión de los 46 casos con los pasos manuales de la sección 3 automatizados y SQL ANTES/DESPUÉS por caso → REP-01 → control cruzado | `03_Re_Prueba_Defectos`, `04_Regresion_Completa`, `05_Verificaciones_SQL` |
| 4 | `dotnet test BancoERP.UnitTests` con y sin la corrección | `02_Pruebas_Unitarias` |
| 5 | Pasar el defecto a **Cerrado** solo si la re-prueba y la regresión completa quedan sin fallos en la misma build | Bug_Tracker y fichas |

Si un intento se interrumpe, no se borra: se mueve a `00_Intento_N_...` con un LEEME que explique la causa, y el ciclo se repite desde un entorno limpio.
