import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

// Inizializza l’Admin SDK solo se non esiste già
if (!admin.apps.length) {
  admin.initializeApp();
}

// Interface per il documento Chat
interface Chat {
  participants: string[];
  createdBy?: string;
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
    const creatorId = chat.createdBy;

    if (!creatorId || !Array.isArray(chat.participants)) {
      console.log("Missing creatorId or invalid participants:", chat);
      return;
    }

    // Troviamo chi DEVE ricevere la notifica (cioè non il creatore)
    const receivers = chat.participants.filter((id) => id !== creatorId);
    if (receivers.length === 0) return;

    const {chatId} = event.params;

    // --- 🌟 NOVITÀ: RECUPERA I DATI DEL MITTENTE ---
    let senderName = "Qualcuno";
    let senderPhoto = "";
    try {
      const creatorDoc = await admin
        .firestore()
        .collection("users")
        .doc(creatorId)
        .get();
      if (creatorDoc.exists) {
        const data = creatorDoc.data();
        senderName = data?.name || "Qualcuno";
        senderPhoto = data?.photoUrl || "";
      }
    } catch (error) {
      console.error("Errore durante il recupero del profilo mittente:", error);
    }

    // 1) Prendi tutti i token dei partecipanti
    const tokensSnap = await admin
      .firestore()
      .collection("tokens")
      .where("uid", "in", receivers)
      .where("tags", "array-contains", "chat")
      .get();

    const allTokens = tokensSnap.docs.map((d) => d.id);
    if (allTokens.length === 0) {
      console.log(`Nessun device attivo per partecipanti=${chat.participants}`);
      return;
    }

    // 2) Prepara i messaggi personalizzati
    const messages: admin.messaging.Message[] = allTokens.map((token) => {
      const message: admin.messaging.Message = {
        token,
        notification: {
          title: `Nuovo match con ${senderName}! 🎉`,
          body: "Tocca per iniziare subito a chattare.",
        },
        data: {
          type: "new_chat",
          chatId,
        },
      };

      // Se l'utente ha una foto, diciamo ad Android/iOS di mostrarla
      // nella Push!
      if (senderPhoto && message.notification) {
        message.notification.imageUrl = senderPhoto;
      }

      return message;
    });

    // 3) Invia tutte le notifiche in parallelo e logga i risultati
    const results = await Promise.allSettled(
      messages.map((msg) => admin.messaging().send(msg))
    );

    const successCount = results.filter((r) => r.status === "fulfilled").length;
    const failureCount = results.length - successCount;
    console.log(
      `✅ Inviate ${successCount}/${results.length} notifiche; ` +
      `${failureCount} fallite.`
    );

    results.forEach((r, idx) => {
      if (r.status === "rejected") {
        console.warn(
          `❌ Token ${allTokens[idx]} →`,
          (r as PromiseRejectedResult).reason
        );
      }
    });
  }
);
