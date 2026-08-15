import 'dart:math' as math;

import 'package:flash/flash.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import '../shared/demo_controls.dart';
import '../shared/demo_page.dart';
import '../shared/demo_theme.dart';

const double _cellSize = 46;
const FSquareGrid _grid = FSquareGrid(cellWidth: _cellSize);
const int _half = 9;

/// Grid agents: [FChaserAgent], [FFleeAgent], [FWandererAgent] and
/// [FPatrolAgent].
///
/// An agent is a node. It is driven by the engine's frame loop like anything
/// else, and its cooldown is in seconds accumulated from `dt` — so pausing the
/// tree pauses it, and it does not need a wall-clock timestamp fed to it. Toggle
/// the pause control and watch them stop.
///
/// Each agent is pointed at the player *node*, not at a coordinate: it converts
/// that node's world position through the grid itself.
class GridAiDemo extends StatefulWidget {
  const GridAiDemo({super.key});

  @override
  State<GridAiDemo> createState() => _GridAiDemoState();
}

class _GridAiDemoState extends State<GridAiDemo> {
  /// Walls, so `canEnter` has something to refuse.
  late final Set<String> _walls = _buildWalls();

  /// The node the agents track. Held here so it exists before they do.
  late final FNode _player = _PlayerNode();

  late List<_Entry> _agents;

