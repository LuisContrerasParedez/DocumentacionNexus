const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'/private/tmp/e2qa-tools/node_modules/playwright-core');
const fs=require('fs'),path=require('path');
const out=path.resolve(__dirname,'../Capturas_Readiness_Entorno');
(async()=>{
const browser=await chromium.launch({channel:'chrome',headless:true});
const ctx=await browser.newContext({viewport:{width:1366,height:900},deviceScaleFactor:1.4});
const page=await ctx.newPage();
for(const [url,name] of [['http://localhost:13000/login','01_Frontend_QA.png'],['http://localhost:15141/swagger/index.html','02_Swagger_Interna_QA.png'],['http://localhost:15254/swagger/index.html','03_Swagger_Publica_QA.png']]){
 await page.goto(url,{waitUntil:'networkidle'});await page.screenshot({path:path.join(out,name)});
}
const r=JSON.parse(fs.readFileSync(path.join(out,'Readiness_Resultados.json')));
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const html='<!doctype html><html lang="es"><meta charset="utf-8"><title>Readiness observado QA E2</title><style>body{font:16px Arial;margin:40px;color:#17365d;background:#f3f7fb}h1{font-size:30px}small{color:#586778}table{border-collapse:collapse;background:white;width:100%}td,th{padding:12px;border-bottom:1px solid #d5dfeb;text-align:left}th{background:#17365d;color:white}.ok{color:#087f63;font-weight:bold}pre{background:white;padding:20px;white-space:pre-wrap}</style><h1>BancoERP · Alistamiento QA E2</h1><p>'+escape(r.fecha_hora_Guatemala)+' · <b>'+escape(r.dictamen)+'</b></p><small>Vista renderizada de Readiness_Resultados.json, generado por readiness.py contra el entorno QA local.</small><table><tr><th>ID</th><th>Comprobación</th><th>Estado</th></tr>'+r.checks.map(x=>'<tr><td>'+x.id+'</td><td>'+escape(x.title)+'</td><td class="ok">'+x.estado+'</td></tr>').join('')+'</table><h2>Datos observados</h2><pre>'+escape(JSON.stringify(r.checks.find(x=>x.id==='RD-05').observado,null,2))+'</pre><h2>Restricciones</h2><p>'+r.restricciones.map(escape).join('<br>')+'</p></html>';
fs.writeFileSync(path.join(out,'Readiness_Observado.html'),html);
await page.setContent(html);await page.screenshot({path:path.join(out,'04_Readiness_Observado.png'),fullPage:true});
const mr=JSON.parse(fs.readFileSync(path.join(out,'Mock_y_Compuerta_Resultados.json')));
const mh='<!doctype html><html lang="es"><meta charset="utf-8"><title>Mock y compuerta QA</title><style>body{font:16px Arial;margin:35px;background:#f3f7fb;color:#17365d}h1{font-size:28px}td,th{padding:10px;border-bottom:1px solid #cdd8e5;text-align:left}table{width:100%;border-collapse:collapse;background:white}th{background:#17365d;color:white}.ok{color:#087f63;font-weight:bold}small{display:block;margin:16px 0}</style><h1>Banco simulado y compuerta local · QA E2</h1><p>'+escape(mr.fecha_hora_Guatemala)+' · 12/12 comprobaciones OK</p><small>'+escape(mr.alcance)+'</small><table><tr><th>ID</th><th>Resultado</th><th>Observado</th></tr>'+mr.controles.map(x=>'<tr><td>'+x.id+'</td><td class="ok">'+x.resultado+'</td><td>'+escape(JSON.stringify(x.observado))+'</td></tr>').join('')+'</table></html>';
fs.writeFileSync(path.join(out,'Mock_y_Compuerta_Observado.html'),mh);await page.setContent(mh);await page.screenshot({path:path.join(out,'05_Mock_y_Compuerta.png'),fullPage:true});
await browser.close();console.log('5 capturas QA guardadas');
})().catch(e=>{console.error(e);process.exit(1)});
