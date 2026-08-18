const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
});

exports.sendChatNotification = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const messageData = event.data.data();

      const senderId = messageData.senderId;
      const receiverId = messageData.receiverId;
      // 🚫 Check if receiver blocked the sender
      const blockId = `${receiverId}_${senderId}`;

      const blockDoc = await admin
          .firestore()
          .collection("blocks")
          .doc(blockId)
          .get();

      if (blockDoc.exists) {
        console.log("User is blocked - notification not sent");
        return;
      }
      // 🚫 Check if receiver muted the chat
      const muteId = `${receiverId}_${senderId}`;
      const muteDoc = await admin
          .firestore()
          .collection("mutes")
          .doc(muteId)
          .get();

      if (muteDoc.exists) {
        console.log("Notifications muted for this chat");
        return;
      }

      const senderDoc = await admin
          .firestore()
          .collection("users")
          .doc(senderId)
          .get();

      const receiverDoc = await admin
          .firestore()
          .collection("users")
          .doc(receiverId)
          .get();

      if (!senderDoc.exists || !receiverDoc.exists) {
        return;
      }

      const sender = senderDoc.data();
      const receiver = receiverDoc.data();

      const token = receiver.fcmToken;

      if (!token) {
        console.log("Receiver has no FCM token");
        return;
      }

      console.log("Sender:", sender.name);
      console.log("Receiver Token:", token);

      let body = "";

      if (
        messageData.voiceUrl &&
        messageData.voiceUrl.trim() !== ""
      ) {
        body = "🎤 Voice message";
      } else if (
        messageData.imageUrl &&
        messageData.imageUrl.trim() !== ""
      ) {
        body = "📷 Photo";
      } else {
        body = messageData.message || "";
      }

      const payload = {
        notification: {
          title: sender.name,
          body: body,
        },
        token: token,
      };

      await admin.messaging().send(payload);

      console.log("Notification sent successfully");
    },
);
exports.sendCallNotification = onDocumentCreated(
    "calls/{callId}",
    async (event) => {
      const callId = event.params.callId;
      const callData = event.data.data();

      if (!callData) return;

      if (callData.status !== "calling") {
        return;
      }

      const callerId = callData.callerId;
      const receiverId = callData.receiverId;

      const callerDoc = await admin
          .firestore()
          .collection("users")
          .doc(callerId)
          .get();

      const receiverDoc = await admin
          .firestore()
          .collection("users")
          .doc(receiverId)
          .get();

      if (!callerDoc.exists || !receiverDoc.exists) {
        return;
      }

      const caller = callerDoc.data();
      const receiver = receiverDoc.data();

      const token = receiver.fcmToken;

      if (!token) {
        console.log("Receiver has no FCM token");
        return;
      }

      const callerName = caller.name || "Someone";

      const payload = {
        notification: {
          title: "📞 Incoming Call",
          body: `${callerName} is calling you`,
        },

        data: {
          type: "incoming_call",
          callId: callId,
          callerId: callerId,
          callerName: callerName,
        },

        token: token,

        android: {
          priority: "high",

          notification: {
            channelId: "incoming_calls",
            sound: "default",
            tag: "call",
          },
        },
      };

      await admin.messaging().send(payload);

      console.log(
          `📞 Incoming call notification sent: ${callId}`,
      );
    },
);
exports.sendMissedCallNotification = onDocumentUpdated(
    "calls/{callId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (!before || !after) {
        return;
      }

      // Only unanswered call:
      // calling → ended
      if (
        before.status !== "calling" ||
        after.status !== "ended"
      ) {
        return;
      }

      const callId = event.params.callId;

      const callerId = after.callerId;
      const receiverId = after.receiverId;

      const callerDoc = await admin
          .firestore()
          .collection("users")
          .doc(callerId)
          .get();

      const receiverDoc = await admin
          .firestore()
          .collection("users")
          .doc(receiverId)
          .get();

      if (!callerDoc.exists || !receiverDoc.exists) {
        return;
      }

      const caller = callerDoc.data();
      const receiver = receiverDoc.data();

      // Missed-call notification must go to B (receiver)
      const token = receiver.fcmToken;

      if (!token) {
        console.log("Receiver has no FCM token");
        return;
      }

      const callerName = caller.name || "Someone";

      const payload = {
        notification: {
          title: "📞 Missed Call",
          body: `You missed a call from ${callerName}`,
        },
        data: {
          type: "missed_call",
          callId: callId,
          callerId: callerId,
          callerName: callerName,
        },
        token: token,
        android: {
          priority: "high",
          notification: {
            channelId: "incoming_calls",
            sound: "default",
            tag: "call",
          },
        },
      };

      await admin.messaging().send(payload);

      console.log(
          `📞 Missed call notification sent: ${callId}`,
      );
    },
);
exports.deleteExpiredMoments = onSchedule(
    "every 1 hours",
    async () => {
      const db = admin.firestore();

      const cutoff = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() - 24 * 60 * 60 * 1000),
      );

      const usersSnapshot = await db
          .collection("users")
          .where("activityVisible", "==", true)
          .where("activityUpdatedAt", "<=", cutoff)
          .get();

      if (usersSnapshot.empty) {
        console.log("No expired moments found.");
        return;
      }

      const batch = db.batch();

      for (const userDoc of usersSnapshot.docs) {
        batch.update(userDoc.ref, {
          activityVisible: false,
          activity: admin.firestore.FieldValue.delete(),
          activityPhoto: admin.firestore.FieldValue.delete(),
          activityUpdatedAt: admin.firestore.FieldValue.delete(),
        });
      }

      await batch.commit();

      console.log(
          `Deleted ${usersSnapshot.size} expired moments.`,
      );
    },
);
