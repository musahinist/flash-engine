import 'package:demo/main.dart';
import 'package:demo/shared/demo_catalog.dart';
import 'package:demo/shared/demo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A smoke test over every entry in the catalogue.
///
/// The demos are the engine's documentation, and a demo that throws on its
/// first frame is worse than no demo. Compiling proves nothing here — most of
/// the mistakes worth catching (a null engine, a missing inherited widget, a
/// bad cast in a scene builder) only show up once the widget is built and
/// pumped.
///
/// This walks the real catalogue rather than a hand-kept list, so a demo added
/// to `main.dart` is covered without anyone remembering to add it here.
void main() {
  /// Pulls the entries straight out of the catalogue widget.
  List<CatalogEntry> catalogueEntries(WidgetTester tester) {
    final page = tester.widget<CatalogPage>(find.byType(CatalogPage));
    return [for (final section in page.sections) ...section.entries];
  }

  testWidgets('the catalogue lists every section', (tester) async {
    await tester.pumpWidget(const FlashDemoApp());
    final page = tester.widget<CatalogPage>(find.byType(CatalogPage));

    expect(page.sections, isNotEmpty);
    for (final section in page.sections) {
      expect(section.entries, isNotEmpty, reason: '"${section.title}" is empty');
      for (final entry in section.entries) {
        expect(entry.title, isNotEmpty);
        expect(entry.description, isNotEmpty,
            reason: '"${entry.title}" has no description; the catalogue is how '
                'someone finds the example for a class');
      }
    }
  });

  testWidgets('every demo builds and survives a few frames', (tester) async {
    // Big enough that the control column is not the whole window.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FlashDemoApp());
    final entries = catalogueEntries(tester);
    expect(entries.length, greaterThan(20), reason: 'the catalogue looks truncated');

    for (final entry in entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: DemoTheme.materialTheme(),
          home: Builder(builder: entry.builder),
        ),
      );
      // A few frames: the first one builds, later ones run the engine tick and
      // any onReady work.
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(tester.takeException(), isNull, reason: '"${entry.title}" threw while building');

      // Unmount, so dispose() runs while the test can still see a throw from
      // it. This is where a missing native release or a double dispose shows.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '"${entry.title}" threw while disposing');
    }
  });

  testWidgets('a demo page still shows its way back on a small window', (tester) async {
    // The old scaffolds put the back control at a fixed offset, and on a phone
    // some of them were off-screen or under other chrome.
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FlashDemoApp());
    final entry = catalogueEntries(tester).first;

    await tester.pumpWidget(
      MaterialApp(theme: DemoTheme.materialTheme(), home: Builder(builder: entry.builder)),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
