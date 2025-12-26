/// Card Asset Generator
///
/// This script generates SVG card assets for the El-Shayeb game.
/// Run with: dart run tool/generate_cards.dart
///
library;
/*
import 'dart:io';

void main() {
  final outputDir = Directory('assets/cards');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final suits = ['hearts', 'diamonds', 'clubs', 'spades'];
  final ranks = [
    'ace',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'jack',
    'queen',
    'king'
  ];
  final rankSymbols = [
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K'
  ];
  final suitSymbols = {
    'hearts': '♥',
    'diamonds': '♦',
    'clubs': '♣',
    'spades': '♠'
  };
  final redSuits = ['hearts', 'diamonds'];

  for (final suit in suits) {
    for (int i = 0; i < ranks.length; i++) {
      final rank = ranks[i];
      final symbol = rankSymbols[i];
      final suitSymbol = suitSymbols[suit]!;
      final isRed = redSuits.contains(suit);
      final color = isRed ? '#DC3545' : '#1A1A1A';

      final svg = generateCardSvg(symbol, suitSymbol, color);
      final file = File('${outputDir.path}/${suit}_$rank.svg');
      file.writeAsStringSync(svg);
      print('Generated: ${file.path}');
    }
  }

  print('Done! Generated ${suits.length * ranks.length} card SVGs.');
}

String generateCardSvg(String rank, String suit, String color) {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 70 100">
  <defs>
    <linearGradient id="cardFace" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" style="stop-color:#FAFAFA"/>
      <stop offset="100%" style="stop-color:#E8E8E8"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="1" dy="2" stdDeviation="2" flood-opacity="0.2"/>
    </filter>
  </defs>
  
  <!-- Card background -->
  <rect width="70" height="100" rx="8" fill="url(#cardFace)" filter="url(#shadow)"/>
  <rect x="1" y="1" width="68" height="98" rx="7" fill="none" stroke="rgba(0,0,0,0.1)" stroke-width="1"/>
  
  <!-- Top left corner -->
  <text x="6" y="18" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="$color">$rank</text>
  <text x="6" y="30" font-family="Arial, sans-serif" font-size="12" fill="$color">$suit</text>
  
  <!-- Center suit -->
  <text x="35" y="60" text-anchor="middle" font-family="Arial, sans-serif" font-size="32" fill="$color">$suit</text>
  
  <!-- Bottom right corner (rotated) -->
  <g transform="rotate(180, 35, 50)">
    <text x="6" y="18" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="$color">$rank</text>
    <text x="6" y="30" font-family="Arial, sans-serif" font-size="12" fill="$color">$suit</text>
  </g>
</svg>''';
}
*/