import 'dart:io';

import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:munich_ways/nav_routes.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class InfoScreen extends StatefulWidget {
  @override
  _InfoScreenState createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String appVersion = "";
  String appName = "";
  String packageName = "";
  GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();

    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      log.d(packageInfo);
      setState(() {
        appName = packageInfo.appName;
        packageName = packageInfo.packageName;
        String version = packageInfo.version;
        String buildNumber = packageInfo.buildNumber;
        this.appVersion =
            '$version($buildNumber) ${Platform.isIOS ? "iOS" : "Android"}';
      });
    });
  }

  void _displayError(String errorMsg) {
    scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
      content: Text(errorMsg),
      duration: Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Scaffold(
        drawer: SideDrawer(),
        appBar: AppBar(
          title: Text("Über die App"),
        ),
        body: ListView(
          children: ListTile.divideTiles(
            context: context,
            tiles: [
              ListTile(
                title: Text("$appName $appVersion"),
                subtitle: Text('munichways.de'),
                trailing: Icon(Icons.link),
                onTap: () async {
                  const url = 'https://munichways.de';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url);
                  } else {
                    _displayError(
                        'Keine App zum öffnen von munichways.de gefunden');
                  }
                },
              ),
              ListTile(
                title: Text('RadlNavi'),
                subtitle: Text('radlnavi.de'),
                trailing: Icon(Icons.link),
                onTap: () async {
                  const url = 'https://radlnavi.de';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url);
                  } else {
                    _displayError(
                        'Keine App zum öffnen von radlnavi.de gefunden');
                  }
                },
              ),
              ListTile(
                title: Text('Feedback'),
                trailing: Icon(Icons.mail),
                subtitle: Text(
                    'Du hast einen Fehler entdeckt? oder eine Verbesserungsidee? Sende uns Feedback per Email an mail@munichways.de.'),
                onTap: () async {
                  final Uri _emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'mail@munichways.de',
                      query:
                          'subject=Feedback Munichways App&body=Appversion: $appVersion\n\n');
                  if (!await launchUrl(_emailLaunchUri,
                      mode: LaunchMode.externalApplication)) {
                    _displayError(("Keine Email App gefunden"));
                  }
                },
              ),
              ListTile(
                title: Text('Impressum & Datenschutz'),
                subtitle: Text('munichways.de/datenschutzerklaerung'),
                trailing: Icon(Icons.info_outline),
                onTap: () async {
                  Navigator.of(context).pushNamed(NavRoutes.imprint);
                },
              ),
              ListTile(
                title: Text('Nutzungsbedingungen'),
                subtitle: Text('munichways.de/nutzungbedingungen-app'),
                trailing: Icon(Icons.info_outline),
                onTap: () async {
                  const url = 'https://munichways.de/nutzungbedingungen-app';
                  if (await canLaunchUrlString(url)) {
                    await launchUrlString(url);
                  } else {
                    _displayError(
                        'Keine App zum öffnen von munichways.de/nutzungbedingungen-app gefunden');
                  }
                },
              ),
              ListTile(
                title: Text('Details zu einer Strecke'),
                subtitle: Text(
                    'Klicke auf eine Strecke auf der Karte für mehr Details'),
                trailing: Icon(Icons.touch_app),
                onTap: () {
                  Navigator.pushNamed(context, NavRoutes.map);
                },
              ),
            ],
          ).toList(),
        ),
      ),
    );
  }
}
