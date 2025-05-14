// import-users.js
const fs = require('fs');
const { parse } = require('csv-parse');
const admin = require('firebase-admin');

// 1) Carica direttamente la chiave JSON
//    Assicurati che serviceAccountKey.json si trovi nella stessa cartella di questo script
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function main() {
  console.log('🚀 Import su progetto:', admin.app().options.projectId);
  console.log('📄 Leggo users.csv da:', __dirname + '/users.csv');

  const parser = fs
    .createReadStream('users.csv')
    .pipe(parse({ columns: true, trim: true }));

  for await (const row of parser) {
    console.log('🔎 Riga:', row);
    try {
      const userRecord = await admin.auth().createUser({
        email: row.email,
        emailVerified: false,
        password: row.password,
        displayName: row.displayName,
      });
      console.log(`✅ Creato utente ${row.email} (UID: ${userRecord.uid})`);
    } catch (err) {
      console.error(`❌ Errore per ${row.email}:`, err.message);
    }
  }

  console.log('🎉 Import completato');
}

main().catch(console.error);
