enum PlayerRole {
  setter,       // 舉球
  outside,      // 大砲
  opposite,     // 副攻
  middle,       // 欄中
  libero,       // 自由球員
}

enum CourtPosition {
  p1, p2, p3, p4, p5, p6, bench 
}

class Player {
  final String id;  //// 這裡維持 String，未來要用資料庫的編號或 UUID(亂碼)再決定
  final int jerseyNo;
  final String name;
  final PlayerRole role;
  
  String? pairedPlayerId; // 自由球員專用：記錄他換下了誰

  Player({
    required this.id,
    required this.jerseyNo,
    required this.name,
    required this.role,
    this.pairedPlayerId,
  });

  // --- 資料庫部分 (Start) ---

  // 1. 把資料庫傳來的 Map 轉成 Player 物件
  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '', // 如果資料庫沒給 ID，給空字串防爆
      jerseyNo: map['jerseyNo'] ?? 0,
      name: map['name'] ?? 'Unknown',
      // 把字串轉回 Enum (例如資料庫存 "setter" -> 轉成 PlayerRole.setter)
      role: PlayerRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => PlayerRole.outside,
      ),
      pairedPlayerId: map['pairedPlayerId'],
    );
  }

  // 2. 把 Player 物件轉成 Map (準備存入資料庫)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jerseyNo': jerseyNo,
      'name': name,
      'role': role.toString().split('.').last, // 只存 "setter", "libero" 等字串
      'pairedPlayerId': pairedPlayerId,
    };
  }
  // --- 資料庫部分 (End) ---

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
}