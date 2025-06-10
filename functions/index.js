const admin = require("firebase-admin");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

admin.initializeApp();

console.log("Messaging projectId:", admin.app().options.projectId);
console.log("Admin options:", JSON.stringify(admin.app().options, null, 2));
console.log("env GCP_PROJECT         :", process.env.GCP_PROJECT);
console.log("env GCLOUD_PROJECT      :", process.env.GCLOUD_PROJECT);
console.log("env GOOGLE_CLOUD_PROJECT:", process.env.GOOGLE_CLOUD_PROJECT);
console.log("FIREBASE_CONFIG         :", process.env.FIREBASE_CONFIG);
console.log("admin.app().options     :", admin.app().options);

exports.onChatCreated = onDocumentCreated(
    "chats/{chatId}",
    async (event) => {
    // 1) event.data might be undefined
      const snap = event.data;
      if (!snap) {
        console.log("No snapshot available");
        return;
      }

      // 2) Call .data() to get the actual document fields
      const doc = snap.data();
      if (!doc) {
        console.log("Snapshot has no data()");
        return;
      }

      const participants = doc.participants;
      if (!Array.isArray(participants)) {
        console.log("Missing or invalid participants field:", participants);
        return;
      }

      // Fetch all FCM tokens for each participant
      const tokensNested = await Promise.all(
          participants.map(async (uid) => {
            const qs = await admin
                .firestore()
                .collection("users")
                .doc(uid)
                .collection("fcmTokens")
                .get();
            return qs.docs.map((d) => d.id);
          }),
      );

      // Flatten and send
      const allTokens = tokensNested.flat();
      if (allTokens.length > 0) {
        // Costruiamo un array di Promise, una per ogni token
        const sendPromises = allTokens.map((token) =>
          admin.messaging().send({
            token,
            notification: {
              title: "È match! 🎉",
              body: "Hai una nuova conversazione. Vai a vedere!",
            },
            // opzionale: aggiungi .data, .android, .apns…
          }),
        );

        // E le eseguiamo in parallelo
        const results = await Promise.allSettled(sendPromises);

        // Loggiamo un breve report
        const sc = results.filter((r) => r.status === "fulfilled").length;
        const fc = results.length - sc;
        console.log(`✅ Send ${sc}/${results.length} notifies; ${fc} failed.`);
        results.forEach((r, i) => {
          if (r.status === "rejected") {
            console.warn(` ❌ Token ${allTokens[i]} →`, r.reason);
          } else {
            console.log(` ✅ Token ${allTokens[i]} →`, r.value);
          }
        });
      }
    },
);
