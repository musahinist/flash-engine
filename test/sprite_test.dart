import 'dart:ui' as ui;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [FSprite] could only ever draw a whole image.
///
/// `FSprite.fromAsset` accepted a `src` rectangle and dropped it on the floor,
/// and the node itself had no way to express one — so every sprite drew the
/// entire sheet squashed into its destination rect, which makes an atlas (the
/// normal way a game ships sprites) impossible to use.
void main() {
  late ui.Image sheet;

  setUpAll(() async {
    // A 4x1 sheet of 64px frames.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * 64.0, 0, 64, 64),
        Paint()..color = [Colors.red, Colors.green, Colors.blue, Colors.yellow][i],
      );
    }
    final picture = recorder.endRecording();
    sheet = await picture.toImage(256, 64);
    picture.dispose();
  });

  tearDownAll(() => sheet.dispose());

  /// The node FSprite creates, once mounted.
  FNode spriteNode(WidgetTester tester) {
    final engine = tester.widget<InheritedFNode>(find.byType(InheritedFNode).first).engine;
    return engine.scene.children.expand(_descendants).firstWhere((n) => n.name == 'atlas');
  }

  testWidgets('a sprite without src is the size of the whole image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: FView(child: FSprite(image: sheet, name: 'atlas'))),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(spriteNode(tester).bounds!.width, 256);
    expect(spriteNode(tester).bounds!.height, 64);
  });

  testWidgets('src makes the sprite the size of the frame, not the sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FView(
          child: FSprite(
            image: sheet,
            name: 'atlas',
            src: const Rect.fromLTWH(64, 0, 64, 64),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    final bounds = spriteNode(tester).bounds!;
    expect(bounds.width, 64, reason: 'a frame from an atlas is one frame wide');
    expect(bounds.height, 64);
  });

  testWidgets('an explicit size still wins over the frame size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FView(
          child: FSprite(
            image: sheet,
            name: 'atlas',
            src: const Rect.fromLTWH(0, 0, 64, 64),
            width: 200,
            height: 120,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    final bounds = spriteNode(tester).bounds!;
    expect(bounds.width, 200);
    expect(bounds.height, 120);
  });

  testWidgets('changing src on rebuild reaches the node', (tester) async {
    Widget build(Rect src) => MaterialApp(
      home: FView(child: FSprite(image: sheet, name: 'atlas', src: src)),
    );

    await tester.pumpWidget(build(const Rect.fromLTWH(0, 0, 64, 64)));
    await tester.pump(const Duration(milliseconds: 16));

    // A flipbook works by rebuilding with a new src every frame, so this is
    // the path that matters.
    await tester.pumpWidget(build(const Rect.fromLTWH(128, 0, 32, 32)));
    await tester.pump(const Duration(milliseconds: 16));

    expect(spriteNode(tester).bounds!.width, 32);
  });
}

Iterable<FNode> _descendants(FNode node) sync* {
  yield node;
  for (final child in node.children) {
    yield* _descendants(child);
  }
}
