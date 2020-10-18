import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ImprintScreen extends StatefulWidget {
  @override
  _ImprintScreenState createState() => _ImprintScreenState();
}

class _ImprintScreenState extends State<ImprintScreen> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Impressum"),
      ),
      body: WebView(
        initialUrl: 'https://www.munichways.com/datenschutzerklaerung/',
      ),
    );
  }
}
