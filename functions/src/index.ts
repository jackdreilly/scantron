import * as functions from "firebase-functions";

// Start writing Firebase Functions
// https://firebase.google.com/docs/functions/typescript

const region = functions.region("europe-west3");
export const helloWorld = region.https.onCall(() => "hi");

export const onScanletCreated = functions.firestore.document("/scanlets")
  .onCreate(async (snapshot, context) => {
  });
