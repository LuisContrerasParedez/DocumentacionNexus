// Reset del banco ACH QA_NEXUS para re-ejecutar TC-REQ13-001 (lo crea el propio caso vía API)
// mongosh "mongodb://127.0.0.1:17017/bancoerp_e2_qa" Reset_ACH_QA_NEXUS.js
if (db.getName() !== 'bancoerp_e2_qa') { throw new Error('Solo bancoerp_e2_qa'); }
printjson(db.ach_banks_configurations.deleteMany({ codigo: 'QA_NEXUS' }));
