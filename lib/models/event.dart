import 'package:system_recorder/models/player.dart';

// ★ 事件大分類
enum EventCategory { serve, receive, set, attack, tip, block, error, oppError }

// ★ 分數結果 (為了未來快速畫圓餅圖)
enum EventOutcome { teamPoint, oppPoint, neutral }

class EventLog {
  // 1. 基本識別
  final String id;             // 本次事件 UUID
  final String matchId;        // 比賽 ID
  final String setNumber;      // 局數 (例如 "1")
  final String rallyId;        // ★ 來回 ID (用來算一球打幾次)
  final DateTime timestamp;    // 發生時間

  // 2. 球員當下狀態
  final String playerId;
  final String playerName;
  final int playerJerseyNo;
  final PlayerRole playerRole;
  final CourtPosition positionAtTime;

  // 3. 事件核心動作
  final EventCategory category; // 例如 Attack
  final String detailType;      // 例如 Kill, Out, BlockedDown

  // 4. 結果與進階數據分析
  final EventOutcome outcome;   // 得分/失分/平手
  final int scoreTeamA;         // 事件發生後的比分
  final int scoreTeamB;
  
  final bool isForcedError;     // ★ 是否為受迫性失誤
  final String pointReason;     // ★ 得分歸屬原因 (例如 OurAttack, OppError)
  final bool rotationApplied;   // 這球有沒有造成輪轉？

  // 5. 復原用快照
  final dynamic beforeStateSnapshot; 

  EventLog({
    required this.id,
    required this.matchId,
    required this.setNumber,
    required this.rallyId,
    required this.timestamp,
    required this.playerId,
    required this.playerName,
    required this.playerJerseyNo,
    required this.playerRole,
    required this.positionAtTime,
    required this.category,
    required this.detailType,
    required this.outcome,
    required this.scoreTeamA,
    required this.scoreTeamB,
    required this.isForcedError,
    required this.pointReason,
    required this.rotationApplied,
    this.beforeStateSnapshot,
  });
}