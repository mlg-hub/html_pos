import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shelf_router/shelf_router.dart' as Rtr;
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shelf/shelf.dart';
import 'dart:async' show Future;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/server.dart';

void main() async {
  runApp(const MyApp());
}

class Service {
  // The [Router] can be used to create a handler, which can be used with
  // [shelf_io.serve].
  Handler get handler {
    final router = Rtr.Router();

    // Handlers can be added with `router.<verb>('<route>', handler)`, the
    // '<route>' may embed URL-parameters, and these may be taken as parameters
    // by the handler (but either all URL parameters or no URL parameters, must
    // be taken parameters by the handler).
    router.get('/say-hi/<name>', (Request request, String name) {
      return Response.ok('hi $name');
    });

    // Embedded URL parameters may also be associated with a regular-expression
    // that the pattern must match.
    router.get('/user/<userId|[0-9]+>', (Request request, String userId) {
      return Response.ok('User has the user-number: $userId');
    });

    // Handlers can be asynchronous (returning `FutureOr` is also allowed).
    router.get('/wave', (Request request) async {
      await Future<void>.delayed(Duration(milliseconds: 100));
      return Response.ok('_o/');
    });

    // Other routers can be mounted...
    router.mount('/api/', Api().router);

    // You can catch all verbs and use a URL-parameter with a regular expression
    // that matches everything to catch app.
    router.all('/<ignored|.*>', (Request request) {
      return Response.notFound('Page not found');
    });

    return router;
  }
}

class Api {
  final corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };
  Future<Response> _messages(Request request) async {
    return Response.ok(
        jsonEncode({"success": true, "message": "everything is good."}),
        headers: {'Content-Type': 'application/json', ...corsHeaders});
  }

  // By exposing a [Router] for an object, it can be mounted in other routers.
  Rtr.Router get router {
    final router = Rtr.Router();

    // A handler can have more that one route.
    router.get('/messages', _messages);
    router.get('/messages/', _messages);

    // This nested catch-all, will only catch /api/.* when mounted above.
    // Notice that ordering if annotated handlers and mounts is significant.
    router.all('/<ignored|.*>', (Request request) => Response.notFound('null'));

    return router;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  Future<String?> getDownloadPath() async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        // Put file in global download folder, if for an unknown reason it didn't exist, we fallback
        // ignore: avoid_slow_async_io
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (err, stack) {
      print("Cannot get download folder path $stack");
    }
    return directory?.path;
  }

  server() async {
    final service = Service();
    final pat = await getDownloadPath();
    // print(pat);
    // if (!FileSystemEntity.isFileSync(pat! + "/assets/index.html")) {
    //   print("not file");
    // } else {
    //   print("good file");
    // }

    await Permission.storage.request();
    var handler = createStaticHandler("${pat!}/assets",
        defaultDocument: 'index.html', serveFilesOutsidePath: true);
    final server = await shelf_io.serve(handler, "192.168.0.110", 8080);
    final server2 =
        await shelf_io.serve(service.handler, '192.168.0.110', 8000);

    debugPrint('Server running on ${server.address}:${server.port}');
    debugPrint('Server running on ${server2.address}:${server2.port}');
    // final appServer = AppServer(
    //   hostname: InternetAddress("192.168.43.7" ?? "0.0.0.0"),
    // );
    // appServer.startServer();
  }

  Future<String?> gettingIP() async {
    await Permission.location.request();
    final info = NetworkInfo();
    var hostAddress = await info.getWifiIP();
    print("called $hostAddress");
    return hostAddress;
  }

  @override
  Widget build(BuildContext context) {
    server();
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FutureBuilder(
                future: gettingIP(),
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return SizedBox(
                      child: Text(snapshot.data ?? ""),
                    );
                  }
                  return const SizedBox();
                }),
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
