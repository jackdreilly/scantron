// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scantron/markdown_editor/widgets/markdown_form_field.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'firebase_options.dart';

final coll = FirebaseFirestore.instance.collection('scanlets');
final functions =
    FirebaseFunctions.instanceFor(app: Firebase.app(), region: "europe-west3");

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    await FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
    functions.useFunctionsEmulator('127.0.0.1', 5001);
  }
  FirebaseMessaging.onBackgroundMessage(handleMessage);
  FirebaseMessaging.onMessage.forEach(handleMessage);
  FirebaseMessaging.onMessageOpenedApp.forEach(handleMessage);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
          providers: [
            StreamProvider<User?>(
                create: (_) => MergeStream([
                      FirebaseAuth.instance.userChanges(),
                      FirebaseAuth.instance.authStateChanges()
                    ]).distinctUnique(),
                initialData: FirebaseAuth.instance.currentUser),
            StreamProvider<Scanlets>(
                create: (_) =>
                    coll.orderBy('created_at', descending: false).snapshots(),
                initialData: null)
          ],
          child: MaterialApp(
              theme: ThemeData(primarySwatch: Colors.teal),
              navigatorObservers: kDebugMode
                  ? []
                  : [
                      FirebaseAnalyticsObserver(
                          analytics: FirebaseAnalytics.instance),
                    ],
              home: MultiProvider(providers: [
                StreamProvider<User?>(
                    create: (_) => FirebaseAuth.instance.userChanges(),
                    initialData: FirebaseAuth.instance.currentUser),
                StreamProvider<Scanlets>(
                    create: (_) => coll
                        .orderBy('created_at', descending: false)
                        .snapshots(),
                    initialData: null)
              ], child: const App())));
}

typedef ScanletData = Map<String, dynamic>;
typedef Scanlets = QuerySnapshot<ScanletData>?;

Scanlets getScanlets(BuildContext context, {bool listen = true}) =>
    Provider.of(context, listen: listen);
User? getUser(BuildContext context, {bool listen = true}) =>
    Provider.of(context, listen: listen);

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller1 = TextEditingController();
    final controller2 = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: Text("Login"),
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ElevatedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => RegisterPage())),
                  icon: Icon(Icons.person_add),
                  label: Text("Register New Account")),
              TextField(
                controller: controller1,
                decoration: InputDecoration(label: Text("Email")),
              ),
              TextField(
                controller: controller2,
                decoration: InputDecoration(label: Text("Password")),
              ),
              ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: controller1.text, password: controller2.text);
                    await updateToken();
                    goHome(navigator);
                  },
                  icon: Icon(Icons.login),
                  label: Text("Login"))
            ].separatedBy(SizedBox(height: 10)).toList(),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller1 = TextEditingController();
    final controller2 = TextEditingController();
    return Scaffold(
      appBar: AppBar(
        title: Text("Register account"),
      ),
      body: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: controller1,
                decoration: InputDecoration(label: Text("Email")),
              ),
              TextField(
                controller: controller2,
                decoration: InputDecoration(label: Text("Password")),
              ),
              ElevatedButton.icon(
                  onPressed: () => FirebaseAuth.instance
                      .createUserWithEmailAndPassword(
                          email: controller1.text, password: controller2.text)
                    ..then((_) => updateToken())
                        .then((value) => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfilePage(),
                            ))),
                  icon: Icon(Icons.check),
                  label: Text("Submit"))
            ]
                .separatedBy(SizedBox(
                  height: 10,
                ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class PersonButton extends StatelessWidget {
  const PersonButton({super.key});

  @override
  Widget build(BuildContext context) {
    return getUser(context) == null
        ? IconButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (context) => LoginPage())),
            icon: Icon(Icons.login))
        : IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => ProfilePage())),
            icon: Icon(Icons.person));
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text("The ScanTron"), actions: const [PersonButton()]),
        body: Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ScanRows(),
              ),
            ),
          ),
        ));
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    final user_ = getUser(context);
    if (user_ == null) {
      return Scaffold(body: Text("Error: go back"));
    }
    final user = user_;
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("email: ${user.email}"),
              Text("name: ${user.displayName}"),
              TextField(
                controller: controller,
                decoration: InputDecoration(label: Text("Change name")),
              ),
              ElevatedButton.icon(
                  onPressed: () => user
                      .updateDisplayName(controller.text)
                      .then((value) => controller.text = ""),
                  icon: Icon(Icons.check),
                  label: Text("Submit name")),
              user.emailVerified
                  ? Text("Email is verified")
                  : ElevatedButton.icon(
                      icon: Icon(Icons.email),
                      label: Text("Send verification email (Check spam!!!)"),
                      onPressed: () => user.sendEmailVerification().then(
                          (_) => snack(context, "Email sent, check spam!")),
                    ),
              ElevatedButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await FirebaseAuth.instance.signOut();
                    goHome(navigator);
                  },
                  icon: Icon(Icons.logout),
                  label: Text("Logout"))
            ]
                .separatedBy(SizedBox(
                  height: 10,
                ))
                .toList()),
      ),
    );
  }
}

