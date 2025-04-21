/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
const { onCall, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Set Firebase Functions timeout and memory (optional)
setGlobalOptions({ maxInstances: 10 });

// ===================
// 1. HTTP Function (Simple Test)
// ===================
exports.helloSmartRoom = onRequest((req, res) => {
  logger.log("Hello SmartRoom triggered");
  res.send("SmartRoom Backend is Working!");
});

// ===================
// 2. Callable Function (User Role Management)
// ===================
exports.migrateUserClaims = onCall((request) => {
  // Secure with context.auth
  if (!request.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Only authenticated users can migrate claims"
    );
  }

  // Your migration logic here
  return { success: true, message: "Claims migration started" };
});

// ===================
// 3. Firestore Trigger (Duty Roster Updates)
// ===================
exports.logDutyRosterUpdate = onDocumentCreated(
    "dutyRoster/{rosterId}",
    (event) => {
      const snapshot = event.data;
      const data = snapshot.data();

      logger.log(`New duty roster created for room: ${data.roomNumber}`, {
        hostel: data.hostelName,
        rotation: data.taskRotation,
      });
    }
);
