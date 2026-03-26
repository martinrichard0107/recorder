// lib/models/player.dart

// 定義球員在場上的位置
enum CourtPosition {
  p1,
  p2,
  p3,
  p4,
  p5,
  p6,
  bench, // 板凳區
}

// 定義球員的角色
enum PlayerRole {
  setter,   // 舉球員
  outside,  // 大砲 (主攻)
  opposite, // 副攻
  middle,   // 攔中 (快攻)
  libero,   // 自由球員
}

class Player {
  final String id;
  final int jerseyNo;
  final String name;
  final PlayerRole role;
  final String? pairedPlayerId; // 用於記錄自由球員替換了誰

  Player({
    required this.id,
    required this.jerseyNo,
    required this.name,
    required this.role,
    this.pairedPlayerId,
  });

  // 拷貝並修改部分屬性
  Player copyWith({
    String? id,
    int? jerseyNo,
    String? name,
    PlayerRole? role,
    String? pairedPlayerId,
  }) {
    return Player(
      id: id ?? this.id,
      jerseyNo: jerseyNo ?? this.jerseyNo,
      name: name ?? this.name,
      role: role ?? this.role,
      pairedPlayerId: pairedPlayerId ?? this.pairedPlayerId,
    );
  }

  // --- 資料庫 JSON 轉換 (Start) ---
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id']?.toString() ?? '', 
      // ★ 這裡支援讀取資料庫的 jersey_no
      jerseyNo: map['jersey_no'] ?? map['jerseyNo'] ?? 0, 
      name: map['name'] ?? 'Unknown',
      // ★ 這裡支援讀取資料庫的 primary_role
      role: _parseRole(map['primary_role'] ?? map['role']), 
      pairedPlayerId: map['pairedPlayerId'],
    );
  }

  // 輔助方法：將資料庫字串安全轉成 Flutter Enum
  static PlayerRole _parseRole(String? roleStr) {
    if (roleStr == null) return PlayerRole.outside;
    return PlayerRole.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == roleStr.toLowerCase(),
      orElse: () => PlayerRole.outside,
    );
  }
  // --- 資料庫 JSON 轉換 (End) ---
}