class ScanRows extends StatelessWidget {
  const ScanRows({super.key});

  @override
  Widget build(BuildContext context) {
    final scanlets = getScanlets(context);
    return Column(
        children: scanlets?.docs
                .slices(4)
                .map<Widget>((e) => Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ScanletRow(e),
                    ))
                .followedBy(
                    scanlets.docs.length % 4 == 0 ? [ScanletRow(const [])] : [])
                .separatedBy(Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    height: 1,
                    color: Colors.grey,
                  ),
                ))
                .toList() ??
            []);
  }
}

class ScanletRow extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> scanlets;
  const ScanletRow(this.scanlets, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: scanlets
            .map<Widget>((e) => ScanletItem(e))
            .followedBy(Iterable.generate(
                4 - scanlets.length, (_) => CreateScanletItem()))
            .toList());
  }
}

class CreateScanletItem extends StatelessWidget {
  const CreateScanletItem({super.key});

  @override
  Widget build(BuildContext context) {
    final user = getUser(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen),
      child: Icon(Icons.edit),
      onPressed: () => user != null
          ? Navigator.push(context,
              MaterialPageRoute(builder: (context) => NewScanletPage()))
          : snack(context, "Must log in first"),
    );
  }
}

snack(BuildContext context, String s) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
}

class NewScanletPage extends StatefulWidget {
  const NewScanletPage({super.key});

  @override
  State<NewScanletPage> createState() => _NewScanletPageState();
}

class _NewScanletPageState extends State<NewScanletPage> {
  List<PlatformFile> files = [];
  bool loading = false;
  double progress = 1;
  final controller = TextEditingController();
  final markdownController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final user = getUser(context);
    return Scaffold(
      appBar: AppBar(title: Text("New Scanlet")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              LinearProgressIndicator(value: progress < 1 ? progress : null),
            TextField(
              controller: controller,
              decoration: InputDecoration(label: Text("Scanlet Name")),
            ),
            Text("Markdown (links, description...)"),
            SafeArea(
              child: SizedBox(
                height: 500,
                child: MarkdownFormField(
                  controller: markdownController,
                  enableToolBar: true,
                  emojiConvert: true,
                  autoCloseAfterSelectEmoji: false,
                ),
              ),
            ),
            Row(
              children: [
                ElevatedButton.icon(
                    onPressed: () => FilePicker.platform.pickFiles().then(
                        (value) =>
                            setState(() => files.addAll(value?.files ?? []))),
                    icon: Icon(Icons.file_upload),
                    label: Text("Upload Files")),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("${files.length} files selected"),
                ),
              ],
            ),
            ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    loading = true;
                  });
                  final navigator = Navigator.of(context);
                  final ref = await coll.add({
                    'title': controller.text,
                    'userDisplay': user?.displayName ?? user?.email,
                    'user_id': user?.uid,
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                    'markdown': markdownController.text,
                  });
                  final uploads = await Future.wait(
                      files.mapIndexed((index, element) async {
                    final storageRef = FirebaseStorage.instance
                        .ref()
                        .child("scanlets")
                        .child(ref.id)
                        .child('uploads')
                        .child(index.toString())
                        .child(element.name);
                    final lastEvent = await storageRef
                        .putData(element.bytes ?? Uint8List.fromList([]));
                    return lastEvent.ref.fullPath;
                  }));
                  await ref.update({'uploads': uploads});
                  await navigator.pushReplacement(MaterialPageRoute(
                      builder: (context) => ScanletPage(ref)));
                },
                label: Text("Create Scanlet"),
                icon: Icon(Icons.create))
          ].separatedBy(SizedBox(height: 10)).toList(),
        ),
      ),
    );
  }
}

class ScanletItem extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> scanlet;
  const ScanletItem(this.scanlet, {super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: Text(scanlet.data()?['title'] ?? "Missing title"),
      onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ScanletPage(scanlet.reference))),
    );
  }
}

