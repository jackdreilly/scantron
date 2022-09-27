import 'package:flutter/material.dart';
import '../src/toolbar.dart';
import 'modal_select_emoji.dart';
import 'modal_input_url.dart';
import 'toolbar_item.dart';

class MarkdownToolbar extends StatelessWidget {
  MarkdownToolbar({
    Key? key,
    required this.onPreviewChanged,
    required this.controller,
    this.emojiConvert = true,
    required this.focusNode,
    required this.isEditorFocused,
    this.autoCloseAfterSelectEmoji = true,
  })  : toolbar = Toolbar(
          controller: controller,
          focusNode: focusNode,
          isEditorFocused: isEditorFocused,
        ),
        super(key: key);

  final VoidCallback onPreviewChanged;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool emojiConvert;
  final bool autoCloseAfterSelectEmoji;
  final Toolbar toolbar;
  final ValueChanged<bool> isEditorFocused;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      width: double.infinity,
      height: 45,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // preview
            ToolbarItem(
              key: const ValueKey<String>("toolbar_view_item"),
              icon: Icons.remove_red_eye,
              onPressedButton: () {
                onPreviewChanged.call();
              },
            ),
            // select single line
            ToolbarItem(
              key: const ValueKey<String>("toolbar_selection_action"),
              icon: Icons.width_normal,
              onPressedButton: () {
                toolbar.selectSingleLine();
              },
            ),
            // bold
            ToolbarItem(
              key: const ValueKey<String>("toolbar_bold_action"),
              icon: Icons.format_bold,
              onPressedButton: () {
                toolbar.action("**", "**");
              },
            ),
            // italic
            ToolbarItem(
              key: const ValueKey<String>("toolbar_italic_action"),
              icon: Icons.format_italic_sharp,
              onPressedButton: () {
                toolbar.action("_", "_");
              },
            ),
            // strikethrough
            ToolbarItem(
              key: const ValueKey<String>("toolbar_strikethrough_action"),
              icon: Icons.strikethrough_s,
              onPressedButton: () {
                toolbar.action("~~", "~~");
              },
            ),
            // heading
            ToolbarItem(
              key: const ValueKey<String>("toolbar_heading_action"),
              icon: Icons.format_size,
              isExpandable: true,
              items: [
                ToolbarItem(
                  key: const ValueKey<String>("h1"),
                  icon: "H1",
                  onPressedButton: () => toolbar.action("# ", ""),
                ),
                ToolbarItem(
                  key: const ValueKey<String>("h2"),
                  icon: "H2",
                  onPressedButton: () => toolbar.action("## ", ""),
                ),
                ToolbarItem(
                  key: const ValueKey<String>("h3"),
                  icon: "H3",
                  onPressedButton: () => toolbar.action("### ", ""),
                ),
              ],
            ),
            // unorder list
            ToolbarItem(
              key: const ValueKey<String>("toolbar_unorder_list_action"),
              icon: Icons.list,
              onPressedButton: () {
                toolbar.action("* ", "");
              },
            ),
            // checkbox list
            ToolbarItem(
              key: const ValueKey<String>("toolbar_checkbox_list_action"),
              icon: Icons.task_alt_sharp,
              isExpandable: true,
              items: [
                ToolbarItem(
                  key: const ValueKey<String>("checkbox"),
                  icon: Icons.check_box,
                  onPressedButton: () {
                    toolbar.action("- [x] ", "");
                  },
                ),
                ToolbarItem(
                  key: const ValueKey<String>("uncheckbox"),
                  icon: Icons.square,
                  onPressedButton: () {
                    toolbar.action("- [ ] ", "");
                  },
                )
              ],
            ),
            // emoji
            ToolbarItem(
              key: const ValueKey<String>("toolbar_emoji_action"),
              icon: Icons.emoji_emotions,
              onPressedButton: () {
                _showModalSelectEmoji(context, controller.selection);
              },
            ),
            // link
            ToolbarItem(
              key: const ValueKey<String>("toolbar_link_action"),
              icon: Icons.link,
              onPressedButton: () {
                if (toolbar.checkHasSelection()) {
                  toolbar.action("[enter link description here](", ")");
                } else {
                  _showModalInputUrl(context, "[enter link description here](",
                      controller.selection);
                }
              },
            ),
            // image
            ToolbarItem(
              key: const ValueKey<String>("toolbar_image_action"),
              icon: Icons.image,
              onPressedButton: () {
                if (toolbar.checkHasSelection()) {
                  toolbar.action("![enter image description here](", ")");
                } else {
                  _showModalInputUrl(
                    context,
                    "![enter image description here](",
                    controller.selection,
                  );
                }
              },
            ),
            // blockquote
            ToolbarItem(
              key: const ValueKey<String>("toolbar_blockquote_action"),
              icon: Icons.format_quote,
              onPressedButton: () {
                toolbar.action("> ", "");
              },
            ),
            // code
            ToolbarItem(
              key: const ValueKey<String>("toolbar_code_action"),
              icon: Icons.code,
              onPressedButton: () {
                toolbar.action("`", "`");
              },
            ),
            // line
            ToolbarItem(
              key: const ValueKey<String>("toolbar_line_action"),
              icon: Icons.horizontal_rule_rounded,
              onPressedButton: () {
                toolbar.action("\n___\n", "");
              },
            ),
          ],
        ),
      ),
    );
  }

  // show modal select emoji
  Future<dynamic> _showModalSelectEmoji(
      BuildContext context, TextSelection selection) {
    return showModalBottomSheet(
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      context: context,
      builder: (context) {
        return ModalSelectEmoji(
          emojiConvert: emojiConvert,
          onChanged: (String emot) {
            if (autoCloseAfterSelectEmoji) Navigator.pop(context);
            final newSelection = toolbar.getSelection(selection);

            toolbar.action(emot, "", textSelection: newSelection);
            // change selection baseoffset if not auto close emoji
            if (!autoCloseAfterSelectEmoji) {
              selection = TextSelection.collapsed(
                offset: newSelection.baseOffset + emot.length,
              );
              focusNode.unfocus();
            }
          },
        );
      },
    );
  }

  // show modal input
  Future<dynamic> _showModalInputUrl(
    BuildContext context,
    String leftText,
    TextSelection selection,
  ) {
    return showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return ModalInputUrl(
          toolbar: toolbar,
          leftText: leftText,
          selection: selection,
        );
      },
    );
  }
}
