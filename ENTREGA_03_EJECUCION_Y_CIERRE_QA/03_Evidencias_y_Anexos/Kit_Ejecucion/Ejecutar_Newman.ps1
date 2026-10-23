# Ejecutar_Newman.ps1 — Corre los casos de un especialista y exporta los resultados reales (Entrega 3, BancoERP Nexus)
# Requisitos: entorno QA levantado (docker compose -f docker-compose.qa.yml up -d), Node.js y Newman:
#   npm install -g newman
# Uso (desde esta carpeta):
#   .\Ejecutar_Newman.ps1 -Especialista Anderson
#   .\Ejecutar_Newman.ps1 -Especialista Walter
#   .\Ejecutar_Newman.ps1 -Especialista Sergio
#   .\Ejecutar_Newman.ps1 -Especialista Luis
# Salida: ..\Resultados_Newman\<Especialista>_<fecha-hora>.json (resultado por petición) y .xml (JUnit)

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Anderson', 'Walter', 'Sergio', 'Luis')]
  [string]$Especialista
)

$ErrorActionPreference = 'Stop'
$base = Join-Path $PSScriptRoot '..\Readiness_y_MockData_E2'
$coleccion = Join-Path $base 'Postman_Collection_QA_Nexus.json'
$ambiente = Join-Path $base 'Postman_Environment_QA_Nexus.json'
$salida = Join-Path $PSScriptRoot '..\Resultados_Newman'
New-Item -ItemType Directory -Force -Path $salida | Out-Null

# Carpetas de la colección por especialista (mismo reparto que el Log de Ejecución)
$carpetas = @{
  'Anderson' = @('REQ-01', 'REQ-02', 'REQ-03', 'REQ-13', 'REQ-14', 'REQ-17')
  'Walter'   = @('REQ-04', 'REQ-05', 'REQ-06', 'REQ-07', 'REQ-12')
  'Sergio'   = @('REQ-08', 'REQ-09', 'REQ-10', 'REQ-11', 'REQ-18')
  'Luis'     = @('REQ-15', 'REQ-16')
}

# 1) Smoke del entorno antes de ejecutar
foreach ($url in @('http://localhost:13000/login', 'http://localhost:15141/api/Ping', 'http://localhost:15254/api/Home')) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
    Write-Host "OK  $url -> HTTP $($r.StatusCode)"
  } catch {
    Write-Host "FALLA  $url -> $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'El entorno QA no responde. Levántelo antes de ejecutar (los casos quedarían Blocked).' -ForegroundColor Red
    exit 1
  }
}

# 2) Ejecución: primero la preparación de tokens y luego las carpetas del especialista
$sello = Get-Date -Format 'yyyyMMdd_HHmm'
$nargs = @('run', $coleccion, '-e', $ambiente, '--folder', '00 · Preparación (tokens)')
foreach ($c in $carpetas[$Especialista]) { $nargs += @('--folder', $c) }
$nargs += @('--reporters', 'cli,json,junit',
           '--reporter-json-export', (Join-Path $salida "$($Especialista)_$sello.json"),
           '--reporter-junit-export', (Join-Path $salida "$($Especialista)_$sello.xml"),
           '--delay-request', '300', '--timeout-request', '30000')
Write-Host "Ejecutando carpetas: $($carpetas[$Especialista] -join ', ')"
& newman @nargs
Write-Host ''
Write-Host "Resultados guardados en $salida. Envíe el .json al equipo/Claude para completar el Log y el TSR."
Write-Host 'IMPORTANTE: los casos marcados PRE-REQUISITO en la Guía requieren pasos SQL; ejecútelos en Postman y regístrelos a mano.'
