import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

// Inizializza l’Admin SDK (idempotente se chiamato più volte)
// Inizializza l’Admin SDK solo se non esiste già
if (!admin.apps.length) {
  admin.initializeApp();
}


// Interface per il documento Chat
interface Chat {
  participants: string[];
  // aggiungi altri campi se necessari
}

// Trigger sulla creazione di un documento in 'chats/{chatId}'
export const onChatCreated = onDocumentCreated(
  "chats/{chatId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("No snapshot available");
      return;
    }

    // Casting esplicito del documento a Chat
    const chat = snap.data() as Chat;
    if (!chat || !Array.isArray(chat.participants)) {
      console.log("Missing or invalid participants:", chat);
      return;
    }

    // Estrai chatId dai parametri del path
    const {chatId} = event.params;

    // 1) Prendi tutti i token dei partecipanti
    const tokensSnap = await admin
      .firestore()
      .collection("tokens")
      .where("uid", "in", chat.participants)
      .where("tags", "array-contains", "chat")
      .get();

    const allTokens = tokensSnap.docs.map((d) => d.id);
    if (allTokens.length === 0) {
      console.log(`Nessun device attivo per partecipanti=${chat.participants}`);
      return;
    }

    // 2) Prepara i messaggi
    const messages: admin.messaging.Message[] = allTokens.map((token) => ({
      token,
      notification: {
        title: "Hai un nuovo match! 🎉",
        body: "Puoi iniziare a chattare con il tuo nuovo match.",
      },
      data: {
        type: "new_chat",
        chatId,
      },
    }));

    // 3) Invia tutte le notifiche in parallelo e logga i risultati
    const results = await Promise.allSettled(
      messages.map((msg) => admin.messaging().send(msg))
    );

    const successCount = results.filter((r) => r.status === "fulfilled").length;
    const failureCount = results.length - successCount;
    console.log(`✅ Inviate ${successCount}/${results.length} notifiche;
       ${failureCount} fallite.`);

    results.forEach((r, idx) => {
      if (r.status === "rejected") {
        console.warn(`❌ Token ${allTokens[idx]} →`,
          (r as PromiseRejectedResult).reason);
      }
    });
  }
);
