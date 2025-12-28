/// Collectible types and power-up definitions for CubeQuest
library;

import 'package:flutter/material.dart';

/// Types of collectible items in the game
enum CollectibleType {
  diamond(points: 10, color: Colors.cyanAccent, emoji: '💎'),
  star(points: 25, color: Colors.amber, emoji: '⭐'),
  key(points: 0, color: Colors.orange, emoji: '🔑'),
  heart(points: 0, color: Colors.red, emoji: '❤️');

  final int points;
  final Color color;
  final String emoji;

  const CollectibleType({required this.points, required this.color, required this.emoji});
}

/// Types of power-ups
enum PowerUpType {
  speed(duration: Duration(seconds: 5), color: Colors.orange, name: 'Hız'),
  shield(duration: Duration(seconds: 10), color: Colors.blue, name: 'Kalkan'),
  magnet(duration: Duration(seconds: 5), color: Colors.purple, name: 'Mıknatıs'),
  ghost(duration: Duration(seconds: 3), color: Colors.grey, name: 'Hayalet');

  final Duration duration;
  final Color color;
  final String name;

  const PowerUpType({required this.duration, required this.color, required this.name});
}

/// A collectible item on the grid
class Collectible {
  final int x;
  final int z;
  final CollectibleType type;

  const Collectible({required this.x, required this.z, required this.type});

  String get key => '$x,$z';
}

/// A power-up on the grid
class PowerUp {
  final int x;
  final int z;
  final PowerUpType type;

  const PowerUp({required this.x, required this.z, required this.type});

  String get key => '$x,$z';
}
