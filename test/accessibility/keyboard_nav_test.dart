import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/core/widgets/skip_link.dart';

void main() {
  group('keyboard navigation & focus (W8-5)', () {
    testWidgets('skip link is hidden until focused and jumps to content', (
      tester,
    ) async {
      final target = FocusNode(debugLabel: 'content', skipTraversal: true);
      addTearDown(target.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SkipLink(
            target: target,
            child: Scaffold(
              body: Focus(
                focusNode: target,
                child: Column(
                  children: [
                    const TextField(),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('زر المحتوى'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final linkText = find.text('الانتقال للمحتوى الرئيسي');
      expect(linkText, findsOneWidget);

      Opacity linkOpacity() => tester.widget<Opacity>(
        find.ancestor(of: linkText, matching: find.byType(Opacity)).first,
      );

      expect(linkOpacity().opacity, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        linkOpacity().opacity,
        1,
        reason: 'skip link should become visible on keyboard focus',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final firstEditable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(
        firstEditable.focusNode.hasFocus,
        isTrue,
        reason: 'activating the skip link must land focus on the first content control',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        firstEditable.focusNode.hasFocus,
        isFalse,
        reason: 'Tab after activation should continue into the content region',
      );
    });

    testWidgets('modal bottom sheet keeps keyboard focus inside', (
      tester,
    ) async {
      final behindFocus = FocusNode(debugLabel: 'behind');
      addTearDown(behindFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                children: [
                  TextButton(
                    focusNode: behindFocus,
                    onPressed: () {},
                    child: const Text('خلفي'),
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'داخل الورقة',
                            ),
                          ),
                        ),
                      ),
                      child: const Text('افتح الورقة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح الورقة'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(
        behindFocus.hasFocus,
        isFalse,
        reason: 'while a bottom sheet is open focus must stay inside it',
      );
    });
  });
}
