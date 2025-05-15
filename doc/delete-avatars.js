// delete-avatars.js
// Script per cancellare tutti gli avatar da Firebase Storage e rimuovere i riferimenti in Firestore

async function deleteAllAvatars() {
  console.log('🚀 Inizio cancellazione avatar su Storage e Firestore...');
  let pageToken;
  do {
    const { users, pageToken: next } = await admin.auth().listUsers(1000, pageToken);
    pageToken = next;
    for (const { uid } of users) {
      // Rimuovi campo photoUrls in Firestore
      await firestore.collection('users').doc(uid).update({ photoUrls: admin.firestore.FieldValue.delete() });
      console.log(`🗑️ [${uid}] campo photoUrls rimosso da Firestore`);

      // Elimina file dal bucket: avatars/male|female/uid-*.jpg
      const genders = ['male', 'female'];
      for (const gender of genders) {
        for (let i = 0; i < 9; i++) {
          const filePath = `avatars/${gender}/${uid}-${i}.jpg`;
          const file = bucket.file(filePath);
          try {
            await file.delete();
            console.log(`🗑️ Eliminato ${filePath}`);
          } catch (err) {
            if (err.code === 404) {
              // file inesistente
            } else {
              console.warn(`⚠️ Errore eliminazione ${filePath}: ${err.message}`);
            }
          }
        }
      }
    }
  } while (pageToken);
  console.log('🎉 Cancellazione completata.');
}

// Se eseguito con argomento 'delete', avvia cancellazione
if (require.main === module && process.argv.includes('delete')) {
  deleteAllAvatars().catch(err => { console.error('Errore deleteAllAvatars:', err); process.exit(1); });
}