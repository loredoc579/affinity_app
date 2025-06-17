// deleteSwipesToday.js

const admin = require('firebase-admin');

// Sostituisci con il path al tuo serviceAccountKey JSON
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function deleteSwipesToday() {
  const now = new Date();
  // inizio della giornata locale (00:00:00)
  const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startTimestamp = admin.firestore.Timestamp.fromDate(startOfDay);

  // Query per tutti gli swipe di oggi
  const snapshot = await db.collection('swipes')
    .where('timestamp', '>=', startTimestamp)
    .get();

  if (snapshot.empty) {
    console.log('Nessuno swipe di oggi da eliminare.');
    return;
  }

  console.log(`Trovati ${snapshot.size} swipe di oggi. Avvio cancellazione...`);

  // Firestore batch supporta max 500 operazioni per batch
  const batchSize = 500;
  let batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    count++;

    // Se raggiungiamo batchSize, committiamo e ricominciamo
    if (count === batchSize) {
      await batch.commit();
      console.log(`Eliminati ${count} documenti...`);
      batch = db.batch();
      count = 0;
    }
  }

  // Commit rimanenti
  if (count > 0) {
    await batch.commit();
    console.log(`Eliminati gli ultimi ${count} documenti.`);
  }

  console.log('Cancellazione completata con successo.');
}

deleteSwipesToday()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Errore durante la cancellazione:', err);
    process.exit(1);
  });
