import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/ui/notes_text.dart';

void main() {
  testWidgets('links in show notes open when tapped', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotesText(
            'Read [the post](https://ex.com/post) or https://ex.com/b.',
            style: const TextStyle(fontSize: 15),
            onOpen: (uri) async => opened.add(uri),
          ),
        ),
      ),
    );
    final spans = <TextSpan>[];
    tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!.visitChildren((s) {
      if (s is TextSpan && s.recognizer != null) spans.add(s);
      return true;
    });
    expect(spans.map((s) => s.text), ['the post', 'https://ex.com/b']);
    expect(spans.first.mouseCursor, SystemMouseCursors.click);
    for (final s in spans) {
      (s.recognizer! as TapGestureRecognizer).onTap!();
    }
    expect(opened, [Uri.parse('https://ex.com/post'), Uri.parse('https://ex.com/b')]);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).textSpan!.toPlainText(),
      'Read the post or https://ex.com/b.',
    );
  });

  testWidgets('tapping a link on screen opens it', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotesText(
            '[Open](https://ex.com)',
            style: const TextStyle(fontSize: 40),
            onOpen: (uri) async => opened.add(uri),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getTopLeft(find.byType(SelectableText)) + const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 500));
    expect(opened, [Uri.parse('https://ex.com')]);
  });
}
