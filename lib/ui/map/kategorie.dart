import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';

/// Class for "kategorie" property
class Kategorie extends Equatable {
  final String title;
  final String url;

  Kategorie({@required this.title, this.url});

  factory Kategorie.fromString(String value) {
    var document = parseFragment(value);
    var aTag = document.querySelector('a');
    if (aTag != null) {
      return Kategorie(title: aTag.text?.trim(), url: aTag.attributes['href']);
    } else {
      return Kategorie(title: value);
    }
  }

  @override
  List<Object> get props => [title, url];

  @override
  String toString() {
    return 'Kategorie{title: $title, url: $url}';
  }
}
