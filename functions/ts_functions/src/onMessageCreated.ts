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

    const chatDoc = await admin.firestore()
      .collection("chats")
      .doc(chatId)
      .get();
    if (!chatDoc.exists) return;

    const chatData = chatDoc.data();
    const participants = chatData?.participants || [];

    const receiverId = participants.find((id: string) => id !== senderId);
    if (!receiverId) return;

    // --- CONTROLLO PREFERENZE NOTIFICHE ---
    const receiverDoc = await admin
      .firestore()
      .collection("users")
      .doc(receiverId)
      .get();
    const receiverData = receiverDoc.data();

    // Se la preferenza esiste ed è esplicitamente false, non inviamo nulla!
    const wantsMessageAlerts =
      receiverData?.notificationPrefs?.newMessages ?? true;
    if (wantsMessageAlerts === false) {
      console.log(
        `L'utente ${receiverId} ha disattivato le notifiche dei messaggi. ` +
        "Abortito."
      );
      return;
    }
    // ---------------------------------------------------

    const activeChatSnap = await admin
      .database()
      .ref(`status/${receiverId}/activeChat`)
      .once("value");
    const activeChat = activeChatSnap.val();
    if (activeChat === chatId) {
      console.log(
        `L'utente ${receiverId} è già nella chat ${chatId}. ` +
        "Non invio la notifica push."
      );
      return;
    }

    const senderDoc = await admin
      .firestore()
      .collection("users")
      .doc(senderId)
      .get();
    const senderData = senderDoc.data();
    const senderName = senderData?.name || "Qualcuno";
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

    const tokensSnap = await admin.firestore().collection("tokens")
      .where("uid", "==", receiverId)
      .get();

    if (tokensSnap.empty) return;

    const allTokens = tokensSnap.docs.map((d) => d.id);

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
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
        },
      },
      apns: {
        payload: {
          aps: {
            contentAvailable: true,
            sound: "default",
          },
        },
      },
    }));

    await Promise.all(messages.map((msg) => admin.messaging().send(msg)));
  }
);
