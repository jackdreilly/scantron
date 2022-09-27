import * as admin from "firebase-admin";
import {firestore} from "firebase-admin";
import * as functions from "firebase-functions";
admin.initializeApp();

const region = functions.region("europe-west3");
export const helloWorld = region.https.onCall(() => "hi");

export const onScanletCreated = region.firestore
    .document("/scanlets")
    .onCreate(async (snapshot) => {
      const documents = await admin.firestore().collection("fcm_tokens").get();
      const validDocs = documents.docs.filter((d) => !!d.data()?.token);
      const tokens = validDocs.map((d) => d.data()?.token);
      const response = await admin.messaging().sendToDevice(tokens, {
        notification: {
          title: "New scanlet posted!",
          body: snapshot.data()?.title ?? "no title",
        },
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
    });
