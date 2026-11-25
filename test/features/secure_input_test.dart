import 'package:device_safety_info/device_safety_info.dart';
import 'package:device_safety_info/src/core/utils/screen_block.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calls = <bool>[];

  setUp(() {
    calls.clear();
    ScreenBlock.blocker = (block) async => calls.add(block);
  });

  tearDown(() => ScreenBlock.blocker = (_) async {});

  test('presets turn off everything that leaks typed text', () {
    for (final c in const [
      SecureInputConfig(),
      SecureInputConfig.password(),
      SecureInputConfig.pin(),
      SecureInputConfig.otp(),
    ]) {
      expect(c.autocorrect, isFalse);
      expect(c.enableSuggestions, isFalse);
      expect(c.enableIMEPersonalizedLearning, isFalse);
      expect(c.enableInteractiveSelection, isFalse);
      expect(c.smartDashesType, SmartDashesType.disabled);
      expect(c.smartQuotesType, SmartQuotesType.disabled);
      expect(c.autofillHints, isNull);
      expect(c.blockScreenshotsWhileFocused, isTrue);
    }
    expect(const SecureInputConfig.pin().keyboardType, TextInputType.number);
    expect(const SecureInputConfig.otp().obscureText, isFalse);
    expect(
      const SecureInputConfig.otp(allowClipboard: true)
          .enableInteractiveSelection,
      isTrue,
    );
    expect(const SecureInputConfig.pin(), const SecureInputConfig.pin());
    expect(
      const SecureInputConfig.pin().hashCode,
      const SecureInputConfig.pin().hashCode,
    );
    expect(
      const SecureInputConfig.pin() == const SecureInputConfig.otp(),
      isFalse,
    );
  });

  Widget app(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(data: const MediaQueryData(), child: child),
  );

  testWidgets(
    'SecureEditableText applies the config and blocks while focused',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      final other = FocusNode();
      addTearDown(() {
        controller.dispose();
        focus.dispose();
        other.dispose();
      });
      await tester.pumpWidget(
        app(
          Column(
            children: [
              SecureEditableText(
                controller: controller,
                focusNode: focus,
                config: const SecureInputConfig.pin(),
                style: const TextStyle(fontSize: 14),
                cursorColor: const Color(0xFF000000),
              ),
              Focus(focusNode: other, child: const SizedBox(height: 10)),
            ],
          ),
        ),
      );
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
      expect(editable.autocorrect, isFalse);
      expect(editable.enableSuggestions, isFalse);
      expect(editable.enableIMEPersonalizedLearning, isFalse);
      expect(editable.enableInteractiveSelection, isFalse);
      expect(editable.contextMenuBuilder, isNull);
      expect(editable.keyboardType, TextInputType.number);
      expect(calls, isEmpty);

      focus.requestFocus();
      await tester.pump();
      expect(calls, [true]);
      expect(ScreenBlock.activeCount, 1);

      other.requestFocus();
      await tester.pump();
      expect(calls, [true, false]);
      expect(ScreenBlock.activeCount, 0);
    },
  );

  testWidgets('a focused field never unblocks a SecureScreen', (tester) async {
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(() {
      focus.dispose();
      controller.dispose();
    });
    Widget tree({required bool screen, required bool field}) => app(
      Column(
        children: [
          if (screen) const SecureScreen(child: SizedBox()),
          if (field)
            SecureFieldGuard(
              child: EditableText(
                controller: controller,
                focusNode: focus,
                style: const TextStyle(),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
              ),
            ),
        ],
      ),
    );
    await tester.pumpWidget(tree(screen: true, field: true));
    focus.requestFocus();
    await tester.pump();
    expect(ScreenBlock.activeCount, 2);
    await tester.pumpWidget(tree(screen: true, field: false));
    expect(ScreenBlock.activeCount, 1, reason: 'disposing the field releases');
    expect(calls, [true]);
    await tester.pumpWidget(tree(screen: false, field: false));
    expect(calls, [true, false]);
  });

  testWidgets('blockScreenshotsWhileFocused: false never blocks', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        SecureEditableText(
          controller: controller,
          autofocus: true,
          config: const SecureInputConfig.password(
            blockScreenshotsWhileFocused: false,
          ),
          style: const TextStyle(),
          cursorColor: const Color(0xFF000000),
        ),
      ),
    );
    await tester.pump();
    expect(calls, isEmpty);
  });
}
