import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [FAnimated] and [FAnimatedList] exist to rebuild a subtree every engine
/// frame. They did not.
///
/// Both were `StatelessWidget`s that read `context.flash` and called the
/// builder with `engine.elapsed`. That reads as correct and cannot work:
/// `context.flash` depends on `InheritedFNode`, whose `updateShouldNotify`
/// compares the engine and the node, and both are the same objects every
/// frame — so it never notified. `FView` also hands its subtree the identical
/// child widget on each rebuild, which Flutter short-circuits. The builder ran
/// exactly once, for the lifetime of the widget, and every demo built on it was
/// a still image.
///
/// Nothing caught it because "the widget builds" and "the widget animates" are
/// different claims, and only the first was ever asserted.
void main() {
  /// Collects the elapsed values a builder is handed over [frames] frames.
  Future<List<double>> collect(WidgetTester tester, Widget Function(void Function(double)) build,
      {int frames = 10}) async {
    final seen = <double>[];
    await tester.pumpWidget(MaterialApp(home: build(seen.add)));
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return seen;
  }

  testWidgets('FAnimated rebuilds every frame with advancing time', (tester) async {
    final seen = await collect(
      tester,
      (record) => FView(
        child: FAnimated(
          builder: (context, elapsed) {
            record(elapsed);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(seen.length, greaterThan(5), reason: 'the builder ran ${seen.length} times in 10 frames');
    expect(seen.toSet().length, greaterThan(5), reason: 'elapsed never advanced: $seen');
    expect(seen.last, greaterThan(seen.first));
  });

  testWidgets('FAnimated still rebuilds when nested below other widgets', (tester) async {
    // The demos wrap it in a Stack, a Builder, a GestureDetector. An
    // implementation that relied on the parent rebuilding would pass the case
    // above and fail here.
    final seen = await collect(
      tester,
      (record) => FView(
        child: Stack(
          children: [
            Builder(
              builder: (context) => FAnimated(
                builder: (context, elapsed) {
                  record(elapsed);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(seen.toSet().length, greaterThan(5), reason: 'elapsed never advanced: $seen');
  });

  testWidgets('FAnimatedList rebuilds every frame too', (tester) async {
    final seen = await collect(
      tester,
      (record) => FView(
        child: FAnimatedList(
          builder: (context, elapsed) {
            record(elapsed);
            return const [SizedBox.shrink()];
          },
        ),
      ),
    );

    expect(seen.toSet().length, greaterThan(5), reason: 'elapsed never advanced: $seen');
  });

  testWidgets('outside an FView it renders nothing rather than throwing', (tester) async {
    var built = false;
    await tester.pumpWidget(
      MaterialApp(
        home: FAnimated(
          builder: (context, elapsed) {
            built = true;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    expect(built, isFalse);
    expect(tester.takeException(), isNull);
  });
}
