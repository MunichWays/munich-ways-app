import 'package:equatable/equatable.dart';
import 'package:html/parser.dart';

class Link extends Equatable {
  final String? title;
  final String? url;

  Link(this.title, this.url);

  @override
  String toString() {
    return 'Link{title: $title, url: $url}';
  }

  @override
  List<Object?> get props => [title, url];
}

class LinksParser {
  final Map<String, String> links;

  LinksParser(this.links);

  static List<Link> parse(String? html) {
    List<Link> links = [];
    if (html == null) {
      return links;
    }
    var document = parseFragment(html);
    var allATags = document.querySelectorAll('a');
    for (var aTag in allATags) {
      String title = aTag.text;
      String? url = aTag.attributes['href'];
      if (title.isNotEmpty && url != null && url.isNotEmpty) {
        links.add(Link(title.trim(), url));
      }
    }
    return links;
  }
}