class ScanletPage extends StatelessWidget {
  final DocumentReference<ScanletData> reference;
  const ScanletPage(this.reference, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<ScanletData>>(
        stream: reference.snapshots(),
        builder: (context, snapshot) {
          final scanlet = snapshot.data;
          if (scanlet == null) {
            return Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Loading"),
              ),
            );
          }
          return Scaffold(
              appBar: AppBar(
                  title: Text(scanlet.data()?['title'] ?? "Missing title")),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                            "Author: ${scanlet.data()?['userDisplay'] ?? 'missing'}"),
                        Text(
                            "Created At: ${scanlet.data()?['created_at'] ?? 'missing'}"),
                        Row(
                          children: <Widget>[
                            ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            ScanletCommentsPage(reference))),
                                icon: Icon(Icons.comment),
                                label: Text("Comments")),
                            if (scanlet.isUser(context: context))
                              ElevatedButton.icon(
                                  onPressed: () async {
                                    final navigator = Navigator.of(context);
                                    await reference.delete();
                                    goHome(navigator);
                                  },
                                  icon: Icon(Icons.delete),
                                  label: Text("Delete"))
                          ].separatedBy(SizedBox(width: 10)).toList(),
                        ),
                        Card(
                          child: Markdown(
                            data: scanlet.data()?['markdown'] ?? '',
                            shrinkWrap: true,
                            onTapLink: ((text, href, title) =>
                                href != null ? launchUrlString(href) : null),
                          ),
                        ),
                        Text("Uploads"),
                        ...(scanlet.data()?['uploads'] ?? []).map((e) =>
                            FutureBuilder<String>(
                                future: FirebaseStorage.instance
                                    .ref(e.toString())
                                    .getDownloadURL(),
                                builder: (context, snapshot) => snapshot.data ==
                                        null
                                    ? Container()
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              onPressed: () {
                                                launchUrlString(snapshot.data!);
                                              },
                                              icon: Icon(Icons.download)),
                                          if ([
                                            'jpeg',
                                            'jpg',
                                            'png',
                                            'gif'
                                          ].any((suffix) =>
                                              e.toString().endsWith(suffix)))
                                            ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxHeight: 500,
                                                    maxWidth: 500),
                                                child: Image.network(
                                                    snapshot.data!)),
                                          if ([
                                            'wav',
                                            'mp3',
                                            'mp4'
                                          ].any((suffix) =>
                                              e.toString().endsWith(suffix)))
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                AudioWidget(snapshot.data!),
                                              ],
                                            ),
                                          Text(e.toString().split('/').last)
                                        ],
                                      )))
                      ]
                          .separatedBy(SizedBox(
                            height: 10,
                          ))
                          .toList()),
                ),
              ));
        });
  }
}

class AudioWidget extends StatefulWidget {
  final String url;
  const AudioWidget(this.url, {super.key});

  @override
  State<AudioWidget> createState() => _AudioWidgetState();
}

class _AudioWidgetState extends State<AudioWidget> {
  final player = AudioPlayer();
  bool playing = false;

  @override
  void initState() {
    super.initState();
    player.setUrl(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          playing ? player.pause() : player.play();
          setState(() {
            playing = !playing;
          });
        },
        icon: Icon(playing ? Icons.pause : Icons.play_arrow));
  }
}

goHome(NavigatorState navigator) {
  navigator.popUntil((e) => e.isFirst);
}

class ScanletCommentsPage extends StatefulWidget {
  final DocumentReference reference;

  const ScanletCommentsPage(this.reference, {super.key});

  @override
  State<ScanletCommentsPage> createState() => _ScanletCommentsPageState();
}

class _ScanletCommentsPageState extends State<ScanletCommentsPage> {
  final controller = TextEditingController();
  CollectionReference get comments => widget.reference.collection('comments');
  @override
  Widget build(BuildContext context) {
    final user = getUser(context);
    return Scaffold(
      appBar: AppBar(title: Text("Comments")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
                onSubmitted: (value) {
                  comments.add({
                    'comment': controller.text,
                    'userDisplay': user?.displayName ?? user?.email,
                    'user_id': user?.uid,
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  });
                  controller.text = "";
                },
                controller: controller,
                decoration: InputDecoration(label: Text("New Comment"))),
            Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.reference
                  .collection('comments')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              initialData: null,
              builder: (context, snapshot) => ListView(
                  children: snapshot.data?.docs
                          .map((e) => ListTile(
                                title:
                                    Text(e.data()['comment'] ?? 'no comment'),
                                leading:
                                    Text(e.data()['userDisplay'] ?? 'no user'),
                                subtitle:
                                    Text(e.data()['created_at'] ?? 'no date'),
                                trailing: e.isUser(user: user)
                                    ? IconButton(
                                        onPressed: () => e.reference.delete(),
                                        icon: Icon(Icons.delete))
                                    : null,
                              ))
                          .toList() ??
                      []),
            ))
          ],
        ),
      ),
    );
  }
}

Future<void> handleMessage(RemoteMessage message) async {
  print([
    message,
    ('was here!!!!'),
    (message.data),
    (message.from),
    (message.sentTime)
  ]);
}

Future updateToken() async {
  await FirebaseFirestore.instance
      .collection('fcm_tokens')
      .doc(FirebaseAuth.instance.currentUser?.uid)
      .set({'token': await FirebaseMessaging.instance.getToken()},
          SetOptions(merge: true));
}

extension<T> on Iterable<T> {
  Iterable<T> separatedBy(T separator) sync* {
    if (isEmpty) {
      return;
    }
    yield first;
    for (final v in skip(1)) {
      yield separator;
      yield v;
    }
  }
}

extension on DocumentSnapshot<Map<String, dynamic>> {
  bool isUser({User? user, BuildContext? context}) {
    if (context != null) {
      user ??= getUser(context);
    }
    return user != null && user.uid == data()?['user_id'];
  }
}
