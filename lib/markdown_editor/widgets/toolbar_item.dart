import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';

class ToolbarItem extends StatelessWidget {
  const ToolbarItem({
    Key? key,
    required this.icon,
    this.onPressedButton,
    this.tooltip,
    this.isExpandable = false,
    this.items,
  }) : super(key: key);

  final dynamic icon;
  final VoidCallback? onPressedButton;
  final String? tooltip;
  final bool isExpandable;
  final List? items;

  @override
  Widget build(BuildContext context) {
    return !isExpandable
        ? Material(
            type: MaterialType.transparency,
            child: IconButton(
              onPressed: onPressedButton,
              splashColor: Colors.teal.withOpacity(0.4),
              highlightColor: Colors.teal.withOpacity(0.4),
              icon: icon is String
                  ? Text(
                      icon,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 16,
                    ),
              tooltip: tooltip,
            ),
          )
        : ExpandableNotifier(
            child: Expandable(
              key: const Key("list_button"),
              collapsed: ExpandableButton(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: icon is String
                      ? Text(
                          icon,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 16,
                        ),
                ),
              ),
              expanded: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (var item in items!) item,
                      ExpandableButton(
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.remove_circle,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
