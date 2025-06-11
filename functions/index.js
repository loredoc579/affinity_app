const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

// Inizializza l’SDK Admin (eventualmente passa projectId esplicito)
admin.initializeApp();

exports.onChatCreated = onDocumentCreated(
    "chats/{chatId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No snapshot available");
        return;
      }

      const chat = snap.data();
      if (!chat || !Array.isArray(chat.participants)) {
        console.log("Missing or invalid participants:", chat);
        return;
      }

      // 1) Prendi tutti i token dei partecipanti
      const tokensSnap = await admin
          .firestore()
          .collection("tokens")
          .where("uid", "in", chat.participants)
          .where("tags", "array-contains", "chat")
          .get();

      const allTokens = tokensSnap.docs.map((d) => d.id);
      if (allTokens.length === 0) {
        console.log(`Nessun device attivo
           per partecipanti=${chat.participants}`);
        return;
      }

      // 2) Prepara i messaggi
      const messages = allTokens.map((token) => ({
        token,
        notification: {
          title: "Nuova chat creata! 💬",
          body: "Hai una nuova conversazione, dai un’occhiata!",
        },
        data: {
          chatId: event.params.chatId,
        },
      }));

      // 3) Mappiamo ogni send() in una Promise
      const sendPromises = messages.map((msg) =>
        admin.messaging().send(msg),
      );

      // 4) Le eseguiamo in parallelo e logghiamo i risultati
      const results = await Promise.allSettled(sendPromises);

      const successCount = results.filter((r) =>
        r.status === "fulfilled").length;
      const failureCount = results.length - successCount;
      console.log(`✅ Inviate ${successCount}/${results.length} 
        notifiche; ${failureCount} fallite.`);

      results.forEach((r, idx) => {
        if (r.status === "rejected") {
          console.warn(` ❌ Token ${allTokens[idx]} →`, r.reason);
        }
      });
    },
);