  FEngine? _engine;
  int _playerX = 0;
  int _playerY = 0;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _resetAgents();
    _syncPlayer();
  }

  static Set<String> _buildWalls() {
    const generator = FProceduralGenerator(seed: 99);
    final walls = <String>{};
    for (int x = -_half; x <= _half; x++) {
      for (int y = -_half; y <= _half; y++) {
        if (x.abs() <= 2 && y.abs() <= 2) continue; // keep the middle clear
        if (generator.hasFeature(x, y, 0.14)) walls.add('$x,$y');
      }
    }
    return walls;
  }

  bool _walkable(int x, int y) =>
      x.abs() <= _half && y.abs() <= _half && !_walls.contains('$x,$y');

  void _resetAgents() {
    _agents = [
      _Entry('chaser', DemoTheme.danger,
          _Chaser(x: -7, y: -7, walkable: _walkable, colour: DemoTheme.danger)),
      _Entry('fleer', DemoTheme.accent,
          _Fleer(x: 7, y: 7, walkable: _walkable, colour: DemoTheme.accent)),
      _Entry('wanderer', DemoTheme.positive,
          _Wanderer(x: -7, y: 7, walkable: _walkable, colour: DemoTheme.positive)),
      _Entry('patroller', DemoTheme.warning,
          _Patroller(x: 7, y: -7, walkable: _walkable, colour: DemoTheme.warning)),
    ];
    for (final entry in _agents) {
      // Both are needed: the grid is how a world position becomes a cell.
      entry.agent.target = _player;
      entry.agent.grid = _grid;
    }
  }

  void _syncPlayer() {
    _player.transform.position = _grid.gridToWorld(_playerX, _playerY, height: 8);
  }

  void _movePlayer(int dx, int dy) {
    final nx = _playerX + dx;
    final ny = _playerY + dy;
    if (!_walkable(nx, ny)) return;
    setState(() {
      _playerX = nx;
      _playerY = ny;
      _syncPlayer();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pausing the tree is the point of the toggle, so it is applied to the
    // engine rather than by not building the agents.
    _engine?.tree.paused = _paused;

    return DemoPage(
      title: 'Grid AI',
      subtitle: 'Agents are nodes: the frame loop drives them, dt times them.',
      accent: DemoTheme.positive,
      controls: [
        DemoPanel(
          title: 'Move',
          tint: DemoTheme.positive,
          children: [_DPad(onMove: _movePlayer)],
        ),
        DemoToggle(
          label: 'Pause the tree',
          value: _paused,
          tint: DemoTheme.warning,
          onChanged: (value) => setState(() => _paused = value),
        ),
        DemoButton(
          label: 'Reset agents',
          icon: Icons.restart_alt_rounded,
          onPressed: () => setState(_resetAgents),
        ),
        DemoPanel(
          title: 'Legend',
          tint: DemoTheme.positive,
          children: [
            DemoLegend(
              entries: [
                for (final entry in _agents) (color: entry.colour, label: entry.label),
                (color: DemoTheme.textPrimary, label: 'you'),
                (color: DemoTheme.accentAlt, label: 'wall'),
              ],
            ),
          ],
        ),
      ],
      readouts: [
        DemoStat(label: 'You', value: '$_playerX, $_playerY'),
        DemoStat(label: 'Tree', value: _paused ? 'paused' : 'running'),
      ],
      hint: 'Pause stops them: their cooldowns come from dt, not from the clock.',
      scene: FView(
        onReady: (engine) => _engine = engine..tree.paused = _paused,
        child: Stack(
          children: [
            FCamera(
              position: v.Vector3(0, 1150, 0),
              rotation: v.Vector3(-math.pi / 2, 0, 0),
              isOrthographic: true,
              orthographicSize: 480,
            ),
            FGridView(
              grid: _grid,
              children: [
                FTileMap(
                  name: 'Board',
                  sortLayer: -3,
                  tilePainter: (canvas, centre, size, x, y) {
                    if (x.abs() > _half || y.abs() > _half) return;
                    final wall = _walls.contains('$x,$y');
                    canvas.drawRect(
                      Rect.fromCenter(
                        center: centre,
                        width: size.width - 3,
                        height: size.height - 3,
                      ),
                      Paint()
                        ..color = wall
                            ? DemoTheme.accentAlt.withValues(alpha: 0.55)
                            : ((x + y).isEven
                                  ? const Color(0xFF141A2A)
                                  : const Color(0xFF10141F)),
                    );
                  },
                ),

                // Both the player and the agents are existing FNode instances
                // put into the tree, rather than nodes the widget creates.
                _Host(node: _player, name: 'Player'),
                for (final entry in _agents)
                  _Host(key: ObjectKey(entry.agent), node: entry.agent, name: entry.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry {
  _Entry(this.label, this.colour, this.agent);

  final String label;
  final Color colour;
  final FGridAgent agent;
}

/// Puts an already-built [FNode] into the tree.
///
/// The declarative widgets create their own node; this is the escape hatch for
/// a node that has to exist first — here, because the agents need a reference
/// to the player node before any of them are built.
class _Host extends FNodeWidget {
  const _Host({super.key, required this.node, super.name});

  final FNode node;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends FNodeWidgetState<_Host, FNode> {
  @override
  FNode createNode() => widget.node;
}

/// Shared drawing and wall logic for the four agents.
///
/// Grids are XZ with +Y up, and a node draws in its local XY, so every marker
/// gets a quarter turn to lie flat under a top-down camera.
mixin _BoardAgent on FGridAgent {
  Color get colour;
  bool Function(int, int) get walkable;

  @override
  bool canEnter(int cellX, int cellY) => walkable(cellX, cellY);

  @override
  void process(double dt) {
    super.process(dt);
    transform.position = _grid.gridToWorld(x, y, height: 6);
    transform.rotation = v.Vector3(math.pi / 2, 0, 0);
  }

  @override
  Rect? get bounds => Rect.fromCircle(center: Offset.zero, radius: 18);

  @override
  void draw(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 15, Paint()..color = colour);
    canvas.drawCircle(
      Offset.zero,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colour.withValues(alpha: 0.4),
    );
  }
}

class _Chaser extends FChaserAgent with _BoardAgent {
  _Chaser({required super.x, required super.y, required this.walkable, required this.colour})
    : super(detectionRange: 14, moveCooldown: 0.45);
  @override
  final bool Function(int, int) walkable;
  @override
  final Color colour;
}

class _Fleer extends FFleeAgent with _BoardAgent {
  _Fleer({required super.x, required super.y, required this.walkable, required this.colour})
    : super(fleeRange: 7, moveCooldown: 0.4);
  @override
  final bool Function(int, int) walkable;
  @override
  final Color colour;
}

class _Wanderer extends FWandererAgent with _BoardAgent {
  _Wanderer({required super.x, required super.y, required this.walkable, required this.colour})
    : super(wanderRadius: 8, seed: 4, moveCooldown: 0.55);
  @override
  final bool Function(int, int) walkable;
  @override
  final Color colour;
}

class _Patroller extends FPatrolAgent with _BoardAgent {
  _Patroller({required super.x, required super.y, required this.walkable, required this.colour})
    : super(
        moveCooldown: 0.5,
        path: const [(x: 7, y: -7), (x: 7, y: 7), (x: -3, y: 7), (x: -3, y: -7)],
      );
  @override
  final bool Function(int, int) walkable;
  @override
  final Color colour;
}

/// The node the agents track.
class _PlayerNode extends FNode {
  _PlayerNode() : super(name: 'Player') {
    transform.rotation = v.Vector3(math.pi / 2, 0, 0);
  }

  @override
  Rect? get bounds => Rect.fromCircle(center: Offset.zero, radius: 20);

  @override
  void draw(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 17, Paint()..color = DemoTheme.textPrimary);
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.onMove});

  final void Function(int dx, int dy) onMove;

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon, int dx, int dy) => Padding(
      padding: const EdgeInsets.all(2),
      child: DemoButton(label: '', icon: icon, onPressed: () => onMove(dx, dy)),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        key(Icons.keyboard_arrow_up_rounded, 0, -1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            key(Icons.keyboard_arrow_left_rounded, -1, 0),
            key(Icons.keyboard_arrow_down_rounded, 0, 1),
            key(Icons.keyboard_arrow_right_rounded, 1, 0),
          ],
        ),
      ],
    );
  }
}
