// delete-photoUrls.js
// Script per cancellare il campo photoUrls in Firestore per tutti gli utenti Auth

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const firestore = admin.firestore();

async function deletePhotoUrlsField() {
  console.log('🚀 Inizio rimozione campo photoUrls in Firestore per tutti gli utenti...');
  let pageToken;

  do {
    const { users, pageToken: next } = await admin.auth().listUsers(1000, pageToken);
    pageToken = next;

    for (const { uid } of users) {
      try {
        await firestore.collection('users').doc(uid)
          .update({ photoUrls: admin.firestore.FieldValue.delete() });
        console.log(`🗑️ [${uid}] campo photoUrls rimosso`);
      } catch (err) {
        if (err.code === 5) {
          console.warn(`⚠️ [${uid}] documento non trovato o senza campo photoUrls`);
        } else {
          console.error(`❌ [${uid}] errore rimozione photoUrls: ${err.message}`);
        }
      }
    }
  } while (pageToken);

  console.log('🎉 Rimozione campo photoUrls completata.');
}

if (require.main === module) {
  deletePhotoUrlsField()
    .catch(err => { console.error('Errore deletePhotoUrlsField:', err); process.exit(1); });
}