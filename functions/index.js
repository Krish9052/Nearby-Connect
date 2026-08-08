const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
