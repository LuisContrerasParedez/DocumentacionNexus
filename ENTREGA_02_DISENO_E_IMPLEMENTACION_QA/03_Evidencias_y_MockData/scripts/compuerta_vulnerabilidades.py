"""Regla académica local; entrada normalizada de hallazgos sintéticos o scanner.
No implica integración al workflow CI existente. Rechaza formatos desconocidos.
"""
import json,sys
from pathlib import Path
try:
 d=json.loads(Path(sys.argv[1]).read_text());items=d['vulnerabilidades'];levels=[x['severidad'].upper() for x in items]
 if any(x not in ['CRITICA','ALTA','MEDIA','BAJA'] for x in levels):raise ValueError('Severidad desconocida')
 counts={k.lower()+'s':levels.count(k) for k in ['CRITICA','ALTA','MEDIA','BAJA']}
 blocked=bool(counts['criticas'] or counts['altas']);decision='RECHAZADO' if blocked else 'APROBADO_CON_SEGUIMIENTO' if counts['medias'] else 'APROBADO'
 print(json.dumps(dict(decision=decision,**counts,seguimiento=[x for x in items if x['severidad'].upper()=='MEDIA']),ensure_ascii=False));raise SystemExit(1 if blocked else 0)
except (OSError,ValueError,KeyError,IndexError,TypeError) as e:
 print(json.dumps({'decision':'ERROR_DE_ENTRADA','message':str(e)}));raise SystemExit(2)
