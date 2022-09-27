import * as admin from "firebase-admin";
import {firestore, messaging} from "firebase-admin";
import * as functions from "firebase-functions";
admin.initializeApp();

const region = functions.region("europe-west3");
export const helloWorld = region.https.onCall(() => "hi");

export const onScanletCreated = region.firestore
    .document("scanlets/{scanlet_id}")
    .onCreate((snapshot) =>
      blastNotification({
        title: "New scanlet posted!",
        body: snapshot.data()?.title ?? "no title",
      })
    );

/**
 * Blasts notifications to everyone.
 * @param {messaging.NotificationMessagePayload} content content to inject into
 * notification
 * @return {Promise<firestore.WriteResult[]>} deletion results of bad tokens
 */
async function blastNotification(
    content: messaging.NotificationMessagePayload,
): Promise<firestore.WriteResult[]> {
  functions.logger.info({blasting: content});
  const documents = await admin.firestore().collection("fcm_tokens").get();
  const validDocs = documents.docs.filter((d) => !!d.data()?.token);
  const tokens = validDocs.map((d) => d.data()?.token);
  functions.logger.info({tokens});
  const response = await admin.messaging().sendToDevice(tokens, {
    notification: content,
  });
  functions.logger.info({
    responses: [response.results.map((r) => r.messageId)],
  });
  const tokensToRemove: Promise<firestore.WriteResult>[] = [];
  response.results.forEach((result, index) => {
    const error = result.error;
    if (error) {
      functions.logger.error(
          "Failure sending notification to",
          tokens[index],
          error,
      );
      // Cleanup the tokens who are not registered anymore.
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(validDocs[index].ref.delete());
      }
    }
  });
  return Promise.all(tokensToRemove);
}
export const onCommentCreated = region.firestore
    .document("scanlets/{scanlet_id}/comments/{comment_id}")
    .onCreate(async (snapshot) => {
      const scanletRef = snapshot.ref.parent.parent;
      const scanlet = await scanletRef?.get();
      const title = scanlet?.data()?.title;
      blastNotification({
        title: `New Comment on ${title}`,
        body: snapshot.data()?.comment,
      });
    });
