import 'package:flutter/material.dart';

import 'demo_theme.dart';

/// One entry in a catalogue.
class CatalogEntry {
  const CatalogEntry({
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
    this.tint = DemoTheme.accent,
  });

  final String title;

  /// What the entry shows. Name the API where it is not obvious from the title
  /// — the catalogue is how someone finds the example for the class they are
  /// looking at.
  final String description;

  final IconData icon;
  final Color tint;
  final WidgetBuilder builder;
}

/// A named group of entries.
class CatalogSection {
  const CatalogSection({required this.title, required this.entries});

  final String title;
  final List<CatalogEntry> entries;
}

/// The grid used by both the examples list and the games list.
///
/// The two were separate copies of the same widget with different gradients and
/// slightly different cards, so they drifted; and both hard-coded three columns,
/// which on a desktop window left the cards stretched across a third of the
/// screen each and on a narrow phone squeezed the descriptions to nothing.
class CatalogPage extends StatelessWidget {
  const CatalogPage({
    super.key,
    required this.title,
    required this.sections,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<CatalogSection> sections;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: DemoTheme.backgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Aim for cards around 190pt wide, so the column count follows the
              // window instead of being fixed at three.
              final columns = (constraints.maxWidth / 190).floor().clamp(2, 6);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (canPop) ...[
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: DemoTheme.textPrimary,
                            ),
                            const SizedBox(width: DemoTheme.gap),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: DemoTheme.title.copyWith(fontSize: 28, letterSpacing: 0.6),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(subtitle!, style: DemoTheme.subtitle),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final section in sections) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text(section.title.toUpperCase(), style: DemoTheme.label),
                            const SizedBox(width: DemoTheme.gapLarge),
                            const Expanded(child: Divider(color: Color(0x22EFF3FF), height: 1)),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          // Tall enough for two lines of description at the
                          // narrowest column width the clamp allows.
                          mainAxisExtent: 132,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _CatalogCard(entry: section.entries[index]),
                          childCount: section.entries.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({required this.entry});

  final CatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: entry.builder)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: entry.tint.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: entry.tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(entry.icon, color: entry.tint, size: 19),
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DemoTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: Text(
                  entry.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: DemoTheme.textMuted, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
