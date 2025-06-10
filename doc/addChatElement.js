// addChat.js

const admin = require('firebase-admin');

// 1) Rimpiazza con il path al tuo file di service account
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createOrReplaceChat() {
  const participantIds = [
    'wj9anhaw4cdj0fI1EHVCtqFat8Q2',
    'HqbyzepkLwO4mZBw2nvQQFghuTj2'
  ];
  const sortedTarget = participantIds.slice().sort();

  try {
    const chatsRef = db.collection('chats');

    // 1) Esegui una sola query con array-contains sul primo ID
    const snapshot = await chatsRef
      .where('participants', 'array-contains', participantIds[0])
      .get();

    // 2) Filtra client-side i documenti che contengono anche il secondo ID
    const deletions = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      if (
        Array.isArray(data.participants) &&
        data.participants.length === 2 &&
        data.participants.includes(participantIds[1])
      ) {
        // Confronto ordinato per sicurezza
        const sortedCurrent = data.participants.slice().sort();
        if (
          sortedCurrent[0] === sortedTarget[0] &&
          sortedCurrent[1] === sortedTarget[1]
        ) {
          console.log(`Cancello chat esistente con ID: ${doc.id}`);
          deletions.push(doc.ref.delete());
        }
      }
    });
    await Promise.all(deletions);

    // 3) Crea un nuovo documento
    const chatData = {
      lastMessage: "",
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      participants: participantIds,
    };
    const docRef = await chatsRef.add(chatData);
    console.log(`Nuova chat creata con ID: ${docRef.id}`);

  } catch (err) {
    console.error('Errore creazione/rimozione chat:', err);
  }
}

createOrReplaceChat();
