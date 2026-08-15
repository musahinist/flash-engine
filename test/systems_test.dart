import 'package:flutter_test/flutter_test.dart';
import 'package:flash/flash.dart';

/// Tweens, timers and scoring had no tests at all, despite being the systems
/// most likely to be wired into a game's core loop.
void main() {
  group('FTween', () {
    test('interpolates from start to end over its duration', () {
      final values = <double>[];
      final tween = FDoubleTween(from: 0, to: 100, duration: 1.0, onUpdate: values.add)..start();

      for (int i = 0; i < 60; i++) {
        tween.update(1 / 60);
      }

      expect(values.first, closeTo(0, 5));
      expect(values.last, closeTo(100, 0.001));
    });

    test('respects its delay before moving', () {
      var updates = 0;
      final tween = FDoubleTween(from: 0, to: 1, duration: 0.5, delay: 0.5, onUpdate: (_) => updates++)..start();

      tween.update(0.25);
      expect(updates, 0, reason: 'tween moved during its delay');

      tween.update(0.5);
      expect(updates, greaterThan(0));
    });

    test('fires onComplete exactly once', () {
      var completions = 0;
      final tween = FDoubleTween(from: 0, to: 1, duration: 0.2, onComplete: () => completions++)..start();

      for (int i = 0; i < 60; i++) {
        tween.update(1 / 60);
      }
      expect(completions, 1);
    });

    test('yoyo reverses instead of jumping back', () {
      final values = <double>[];
      final tween = FDoubleTween(
        from: 0,
        to: 10,
        duration: 0.1,
        repeatCount: 1,
        yoyo: true,
        onUpdate: values.add,
      )..start();

      for (int i = 0; i < 30; i++) {
        tween.update(1 / 60);
      }

      expect(values.reduce((a, b) => a > b ? a : b), closeTo(10, 0.5));
      expect(values.last, lessThan(10));
    });

    test('manager drives and retires its tweens', () {
      final manager = FTweenManager();
      var completed = false;
      manager.add(FDoubleTween(from: 0, to: 1, duration: 0.1, onComplete: () => completed = true));

      for (int i = 0; i < 20; i++) {
        manager.update(1 / 60);
      }
      expect(completed, isTrue);
    });
  });

  group('FTimer', () {
    late FEngine engine;
    setUp(() => engine = FEngine());
    tearDown(() => engine.dispose());

    FTimer attach(FTimer timer) {
      engine.scene.addChild(timer);
      return timer;
    }

    void run(double seconds) {
      final steps = (seconds * 60).round();
      for (int i = 0; i < steps; i++) {
        engine.tree.process(1 / 60);
      }
    }

    test('fires after its wait time', () {
      var fired = 0;
      final timer = attach(FTimer(waitTime: 0.5, oneShot: true, autoStart: true));
      timer.timeout.connect((_) => fired++);

      run(0.4);
      expect(fired, 0);
      run(0.2);
      expect(fired, 1);
    });

    test('a repeating timer keeps firing', () {
      var fired = 0;
      final timer = attach(FTimer(waitTime: 0.1, autoStart: true));
      timer.timeout.connect((_) => fired++);

      run(0.55);
      expect(fired, greaterThanOrEqualTo(4));
    });

    test('a one-shot timer fires once', () {
      var fired = 0;
      final timer = attach(FTimer(waitTime: 0.1, oneShot: true, autoStart: true));
      timer.timeout.connect((_) => fired++);

      run(1.0);
      expect(fired, 1);
    });

    test('stops while the tree is paused', () {
      // ProcessMode was inert before, so a "paused" game kept counting down.
      var fired = 0;
      final timer = attach(FTimer(waitTime: 0.2, oneShot: true, autoStart: true));
      timer.timeout.connect((_) => fired++);

      engine.tree.paused = true;
      run(1.0);
      expect(fired, 0, reason: 'timer ran while the tree was paused');

      engine.tree.paused = false;
      run(0.3);
      expect(fired, 1);
    });
  });

  group('FScoreSystem', () {
    test('addFlat accumulates without a combo bonus', () {
      final score = FScoreSystem();
      score.addFlat(10);
      score.addFlat(5);
      expect(score.score, 15);
    });

    test('add() builds a combo, and the multiplier grows with it', () {
      final score = FScoreSystem();
      score.add(100);
      final firstMultiplier = score.comboMultiplier;
      score.add(100);
      expect(score.comboCount, 2);
      expect(score.comboMultiplier, greaterThan(firstMultiplier));
    });

    test('breakCombo resets the streak but keeps the score', () {
      final score = FScoreSystem();
      score.add(100);
      final earned = score.score;
      score.breakCombo();
      expect(score.comboCount, 0);
      expect(score.score, earned);
    });

    test('tracks a high score across resets', () {
      final score = FScoreSystem();
      score.addFlat(100);
      score.reset();
      expect(score.score, 0);
      expect(score.highScore, 100);
    });
  });
}
