import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';
import 'package:munich_ways/common/logger_setup.dart';

import 'links.dart';

/// Combines all "bezirk"-properties
class Bezirk extends Equatable {
  final String name;
  final String nummer;
  final Link link;
  final String region;

  Bezirk(
      {@required this.name,
      @required this.nummer,
      @required this.link,
      @required this.region});

  factory Bezirk.fromProps(
      {@required name, @required nummer, @required link, @required region}) {
    var aTag;
    if (link != null) {
      var document = parseFragment(link);
      aTag = document.querySelector('a');
    }

    if (aTag != null) {
      return Bezirk(
          name: name,
          nummer: nummer,
          region: region,
          link: Link(aTag.text?.trim(), aTag.attributes['href']));
    } else {
      log.d("Could not parse link for $nummer $name $link");
      return Bezirk(
          name: name,
          nummer: nummer,
          region: region,
          link: Link("$nummer $name",
              "https://www.munichways.com/bezirksausschuesse/"));
    }
  }

  @override
  List<Object> get props => [this.name, this.nummer, this.link, this.region];
}
