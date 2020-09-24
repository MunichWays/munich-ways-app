import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:munich_ways/ui/side_drawer.dart';
import 'package:munich_ways/ui/theme.dart';

import '../../control/geojsonroutes.dart';
import 'map_app_bar.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with Routes {
  static const STACHUS = [48.14, 11.5652];

  static const LAYERID = "WHICH_LAYERID_OUGHT_TO_APPLY";
  static const LHM =
      "https://cartocdn-gusc-c.gloabl.ssl.fastly.net/usocialmapls/api/V1/MAP/USOCIALMAPS@" +
          LAYERID +
          "/1,2,3,4,5,/{Z}/{X}/{Y}.png";
  static const OPENPT = "http://openptmap.org/tiles/{z}/{x}/{y}.png";
  static const GEOJSONENDPOINTS = {
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

  GoogleMapController mapController;
  final LatLng _center = LatLng(STACHUS[0], STACHUS[1]);

  void initState() {
    GEOJSONENDPOINTS.forEach((networkKey, networkValue) async {
      if (networkKey.toString() == "vorrangnetz") {
        await for (var i in getNetworks(networkKey, networkValue)) {
          _polylines_vorrangnetz = i;
        }
      }
    });
    GEOJSONENDPOINTS.forEach((networkKey, networkValue) async {
      if (networkKey.toString() == "gesamtnetz") {
        await for (var i in getNetworks(networkKey, networkValue)) {
          _polylines_gesamtnetz = i;
        }
      }
    });
  }

// TODO introduce again
//  display Gesamtnetz
//        case "Gesamtnetz":
//          setState(() {
//            bool newValue = false;
//            if (isChecked == true) {
//              newValue = false;
//              _polylines_gesamtnetz.forEach((element) {
//                _polylines.remove(element);
//              });
//            } else {
//              _polylines_gesamtnetz.forEach((element) {
//                _polylines.add(element);
//              });
//              newValue = true;
//            }
//            isChecked = newValue;
//          });

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
      var Overlays = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SideDrawer(),
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
              zoomControlsEnabled: false,
            ),
            MapAppBar(
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Legende',
                  onPressed: () {
                    //TODO display information about map
                    setState(() {
                      //display vorrangnetz
                      //TODO introduce button on map for changing layers
                      _polylines = _polylines_vorrangnetz;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}