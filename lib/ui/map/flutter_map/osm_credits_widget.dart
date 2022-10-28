import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OSMCreditsWidget extends StatelessWidget {
  const OSMCreditsWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: GestureDetector(
        onTap: () async {
          const url = 'https://www.openstreetmap.org/copyright';
          if (await canLaunchUrlString(url)) {
            await launchUrlString(url);
          } else {
            log.e("No browser found");
          }
        },
        child: Container(
            padding: const EdgeInsets.all(2.0),
            color: Colors.white70,
            child: Text.rich(TextSpan(
              text: "© ",
              style: TextStyle(fontSize: 12),
              children: <TextSpan>[
                TextSpan(
                    text: "OpenStreetMaps",
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                    )),
                TextSpan(
                  text: " contributors",
                )
              ],
            ))),
      ),
    );
  }
}
