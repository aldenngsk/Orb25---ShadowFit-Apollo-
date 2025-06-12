class ShadowSoldier {
  final String name;
  final int requiredSets;
  String grade = 'Beast';
  int xp = 0;
  bool isUnlocked = false;

  ShadowSoldier({
    required this.name,
    required this.requiredSets,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'requiredSets': requiredSets,
      'grade': grade,
      'xp': xp,
      'isUnlocked': isUnlocked,
    };
  }

  factory ShadowSoldier.fromMap(Map<String, dynamic> map) {
    final soldier = ShadowSoldier(
      name: map['name'] as String,
      requiredSets: map['requiredSets'] as int,
    );
    soldier.grade = map['grade'] as String;
    soldier.xp = map['xp'] as int;
    soldier.isUnlocked = map['isUnlocked'] as bool;
    return soldier;
  }

  String getNextGrade() {
    if (xp < 100) return 'Infantry';
    if (xp < 200) return 'Elite';
    if (xp < 350) return 'Knight';
    if (xp < 500) return 'Knight Elite';
    if (xp < 700) return 'Commander';
    if (xp < 900) return 'Marshall';
    if (xp < 1150) return 'Grand-Marshall';
    return 'Max Level';
  }

  int getRequiredXPForNextGrade() {
    if (xp < 100) return 100 - xp;
    if (xp < 200) return 200 - xp;
    if (xp < 350) return 350 - xp;
    if (xp < 500) return 500 - xp;
    if (xp < 700) return 700 - xp;
    if (xp < 900) return 900 - xp;
    if (xp < 1150) return 1150 - xp;
    return 0;
  }

  void updateGrade() {
    if (xp >= 1150) {
      grade = 'Grand-Marshall';
    } else if (xp >= 900) grade = 'Marshall';
    else if (xp >= 700) grade = 'Commander';
    else if (xp >= 500) grade = 'Knight Elite';
    else if (xp >= 350) grade = 'Knight';
    else if (xp >= 200) grade = 'Elite';
    else if (xp >= 100) grade = 'Infantry';
    else grade = 'Beast';
  }
} 