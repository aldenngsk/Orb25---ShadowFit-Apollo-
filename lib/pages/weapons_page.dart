import 'package:flutter/material.dart';

class WeaponsPage extends StatelessWidget {
  const WeaponsPage({Key? key}) : super(key: key);

  final List<String> weapons = const [
    'Demon King’s Dagger',
    'Kamish’s Wrath',
    'Baruka’s Dagger',
    'Knight Killer',
    'Demon Monarch’s Longsword',
    'Demon Monarch’s Shortsword',
    'Demon Monarch’s Daggers',
    'Demon Monarch’s Armor',
    'Demon Monarch’s Ring',
    'Demon Monarch’s Necklace',
    'Demon Monarch’s Earrings',
    'Demon Monarch’s Belt',
    'Demon Monarch’s Boots',
    'Demon Monarch’s Gloves',
    'Demon Monarch’s Cloak',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weapons'),
      ),
      body: ListView.builder(
        itemCount: weapons.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.security),
            title: Text(weapons[index]),
          );
        },
      ),
    );
  }
} 