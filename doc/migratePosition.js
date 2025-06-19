// migrateLocation.js

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function migrate() {
  const users = await db.collection('users').get();
  console.log(`Trovati ${users.size} utenti`);

  for (const doc of users.docs) {
    const data = doc.data();
    const hasLegacy = (
      data.lastLat !== undefined ||
      data.lastLong !== undefined ||
      data.lastCity !== undefined ||
      data.lastLocationUpdate !== undefined
    );
    if (!hasLegacy) continue;

    const lat = Number(data.lastLat) || 0;
    const lng = Number(data.lastLong) || 0;
    const city = typeof data.lastCity === 'string' ? data.lastCity : '';
    const ts  = data.lastLocationUpdate instanceof admin.firestore.Timestamp
                ? data.lastLocationUpdate
                : admin.firestore.Timestamp.now();

    const newLoc = {
      position: new admin.firestore.GeoPoint(lat, lng),
      city: city,
      updatedAt: ts,
    };

    // Scrivo il nuovo campo e rimuovo i legacy
    await doc.ref.set({
      location: newLoc
    }, { merge: true });

    await doc.ref.update({
      lastLat: admin.firestore.FieldValue.delete(),
      lastLong: admin.firestore.FieldValue.delete(),
      lastCity: admin.firestore.FieldValue.delete(),
      lastLocationUpdate: admin.firestore.FieldValue.delete(),
    });

    console.log(`Migrato ${doc.id}:`, newLoc);
  }

  console.log('Migrazione completata');
  process.exit(0);
}

migrate().catch(err => {
  console.error(err);
  process.exit(1);
});
