import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_esc_pos_network/flutter_esc_pos_network.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  InAppWebViewSettings settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
  );

  String? iPaddress;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(title: const Text("JavaScript Handlers")),
          body: SafeArea(
              child: Column(children: <Widget>[
            Container(
                margin: const EdgeInsets.all(20),
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Printer IP address',
                  ),
                  onChanged: (text) {
                    setState(() {
                      iPaddress = text;
                      //you can access nameController in its scope to get
                      // the value of text entered as shown below
                      //fullName = nameController.text;
                    });
                  },
                )),
            Expanded(
              child: InAppWebView(
                initialData: InAppWebViewInitialData(data: """
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0">
        <script>
          let text = ''; 
          let isFlutterInAppWebViewReady = false;
          window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
            console.log("isFlutterInAppWebViewReady : true");
              isFlutterInAppWebViewReady = true;
          });

          function printMe() {
              if (isFlutterInAppWebViewReady) {
              const args = [{"data": "You print via html"}, "  You print via html"];
              window.flutter_inappwebview.callHandler('PRNTME', ...args);
            }
          }
        </script>
    </head>
    <body>
        <h1>Printer Handlers</h1>
        <button onclick="printMe()">Print me</button>
    </body>
    
</html>
"""),
                initialSettings: settings,
                onWebViewCreated: (controller) {
                  controller.addJavaScriptHandler(
                      handlerName: 'PRNTME',
                      callback: (args) async {
                        log(args[1]);
                        List<int> ticket = await testTicket(args[1]);
                        printNetwork(iPaddress!, ticket);
                        // it will print: [1, true, [bar, 5], {foo: baz}, {bar: bar_value, baz: baz_value}]
                      });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  log(consoleMessage.toString());
                  // it will print: {message: {"bar":"bar_value","baz":"baz_value"}, messageLevel: 1}
                },
              ),
            ),
          ]))),
    );
  }
}

void printNetwork(String ip, List<int> ticket) async {
  final printer = PrinterNetworkManager(ip);
  PosPrintResult connect = await printer.connect();
  if (connect == PosPrintResult.success) {
    PosPrintResult printing = await printer.printTicket(ticket);
    print(printing.msg);
    printer.disconnect();
  }
}

Future<List<int>> testTicket(String text) async {
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);
  List<int> bytes = [];
  bytes += generator.text(text);
  return bytes;
}
