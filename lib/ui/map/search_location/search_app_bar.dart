import 'package:flutter/material.dart';
import 'package:munich_ways/common/logger_setup.dart';

class SearchAppBar extends StatefulWidget implements PreferredSizeWidget {
  SearchAppBar({Key key, Function(String query) this.onSearch})
      : preferredSize = Size.fromHeight(kToolbarHeight + 24),
        super(key: key);

  @override
  final Size preferredSize;

  final Function onSearch;

  @override
  _SearchAppBarState createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar> {
  TextEditingController _searchQueryController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double statusBarHeight = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: AppBar(
        titleSpacing: 0.0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black54),
        title: TextField(
          controller: _searchQueryController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Suche Ziel ...",
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 18.0),
          textInputAction: TextInputAction.search,
          onSubmitted: (text) {
            widget.onSearch(_searchQueryController.value.text);
          },
        ),
        backgroundColor: Colors.white,
        shape: SearchAppBarShape(statusBarHeight),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Starte Suche',
            onPressed: () {
              widget.onSearch(_searchQueryController.value.text);
            },
          ),
        ],
      ),
    );
  }
}

class SearchAppBarShape extends ShapeBorder {
  final double statusBarHeight;

  SearchAppBarShape(this.statusBarHeight) {}

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection textDirection}) => null;

  @override
  Path getOuterPath(Rect rect, {TextDirection textDirection}) {
    log.d(rect.height);
    return Path()
      ..addRRect(RRect.fromLTRBR(rect.left, rect.top + statusBarHeight,
          rect.right, rect.bottom, Radius.circular(rect.height / 10)))
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
