/**
 * Script di migrazione filtri da campi legacy
 *   users/{uid} → users/{uid}/filters/settings
 * 
 * Opzionale: rimuove i campi legacy dopo averli copiati.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrate() {
  const usersSnap = await db.collection('users').get();
  console.log(`Trovati ${usersSnap.size} utenti`);
  
  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const data = userDoc.data();

    // Controllo se ci sono i vecchi campi
    const hasLegacy = 
      data.filterMinAge !== undefined ||
      data.filterMaxAge !== undefined ||
      data.filterMaxDistance !== undefined ||
      data.filterGender !== undefined;

    if (!hasLegacy) continue;

    // Costruisco l'oggetto per il nuovo documento
    const newSettings = {
      minAge:      typeof data.filterMinAge      === 'number' ? data.filterMinAge      : 18,
      maxAge:      typeof data.filterMaxAge      === 'number' ? data.filterMaxAge      : 40,
      maxDistance: typeof data.filterMaxDistance === 'number' ? data.filterMaxDistance : 50,
      gender:      typeof data.filterGender      === 'string' ? data.filterGender      : 'all',
    };

    // Scrivo in users/{uid}/filters/settings
    const settingsRef = db
      .collection('users')
      .doc(uid)
      .collection('filters')
      .doc('settings');

    await settingsRef.set(newSettings, { merge: true });
    console.log(`  ▸ Migrazione filtri per utente ${uid}:`, newSettings);

    // Opzionale: rimuovo i campi legacy
    await userDoc.ref.update({
      filterMinAge:      admin.firestore.FieldValue.delete(),
      filterMaxAge:      admin.firestore.FieldValue.delete(),
      filterMaxDistance: admin.firestore.FieldValue.delete(),
      filterGender:      admin.firestore.FieldValue.delete(),
    });
    console.log(`    • Campi legacy rimossi per ${uid}`);
  }

  console.log('Migrazione completata!');
  process.exit(0);
}

migrate().catch(err => {
  console.error('Errore durante migrazione:', err);
  process.exit(1);
});
