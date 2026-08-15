import 'package:demo/main.dart';
import 'package:demo/shared/demo_catalog.dart';
import 'package:demo/shared/demo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flash/flash.dart';
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
library;

/// The engine behind whatever demo is currently mounted.
FEngine? _engineOf(WidgetTester tester) {
  final found = find.byType(InheritedFNode);
  if (found.evaluate().isEmpty) return null;
  return tester.widget<InheritedFNode>(found.first).engine;
}

/// Every render node's world position, as a comparable string.
String _positions(FEngine engine) {
  final buffer = StringBuffer();
  for (final node in engine.renderNodes) {
    final p = node.worldPosition;
    buffer.write('${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)},${p.z.toStringAsFixed(3)};');
  }
  return buffer.toString();
}

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

  testWidgets('every demo puts something on screen', (tester) async {
    // "It builds" and "you can see it" are different claims, and only the
    // first was ever checked. Three grid demos shipped with a camera parked
    // above the plane but never pitched down at it, so they rendered a
    // perfectly healthy scene entirely out of view.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FlashDemoApp());

    for (final entry in catalogueEntries(tester)) {
      await tester.pumpWidget(
        MaterialApp(theme: DemoTheme.materialTheme(), home: Builder(builder: entry.builder)),
      );
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      tester.takeException();

      final engine = _engineOf(tester);
      if (engine == null) continue; // not every entry drives an engine

      // Only nodes with geometry count. A camera has no bounds and is never
      // drawn, so it must not be mistaken for visible content.
      final drawable = engine.renderNodes.where((n) => n.bounds != null).toList();
      if (drawable.length < 2) continue; // painter- or particle-driven scene

      final viewport = engine.viewportSize;
      final onScreen = drawable.where((node) {
        final screen = engine.project(node.worldPosition);
        return screen != null &&
            screen.x >= 0 &&
            screen.x <= viewport.x &&
            screen.y >= 0 &&
            screen.y <= viewport.y;
      }).length;

      expect(onScreen, greaterThan(0),
          reason: '"${entry.title}" draws ${drawable.length} nodes and not one '
              'of them lands inside the viewport');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.takeException();
    }
  });

  testWidgets('demos driven by elapsed time actually move', (tester) async {
    // FAnimated was a StatelessWidget reading an InheritedWidget that never
    // notified, so its builder ran exactly once and every scene built on it was
    // a still image. Everything below is animated purely by the engine clock,
    // with no input, so each one has to change over a second of frames.
    const mustAnimate = {
      'Basic Scene',
      'Solar System',
      '3D Primitives',
      '2.5D Diorama',
      'Sprites',
      'Rendering',
      'Dynamic Light',
      'Tween Widgets',
      '3D Audio',
    };

    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FlashDemoApp());
    final entries = catalogueEntries(tester).where((e) => mustAnimate.contains(e.title)).toList();
    expect(entries.length, mustAnimate.length, reason: 'a demo in the list was renamed or removed');

    for (final entry in entries) {
      await tester.pumpWidget(
        MaterialApp(theme: DemoTheme.materialTheme(), home: Builder(builder: entry.builder)),
      );
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      tester.takeException();

      final engine = _engineOf(tester);
      expect(engine, isNotNull, reason: '"${entry.title}" has no engine');

      final before = _positions(engine!);
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final after = _positions(engine);
      tester.takeException();

      expect(after, isNot(equals(before)),
          reason: '"${entry.title}" did not move over a second of frames');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      tester.takeException();
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
