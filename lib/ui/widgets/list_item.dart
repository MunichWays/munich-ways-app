import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool isLink;
  final bool compact;

  const ListItem({
    Key? key,
    required this.label,
    required this.value,
    this.onTap,
    this.isLink = false,
    this.compact = false,
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
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: compact
                            ? Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    value!,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    this.label,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  SizedBox(
                                    height: 6,
                                  ),
                                  Text(
                                    this.value!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: isLink
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                          decoration: isLink
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                          decorationColor: isLink
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                  )
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
