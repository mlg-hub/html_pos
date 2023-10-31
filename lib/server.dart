import 'dart:convert';
import 'dart:io';

class AppServer {
  HttpServer? server;
  final InternetAddress hostname;

  AppServer({required this.hostname});

  startServer() async {
    try {
      server = await HttpServer.bind(hostname, 4040, shared: true);

      server!.listen((request) {
        //debugPrint("new request is here");
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers
            .add('Access-Control-Allow-Methods', 'POST,GET,DELETE,PUT,OPTIONS');
        _handleRequest(request);
      });

      print(
          "Server is listening at port: ${server!.address.host}:${server!.port.toString()}");
      return true;
    } catch (_) {
      return false;
    }
  }

  stopServer() async {
    try {
      if (server != null) {
        await server!.close();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  _handleRequest(HttpRequest request) async {
    print("Request reveived");
    switch (request.method) {
      case "POST":
        request.response.write(jsonEncode([
          {"mama": true}
        ]));
        request.response.close();
        break;
      case "GET":
        request.response.write(jsonEncode([
          {"message": "get is good"}
        ]));
        request.response.close();
        break;
      default:
        request.response.write([]);
        request.response.close();
    }
  }
}
