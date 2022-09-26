import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutterfire_ui/auth.dart';

import 'firebase_options.dart';

final coll = FirebaseFirestore.instance.collection('scanlets');
final functions =
    FirebaseFunctions.instanceFor(app: Firebase.app(), region: "europe-west3");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  if (kDebugMode) {
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    functions.useFunctionsEmulator('127.0.0.1', 5001);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const providerConfigs = [EmailProviderConfiguration()];

    return MaterialApp(
      initialRoute:
          FirebaseAuth.instance.currentUser == null ? '/sign-in' : '/profile',
      routes: {
        '/sign-in': (context) {
          return SignInScreen(
            providerConfigs: providerConfigs,
            actions: [
              AuthStateChangeAction<SignedIn>((context, state) {
                FirebaseAuth.instance.currentUser?.updateDisplayName(
                    FirebaseAuth.instance.currentUser?.displayName ??
                        FirebaseAuth.instance.currentUser?.email);
                Navigator.pushReplacementNamed(context, '/home');
              }),
            ],
          );
        },
        '/profile': (context) {
          return ProfileScreen(
            providerConfigs: providerConfigs,
            actions: [
              SignedOutAction((context) async {
                Navigator.pushReplacementNamed(context, '/sign-in');
              }),
            ],
            children: [
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/home'),
                child: const Text("Home"),
              )
            ],
          );
        },
        '/home': (context) => const Scaffold(body: App())
      },
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: coll.snapshots(),
        builder: (context, snapshot) => ListView(
            children: snapshot.data?.docs
                    .map((e) => ListTile(
                          title: Text(e.data()['title'] ?? "Missing"),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) =>
                                      ScanletPage(scanlet: e.reference))),
                          leading: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () async {
                              final x = await functions
                                  .httpsCallable("helloWorld")
                                  .call();
                              print(x.data);
                              final task = FirebaseStorage.instance
                                  .ref("${e.id}/item")
                                  .putString("holy moses");
                              final state = await task.asStream().firstWhere(
                                  (element) =>
                                      element.state == TaskState.success);
                              await e.reference
                                  .update({'item': state.ref.fullPath});
                            },
                          ),
                        ))
                    .toList() ??
                []));
  }
}

class ScanletPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> scanlet;
  const ScanletPage({super.key, required this.scanlet});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: scanlet.snapshots(),
        builder: (context, snapshot) {
          return Scaffold(
            body: Column(
              children: [
                Text(snapshot.data?.data()?['title'] ?? "missing title"),
                FutureBuilder(
                    future: FirebaseStorage.instance
                        .ref(snapshot.data?.data()?['item'] ?? '')
                        .getData(),
                    builder: ((context, snapshot) => Text(String.fromCharCodes(
                        (snapshot.data ??
                            Uint8List.fromList("no items".codeUnits))))))
              ],
            ),
          );
        });
  }
}
