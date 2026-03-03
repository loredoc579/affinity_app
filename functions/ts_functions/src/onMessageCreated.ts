import * as admin from "firebase-admin";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data();
    const senderId = messageData.senderId;
    const text = messageData.text;
    const {chatId} = event.params;

    // 1. Recupera i dati della chat per capire chi è il destinatario
    const chatDoc = await admin.firestore()
      .collection("chats")
      .doc(chatId)
      .get();
    if (!chatDoc.exists) return;

    const chatData = chatDoc.data();
    const participants = chatData?.participants || [];

    // Trova l'ID di chi DEVE ricevere la notifica (cioè non il mittente)
    const receiverId = participants.find((id: string) => id !== senderId);
    if (!receiverId) return;

    // --- NUOVO CONTROLLO: L'UTENTE È GIÀ NELLA CHAT? ---
    const activeChatSnap = await admin
      .database()
      .ref(`status/${receiverId}/activeChat`)
      .once("value");
    const activeChat = activeChatSnap.val();
    if (activeChat === chatId) {
      console.log(
        `L'utente ${receiverId} è già nella chat ${chatId}. ` +
        "Salto la notifica push."
      );
      return; // Blocchiamo la notifica alla radice!
    }

    // Recupera anche il nome del mittente per un bel popup
    const senderDoc = await admin
      .firestore()
      .collection("users")
      .doc(senderId)
      .get();
    const senderName = senderDoc.data()?.name || "Un utente";

    const senderData = senderDoc.data();
    let senderPhoto = "";
    if (
      senderData?.photoUrls &&
      Array.isArray(senderData.photoUrls) &&
      senderData.photoUrls.length > 0
    ) {
      senderPhoto = senderData.photoUrls[0];
    } else if (senderData?.photoUrl) {
      senderPhoto = senderData.photoUrl;
    }

    // 2. Prendi il token FCM del destinatario
    const tokensSnap = await admin.firestore().collection("tokens")
      .where("uid", "==", receiverId)
      .get();

    if (tokensSnap.empty) return;

    const allTokens = tokensSnap.docs.map((d) => d.id);

    // 3. Invia la notifica Push con PRIORITÀ ALTA
    const messages: admin.messaging.Message[] = allTokens.map((token) => ({
      token,
      notification: {
        title: `Nuovo messaggio da ${senderName}`,
        body: text.length > 30 ? text.substring(0, 30) + "..." : text,
      },
      data: {
        type: "new_message",
        chatId: chatId,
        otherUserId: senderId,
        otherUserName: senderName,
        otherUserPhotoUrl: senderPhoto,
      },
      // --- IL TURBO PER ANDROID ---
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          // Opzionale, utile per Android 8+
        },
      },
      // --- IL TURBO PER IOS ---
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          },
        },
      },
    }));

    await Promise.allSettled(
      messages.map((msg) => admin.messaging().send(msg))
    );
  }
);
