// addChat.js

const admin = require('firebase-admin');

// 1) Rimpiazza con il path al tuo file di service account
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function createChat() {
  try {
    const chatData = {
      lastMessage: "",
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      participants: [
        'wj9anhaw4cdj0fI1EHVCtqFat8Q2',
        'HqbyzepkLwO4mZBw2nvQQFghuTj2'
      ],
    };

    // 2) Aggiunge un nuovo documento con ID auto-generato
    const docRef = await db.collection('chats').add(chatData);

    console.log(`Chat creata con ID: ${docRef.id}`);
  } catch (err) {
    console.error('Errore creazione chat:', err);
  }
}

createChat();
