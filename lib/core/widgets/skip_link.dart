import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/app_colors.dart';

/// Keyboard accessibility overlay that jumps straight to the page content.
///
/// The link is the first focusable element on the page (enforced with an
/// ordered focus traversal group) but stays invisible until it receives
/// keyboard focus; activating it requests focus on [target] (a
/// traversal-skipped `FocusNode` wrapped around the main content), so Tab
/// no longer walks the sidebar navigation first.
class SkipLink extends StatefulWidget {
  const SkipLink({super.key, required this.target, required this.child});

  final FocusNode target;
  final Widget child;

  @override
  State<SkipLink> createState() => _SkipLinkState();
}

class _SkipLinkState extends State<SkipLink> {
  bool _focused = false;
  final FocusNode _linkFocus = FocusNode();

  @override
  void dispose() {
    _linkFocus.dispose();
    super.dispose();
  }

  static FocusNode? _firstFocusable(FocusNode root) {
    FocusNode? found;
    void walk(FocusNode node) {
      for (final child in node.children) {
        walk(child);
      }
      if (found == null && !node.skipTraversal && node.canRequestFocus) {
        found = node;
      }
    }

    walk(root);
    return found;
  }

  void _activate() {
    (_firstFocusable(widget.target) ?? widget.target).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 12,
            left: 12,
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(-1),
              child: Opacity(
                opacity: _focused ? 1 : 0,
                child: Material(
                  color: AppColors.surface,
                  elevation: _focused ? 4 : 0,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    focusNode: _linkFocus,
                    canRequestFocus: true,
                    onFocusChange: (focused) =>
                        setState(() => _focused = focused),
                    onTap: _activate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.keyboard,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الانتقال للمحتوى الرئيسي',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
