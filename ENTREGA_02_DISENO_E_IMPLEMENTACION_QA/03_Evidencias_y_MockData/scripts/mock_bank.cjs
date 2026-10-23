// Banco externo 100% sintético. Sin conexiones salientes ni datos reales.
const http=require('node:http');
const processed=new Map();const attempts=new Map();
function json(res,status,data){res.writeHead(status,{'content-type':'application/json'});res.end(JSON.stringify(data));}
http.createServer(async(req,res)=>{
 const url=new URL(req.url,'http://mock-bank:8081');
 if(url.pathname==='/health')return json(res,200,{status:'READY',synthetic:true,scenarios:['success','http500','invalid','timeout','duplicate'],timeoutDelaySeconds:20});
 if(url.pathname==='/stats')return json(res,200,{processed:[...processed.keys()],attempts:Object.fromEntries(attempts)});
 if(url.pathname==='/reset'&&req.method==='POST'){processed.clear();attempts.clear();return json(res,200,{reset:true});}
 if(url.pathname.startsWith('/cuentas/search/'))return json(res,200,{status:true,message:'Cuenta sintetica encontrada.',data:{numeroCuenta:decodeURIComponent(url.pathname.split('/').pop()),estado:true,moneda:'GTQ',tipoCuenta:'AHORRO',titular:{nombre:'Titular QA Sintetico'}}});
 let raw='';for await(const chunk of req)raw+=chunk;
 let body={};try{body=JSON.parse(raw||'{}')}catch{return json(res,400,{status:false,message:'JSON de entrada invalido.'})}
 const scenario=url.pathname.split('/')[1],code=body.codigo_confirmacion;
 if(!['success','http500','invalid','timeout','duplicate'].includes(scenario)||!url.pathname.endsWith('/transferencias'))return json(res,404,{message:'Ruta mock inexistente.'});
 if(!code)return json(res,400,{message:'codigo_confirmacion requerido.'});
 attempts.set(code,(attempts.get(code)||0)+1);
 if(scenario==='timeout'){setTimeout(()=>{if(!res.destroyed)json(res,504,{status:false,message:'Demora sintetica de 20 segundos.'});},20000);return;}
 if(scenario==='http500')return json(res,500,{status:false,message:'Fallo sintetico de banco externo.'});
 if(scenario==='invalid'){res.writeHead(200,{'content-type':'application/json'});res.end('{respuesta-json-incompleta');return;}
 if(processed.has(code)||scenario==='duplicate')return json(res,409,{status:false,message:'La transferencia ya fue procesada.',codigo_confirmacion:code});
 processed.set(code,body.monto);return json(res,201,{status:true,message:'Transferencia sintetica aprobada.',data:{estado:'APROBADA',codigo_confirmacion:code,monto:body.monto}});
}).listen(8081,'0.0.0.0',()=>console.log('Banco simulado QA listo en 8081'));
