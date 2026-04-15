import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintScreen extends StatefulWidget {
  @override
  _ImprintScreenState createState() => _ImprintScreenState();
}

class _ImprintScreenState extends State<ImprintScreen> {
  final WebViewController webViewController = WebViewController()
    ..loadRequest(
        Uri.parse('https://www.munichways.de/datenschutzerklaerung/'));

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Impressum"),
      ),
      body: WebViewWidget(
        controller: webViewController,
      ),
    );
  }
}
