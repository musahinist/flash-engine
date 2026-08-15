import 'dart:math';

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

/// [FEventBus]: typed events between things that do not know about each other.
///
/// Three emitters publish; three listeners react. Nothing here holds a
/// reference to anything else — that is the point, and it is why the
/// subscriptions have to be cancelled in [dispose] or they outlive the page.
class EventBusDemo extends StatefulWidget {
  const EventBusDemo({super.key});

  @override
  State<EventBusDemo> createState() => _EventBusDemoState();
}

/// A payload event. `FDataEvent<T>` covers the simple cases; a class of your
/// own is worth it once the payload has more than one field.
class _PulseEvent extends FEvent {
  _PulseEvent(this.channel, this.strength);

  final int channel;
  final double strength;

  @override
  String get name => 'Pulse(ch$channel, ${strength.toStringAsFixed(2)})';
}

class _ResetEvent extends FEvent {}

class _EventBusDemoState extends State<EventBusDemo> {
  final FEventBus _bus = FEventBus.instance;
  final List<FEventSubscription> _subscriptions = [];
  final Random _random = Random(11);

  final List<double> _charge = [0, 0, 0];
  final List<String> _log = [];
  int _pulses = 0;

  static const List<Color> _channelColors = [
    DemoTheme.accent,
    DemoTheme.accentAlt,
    DemoTheme.warning,
  ];

  @override
  void initState() {
    super.initState();

    // Each listener knows only the event type. It has never heard of whatever
    // publishes it.
    _subscriptions.add(
      _bus.on<_PulseEvent>((event) {
        if (!mounted) return;
        setState(() {
          _pulses++;
          _charge[event.channel] = (_charge[event.channel] + event.strength).clamp(0.0, 1.0);
          _pushLog('pulse   ch${event.channel}  +${event.strength.toStringAsFixed(2)}');
        });
      }),
    );

    // A second, independent listener on the same type. Both run.
    _subscriptions.add(
      _bus.on<_PulseEvent>((event) {
        if (!mounted) return;
        if (event.strength > 0.6) {
          setState(() => _pushLog('strong pulse on ch${event.channel}'));
        }
      }),
    );

    _subscriptions.add(
      _bus.on<_ResetEvent>((_) {
        if (!mounted) return;
        setState(() {
          _charge.fillRange(0, _charge.length, 0);
          _pushLog('reset');
        });
      }),
    );
  }

  @override
  void dispose() {
    // The bus is a singleton and outlives this page. Without this, every visit
    // would leave another set of handlers behind, all still firing.
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _pushLog(String line) {
    _log.insert(0, line);
    if (_log.length > 7) _log.removeLast();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Event Bus',
      subtitle: 'FEventBus: publish a type, anything listening for it reacts.',
      controlsWidth: 250,
      controls: [
        for (int channel = 0; channel < 3; channel++)
          DemoButton(
            label: 'Pulse channel $channel',
            icon: Icons.bolt_rounded,
            tint: _channelColors[channel],
            onPressed: () => _bus.emit(_PulseEvent(channel, 0.2 + _random.nextDouble() * 0.6)),
          ),
        DemoButton(
          label: 'Broadcast reset',
          icon: Icons.restart_alt_rounded,
          tint: DemoTheme.danger,
          onPressed: () => _bus.emit(_ResetEvent()),
        ),
        DemoPanel(
          title: 'Received',
          children: [
            for (final line in _log)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line, style: DemoTheme.body.copyWith(fontSize: 11)),
              ),
            if (_log.isEmpty) Text('nothing yet', style: DemoTheme.body.copyWith(fontSize: 11)),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'Pulses', value: '$_pulses'),
        DemoStat(label: 'Handlers', value: '${_subscriptions.length}'),
      ],
      hint: 'Two separate handlers listen for _PulseEvent; both of them run.',
      scene: FView(
        autoUpdate: false,
        child: Stack(
          children: [
            FCamera(position: v.Vector3(0, 0, 900)),
            for (int channel = 0; channel < 3; channel++)
              FSphere(
                position: v.Vector3(-260 + channel * 260.0, 0, 0),
                radius: 45 + _charge[channel] * 55,
                color: Color.lerp(
                  _channelColors[channel].withValues(alpha: 0.25),
                  _channelColors[channel],
                  _charge[channel],
                )!,
              ),
            for (int channel = 0; channel < 3; channel++)
              FLabel(
                text: 'ch$channel',
                position: v.Vector3(-260 + channel * 260.0, -160, 0),
                style: const TextStyle(color: DemoTheme.textMuted, fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
