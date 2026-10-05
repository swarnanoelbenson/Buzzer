const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore("busmate-db");

/**
 * Triggered when a new document is added to /notificationQueue.
 * Fetches the authorised parent FCM tokens for the student and
 * sends a push notification to each one.
 */
exports.sendParentNotification = onDocumentCreated(
  { document: "notificationQueue/{docId}", database: "busmate-db" },
  async (event) => {
    const data = event.data.data();
    if (!data || data.sent) return;

    const { studentId, title, body } = data;

    try {
      // Fetch student to get authorised parent IDs
      const studentDoc = await db.collection("students").doc(studentId).get();
      if (!studentDoc.exists) {
        console.log(`Student ${studentId} not found`);
        return;
      }

      const authorisedParentIds = studentDoc.data().authorisedParentIds || [];
      if (authorisedParentIds.length === 0) {
        console.log(`No authorised parents for student ${studentId}`);
        await event.data.ref.update({ sent: true, skipped: true });
        return;
      }

      // Fetch FCM tokens for each authorised parent
      const tokens = [];
      for (const parentId of authorisedParentIds) {
        const parentDoc = await db.collection("parents").doc(parentId).get();
        if (parentDoc.exists) {
          const token = parentDoc.data().fcmToken;
          if (token && token.length > 0) {
            tokens.push(token);
          }
        }
      }

      if (tokens.length === 0) {
        console.log(`No FCM tokens found for parents of student ${studentId}`);
        await event.data.ref.update({ sent: true, skipped: true, reason: "no_tokens" });
        return;
      }

      // Send notification to all parent tokens
      const message = {
        notification: { title, body },
        data: {
          studentId,
          status: data.status || "",
          tripType: data.tripType || "",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        tokens,
      };

      const response = await getMessaging().sendEachForMulticast(message);
      console.log(
        `Sent ${response.successCount} notifications, ${response.failureCount} failed`
      );

      // Mark as sent
      await event.data.ref.update({
        sent: true,
        sentAt: new Date(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
    } catch (error) {
      console.error("Error sending notification:", error);
      await event.data.ref.update({ sent: false, error: error.message });
    }
  }
);
