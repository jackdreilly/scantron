importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyBZJXtWhVayBne4g_-1JjoO9WKo-BWlfOA",
  authDomain: "reilly-scantron.firebaseapp.com",
  projectId: "reilly-scantron",
  storageBucket: "reilly-scantron.appspot.com",
  messagingSenderId: "788690092461",
  appId: "1:788690092461:web:e865be1c1dc3cb13a8a124",
  measurementId: "G-20FMRBSV5R"
});
// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});