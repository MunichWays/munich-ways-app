import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const ListItem({
    Key? key,
    required this.label,
    required this.value,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) {
      return SizedBox.shrink();
    } else {
      return Column(
        children: [
          Divider(
            height: 0,
          ),
          Material(
            child: InkWell(
              child: Ink(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              this.label,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            SizedBox(
                              height: 6,
                            ),
                            Text(this.value!,
                                style: Theme.of(context).textTheme.titleMedium)
                          ],
                        ),
                      ),
                      onTap != null
                          ? Icon(Icons.open_in_browser)
                          : SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
              onTap: this.onTap,
            ),
          ),
        ],
      );
    }
  }
}
