import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

if (!admin.apps.length) {
  admin.initializeApp();
}

interface Chat {
  participants: string[];
  createdBy?: string;
}

export const onChatCreated = onDocumentCreated(
  "chats/{chatId}",
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("No snapshot available");
      return;
    }

    const chat = snap.data() as Chat;
    const creatorId = chat.createdBy;

    if (!creatorId || !Array.isArray(chat.participants)) {
      console.log("Missing creatorId or invalid participants:", chat);
      return;
    }

    const receivers = chat.participants.filter((id) => id !== creatorId);
    if (receivers.length === 0) return;

    const {chatId} = event.params;

    // --- CONTROLLO PREFERENZE NOTIFICHE MATCH ---
    // Di solito in una chat a due, receivers[0] è l'altro utente.
    const receiverId = receivers[0];
    const receiverDoc = await admin
      .firestore()
      .collection("users")
      .doc(receiverId)
      .get();
    const receiverData = receiverDoc.data();

    // Controlliamo l'impostazione "newMatches" (di default è true)
    const wantsMatchAlerts =
      receiverData?.notificationPrefs?.newMatches ?? true;
    if (wantsMatchAlerts === false) {
      console.log(
        `L'utente ${receiverId} ha disattivato le notifiche dei match. ` +
        "Abortito."
      );
      return;
    }
    // --------------------------------------------------------

    let senderName = "Qualcuno";
    let senderPhoto = "";
    try {
      const creatorDoc = await admin
        .firestore()
        .collection("users")
        .doc(creatorId)
        .get();

      if (creatorDoc.exists) {
        const d = creatorDoc.data();
        if (d?.name) senderName = d.name;
        if (
          d?.photoUrls &&
          Array.isArray(d.photoUrls) &&
          d.photoUrls.length > 0
        ) {
          senderPhoto = d.photoUrls[0];
        } else if (d?.photoUrl) {
          senderPhoto = d.photoUrl;
        }
      }
    } catch (e) {
      console.error("Errore recupero creator:", e);
    }

    const tokensSnap = await admin.firestore()
      .collection("tokens")
      .where("uid", "in", receivers)
      .get();

    const allTokens = tokensSnap.docs.map((d) => d.id);
    if (allTokens.length === 0) {
      console.log(`Nessun device attivo per partecipanti=${chat.participants}`);
      return;
    }

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

      if (senderPhoto && message.notification) {
        message.notification.imageUrl = senderPhoto;
      }

      return message;
    });

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
        console.error(`Errore notifica ${idx}:`, r.reason);
      }
    });
  }
);
