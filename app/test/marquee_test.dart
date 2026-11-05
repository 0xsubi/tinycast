import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinycast/ui/marquee.dart';

Future<void> _pump(WidgetTester tester, String text) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(width: 120, child: MarqueeText(text, style: const TextStyle(fontSize: 14))),
    ),
  ),
);

void main() {
  testWidgets('a title that fits stays put and asks for no frames', (tester) async {
    await _pump(tester, 'Short');
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(Transform), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a long title holds, then crawls left', (tester) async {
    await _pump(tester, 'A title far too long to fit in the mini player at all');
    await tester.pump();
    double x() => tester.widget<Transform>(find.byType(Transform)).transform.getTranslation().x;
    await tester.pump(const Duration(seconds: 1));
    expect(x(), 0);
    await tester.pump(const Duration(seconds: 3));
    final a = x();
    await tester.pump(const Duration(seconds: 1));
    expect(a, lessThan(0));
    expect(x() - a, closeTo(-24, 0.5));
    // The next copy follows the first.
    expect(find.text('A title far too long to fit in the mini player at all'), findsNWidgets(2));
  });
}
