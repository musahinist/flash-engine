import 'package:flutter/material.dart';

import '../shared/demo_catalog.dart';
import '../shared/demo_theme.dart';
import 'cube/cube_game_screen.dart';
import 'cube_quest/cube_quest_screen.dart';
import 'cube_runner/cube_runner_screen.dart';

/// The games list.
///
/// This was a second copy of the examples catalogue — its own card widget, its
/// own gradient, its own data class — so the two looked different for no reason
/// and had to be edited in parallel. It is the same [CatalogPage] now.
class GamesCatalog extends StatelessWidget {
  const GamesCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return CatalogPage(
      title: 'Games',
      subtitle: 'Complete games, to show the engine doing a whole job.',
      sections: [
        CatalogSection(
          title: 'Built on the engine',
          entries: [
            CatalogEntry(
              title: 'CubeRunner',
              description: 'Tilemap, grid AI and power-ups on the Flash scene graph.',
              icon: Icons.rocket_launch_rounded,
              builder: (_) => const CubeRunnerScreen(),
            ),
          ],
        ),
        CatalogSection(
          title: 'Plain Flutter',
          entries: [
            CatalogEntry(
              title: 'CubeQuest',
              description: 'Collect gems, dodge enemies, use power-ups.',
              icon: Icons.sports_esports_rounded,
              tint: DemoTheme.accentAlt,
              builder: (_) => const CubeQuestScreen(),
            ),
            CatalogEntry(
              title: 'Cube Roller',
              description: 'Roll and jump across an infinite isometric grid.',
              icon: Icons.view_in_ar_rounded,
              tint: DemoTheme.positive,
              builder: (_) => const CubeGameScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
