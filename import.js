// import.js
const admin = require('firebase-admin');
const serviceAccount = require('./appgap_service_key.json');
const data = require('./organigramme.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function importData() {
  const col = db.collection('organigramme');
  for (const [docId, docData] of Object.entries(data)) {
    await col.doc(docId).set(docData);
    console.log(`Importé ${docId}`);
  }
  console.log('Import terminé.');
  process.exit(0);
}

importData().catch(err => {
  console.error(err);
  process.exit(1);
});
