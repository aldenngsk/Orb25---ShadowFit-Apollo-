import 'package:flutter/material.dart';

class Weapon {
  final String name;
  final int attack;
  final int magic;
  final String rarity;

  const Weapon({
    required this.name,
    required this.attack,
    required this.magic,
    required this.rarity,
  });
}

class WeaponsPage extends StatelessWidget {
  const WeaponsPage({Key? key}) : super(key: key);

  final List<Weapon> weapons = const [
    Weapon(name: 'Demon King’s Dagger', attack: 120, magic: 80, rarity: 'Legendary'),
    Weapon(name: 'Kamish’s Wrath', attack: 200, magic: 150, rarity: 'Mythic'),
    Weapon(name: 'Baruka’s Dagger', attack: 90, magic: 60, rarity: 'Epic'),
    Weapon(name: 'Knight Killer', attack: 100, magic: 40, rarity: 'Rare'),
    Weapon(name: 'Demon Monarch’s Longsword', attack: 180, magic: 120, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Shortsword', attack: 160, magic: 110, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Daggers', attack: 140, magic: 100, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Armor', attack: 0, magic: 200, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Ring', attack: 20, magic: 180, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Necklace', attack: 15, magic: 170, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Earrings', attack: 10, magic: 160, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Belt', attack: 5, magic: 150, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Boots', attack: 0, magic: 140, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Gloves', attack: 25, magic: 130, rarity: 'Legendary'),
    Weapon(name: 'Demon Monarch’s Cloak', attack: 0, magic: 120, rarity: 'Legendary'),
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
          final weapon = weapons[index];
          return ListTile(
            leading: const Icon(Icons.security),
            title: Text(weapon.name),
            subtitle: Text('ATK: ${weapon.attack}  |  MAG: ${weapon.magic}  |  Rarity: ${weapon.rarity}'),
          );
        },
      ),
    );
  }
} 