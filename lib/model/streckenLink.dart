import 'package:equatable/equatable.dart';
import 'package:html/parser.dart';

/// Class for "streckenLink" property
class StreckenLink extends Equatable {
  final String title;
  final String? url;

  StreckenLink({required this.title, this.url});

  factory StreckenLink.fromString(String value) {
    var document = parseFragment(value);
    var aTag = document.querySelector('a');
    if (aTag != null) {
      return StreckenLink(
          title: aTag.text.trim(), url: aTag.attributes['href']);
    } else {
      return StreckenLink(title: value);
    }
  }

  @override
  List<Object?> get props => [title, url];

  @override
  String toString() {
    return 'StreckenLink{title: $title, url: $url}';
  }
}
