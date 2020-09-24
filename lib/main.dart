import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/ui/map/map_app_bar.dart';

import 'control/geojsonroutes.dart';

const STACHUS = [48.14, 11.5652];

const LAYERID = "WHICH_LAYERID_OUGHT_TO_APPLY";
const LHM =
    "https://cartocdn-gusc-c.gloabl.ssl.fastly.net/usocialmapls/api/V1/MAP/USOCIALMAPS@" +
        LAYERID +
        "/1,2,3,4,5,/{Z}/{X}/{Y}.png";
const OPENPT = "http://openptmap.org/tiles/{z}/{x}/{y}.png";
const GEOJSONENDPOINTS = {
  "vorrangnetz": {
    "url": "https://www.munichways.com/App/radlvorrangnetz.geojson",
    "width": 5,
    "pattern": {"type": "POLYLINE_PATTERN_DOTTED", "gapLength": 2}
  },
  "gesamtnetz": {
    "url": "https://www.munichways.com/App/gesamtnetz.geojson",
    "width": 5,
    "pattern": {
      "type": "POLYLINE_PATTERN_DASHED",
      "dashLength": 3,
      "gapLength": 5
    }
  }
};

Set<Marker> _markerSet = {};
Set<Polyline> _polylines_vorrangnetz;
Set<Polyline> _polylines_gesamtnetz;
Set<Polyline> _polylines;

bool isChecked = false;

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with Routes {
  GoogleMapController mapController;
  final LatLng _center = LatLng(STACHUS[0], STACHUS[1]);

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
      var Overlays = {};
    });
  }

  void initState() {
    GEOJSONENDPOINTS.forEach((networkKey, networkValue) async {
      if (networkKey.toString() == "vorrangnetz") {
        await for (var i in getNetworks(networkKey, networkValue)) {
          _polylines_vorrangnetz = i;
        }
        ;
      }
    });
    GEOJSONENDPOINTS.forEach((networkKey, networkValue) async {
      if (networkKey.toString() == "gesamtnetz") {
        await for (var i in getNetworks(networkKey, networkValue)) {
          _polylines_gesamtnetz = i;
        }
        ;
      }
    });
  }

  String _selectedChoice;

  void _select(String choice) {
    setState(() {
      _selectedChoice = choice;
      switch (_selectedChoice) {
        case "RadlvorrangNetz":
          _polylines = _polylines_vorrangnetz;
          break;
        case "Gesamtnetz":
          setState(() {
            bool newValue = false;
            if (isChecked == true) {
              newValue = false;
              _polylines_gesamtnetz.forEach((element) {
                _polylines.remove(element);
              });
            } else {
              _polylines_gesamtnetz.forEach((element) {
                _polylines.add(element);
              });
              newValue = true;
            }
            isChecked = newValue;
          });
          break;
        case "Ändere Kartenstil":
          break;
        case "MunichWays Webseite":
          break;
        case "Spende":
          break;
        case "Bewertungskriterien":
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      drawer: Drawer(
        child: Text("Hier gibts bald mehr zu lesen ..."),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              polylines: _polylines,
              myLocationButtonEnabled: true,
              myLocationEnabled: false,
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 14.0,
              ),
              mapType: MapType.normal,
              mapToolbarEnabled: true,
              zoomControlsEnabled: true,
            ),
            MapAppBar(
              actions: <Widget>[
                PopupMenuButton<String>(
                    onSelected: _select,
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[0].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                          textScaleFactor: 1,
                        ),
                        enabled: true,
                        value: choices[0],
                        checked: true,
                      ),
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[1].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                        ),
                        enabled: true,
                        value: choices[1],
                        checked: isChecked,
                      ),
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[2].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                        ),
                        enabled: false,
                        value: choices[2],
                      ),
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[3].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                        ),
                        enabled: false,
                        value: choices[3],
                      ),
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[4].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                        ),
                        enabled: false,
                        value: choices[4],
                      ),
                      CheckedPopupMenuItem<String>(
                        child: Text(
                          choices[5].toString(),
                          style: Theme.of(context).textTheme.bodyText1,
                          textAlign: TextAlign.left,
                          strutStyle: StrutStyle(fontSize: 1.2),
                        ),
                        enabled: false,
                        value: choices[5],
                      ),
                    ]),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}

final List<String> choices = <String>[
  "RadlvorrangNetz",
  "Gesamtnetz",
  "Ändere Kartenstil",
  "MunichWays Webseite",
  "Spende",
  "Bewertungskriterien"
];
