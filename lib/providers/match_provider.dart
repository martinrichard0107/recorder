import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/rotation_service.dart';
import '../services/libero_service.dart';
import '../services/event_rules.dart';

class MatchProvider extends ChangeNotifier {
  // --- 新增：進階數據記憶區 ---
  List<PlayLog> matchPlayLogs = []; 
  String currentRallyId = DateTime.now().millisecondsSinceEpoch.toString(); 
  int currentTeamRotation = 1;

  final String matchId = const Uuid().v4();
  int _currentSet = 1;
  String _currentRallyId = const Uuid().v4(); 
  String _opponentName = "對手隊伍"; 

  int _scoreTeamA = 0;
  int _scoreTeamB = 0;
  bool _isOurServe = true;

  final List<String> _setScoreHistory = [];
  List<Player> _allPlayers = []; // ★ 這裡原本是空的，現在靠 startNewSet 傳進來
  
  Map<CourtPosition, String?> _positions = {
    CourtPosition.p1: null, CourtPosition.p2: null, CourtPosition.p3: null,
    CourtPosition.p4: null, CourtPosition.p5: null, CourtPosition.p6: null,
  };

  String? _liberoId;        
  bool _isLiberoOnCourt = false; 
  String? _pairedPlayerId;  
  String? _selectedPlayerId;
  
  final List<EventLog> _eventHistory = [];

  // --- Getters ---
  int get scoreTeamA => _scoreTeamA;
  int get scoreTeamB => _scoreTeamB;
  int get currentSet => _currentSet;
  bool get isOurServe => _isOurServe;
  String get opponentName => _opponentName;
  Map<CourtPosition, String?> get positions => _positions;
  String? get selectedPlayerId => _selectedPlayerId;
  List<String> get setScoreHistory => _setScoreHistory;
  
  List<EventLog> get history => List.unmodifiable(_eventHistory.reversed);
  
  List<EventLog> get currentSetHistory {
    return _eventHistory.where((e) => e.setNumber == _currentSet.toString()).toList().reversed.toList();
  }
  
  EventLog? get lastEvent => _eventHistory.isNotEmpty ? _eventHistory.last : null;

  Player? get selectedPlayer {
    if (_selectedPlayerId == null) return null;
    return getPlayerById(_selectedPlayerId!);
  }

  Player? get currentLibero {
    if (_liberoId == null) return null;
    return getPlayerById(_liberoId!);
  }

  List<Player> get benchPlayers {
    final onCourtIds = _positions.values.whereType<String>().toSet();
    if (_liberoId != null) onCourtIds.add(_liberoId!);
    return _allPlayers.where((p) => !onCourtIds.contains(p.id)).toList();
  }

  void substitutePlayer(CourtPosition pos, String newPlayerId) {
    _positions[pos] = newPlayerId;
    _selectedPlayerId = newPlayerId; 
    notifyListeners();
  }

  // --- 數據統計邏輯 ---
  int get totalAttacks => _eventHistory.where((e) => e.category == EventCategory.attack).length;
  int get totalReceives => _eventHistory.where((e) => e.category == EventCategory.receive).length;
  
  double get attackEfficiency {
    final attacks = _eventHistory.where((e) => e.category == EventCategory.attack).toList();
    if (attacks.isEmpty) return 0.0;
    final kills = attacks.where((e) => e.detailType == 'Kill').length;
    final errors = attacks.where((e) => e.detailType == 'BlockedDown' || e.detailType == 'Out').length;
    return (kills - errors) / attacks.length;
  }

  double get passQuality {
    final receives = _eventHistory.where((e) => e.category == EventCategory.receive).toList();
    if (receives.isEmpty) return 0.0;
    double totalWeight = 0;
    for (var r in receives) {
      // 🚨 修復警告：加上大括號
      if (r.detailType == 'Perfect') {
        totalWeight += 3;
      } else if (r.detailType == 'Good') {
        totalWeight += 2;
      } else if (r.detailType == 'Bad') {
        totalWeight += 1;
      }
    }
    return totalWeight / receives.length;
  }

  List<Map<String, dynamic>> getBoxScore() {
    final activePlayerIds = _eventHistory.map((e) => e.playerId).toSet();
    return activePlayerIds.map((id) {
      final p = getPlayerById(id);
      final pEvents = _eventHistory.where((e) => e.playerId == id);
      return {
        'name': p?.name ?? 'Unknown',
        'jersey': p?.jerseyNo ?? 0,
        'pts': pEvents.where((e) => e.outcome == EventOutcome.teamPoint).length,
        'kill': pEvents.where((e) => e.category == EventCategory.attack && e.detailType == 'Kill').length,
        'blk': pEvents.where((e) => e.category == EventCategory.block && e.detailType == 'Kill').length,
        'ace': pEvents.where((e) => e.category == EventCategory.serve && e.detailType == 'Ace').length,
        'err': pEvents.where((e) => e.outcome == EventOutcome.oppPoint).length,
      };
    }).toList();
  }

  // --- 局間轉換 ---
  void startNewSet({
    required List<Player> allPlayers, 
    required Map<int, MapEntry<Player, PlayerRole>?> rotation,
    required Player? libero,
    required String opponentName,
  }) {
    if (_scoreTeamA > 0 || _scoreTeamB > 0) {
      _setScoreHistory.add("$_scoreTeamA - $_scoreTeamB");
      _currentSet++;
    }
    
    _allPlayers = allPlayers; 
    _opponentName = opponentName;
    _scoreTeamA = 0;
    _scoreTeamB = 0;
    _selectedPlayerId = null;
    _isOurServe = true;
    _isLiberoOnCourt = false;
    _pairedPlayerId = null;
    _currentRallyId = const Uuid().v4();
    
    _positions = {
      CourtPosition.p1: rotation[1]?.key.id,
      CourtPosition.p2: rotation[2]?.key.id,
      CourtPosition.p3: rotation[3]?.key.id,
      CourtPosition.p4: rotation[4]?.key.id,
      CourtPosition.p5: rotation[5]?.key.id,
      CourtPosition.p6: rotation[6]?.key.id,
    };
    _liberoId = libero?.id;
    notifyListeners();
  }

  // --- 輔助與事件處理 ---
  Player? getPlayerById(String id) {
    try { return _allPlayers.firstWhere((p) => p.id == id); } catch (e) { return null; }
  }

  Player? getPlayerAtPosition(CourtPosition pos) {
    final String? playerId = _positions[pos];
    if (playerId == null) return null;
    return getPlayerById(playerId);
  }

  void handleEvent({required EventCategory category, required String detailType}) {
    // 確保有選到球員，沒選到的話就用系統預設
    final player = selectedPlayer ?? Player(id: 'system', jerseyNo: 0, name: 'Team', role: PlayerRole.setter);
    
    final result = EventRules.calculateOutcome(category: category, detailType: detailType);
    final snapshot = _createSnapshot();

    // ★ 1. 在比分改變前，先把這個動作寫進進階數據百寶箱！
    int playerPosNum = 1; 
    if (selectedPlayerId != null) {
       _positions.forEach((pos, id) {
         if (id == selectedPlayerId) {
           String posStr = pos.toString().split('.').last;
           playerPosNum = int.tryParse(posStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
         }
       });
    }

    // 🚨 修復核心：這裡是「呼叫」 recordAction，把剛才算好的 playerPosNum 丟進去！
    recordAction(
      playerId: player.id,
      playerName: player.name,  // ★ 補上姓名
      jerseyNo: player.jerseyNo, // ★ 補上背號
      playerPosition: playerPosNum,
      actionType: category.toString().split('.').last,
      actionResult: detailType,
    );

    // 2. 處理比分變化
    _scoreTeamA += result.scoreDeltaTeam;
    _scoreTeamB += result.scoreDeltaOpp;
    
    // 3. 處理發球權與輪轉位
    bool rotationHappened = false;
    if (result.scoreDeltaTeam > 0) {
      if (!_isOurServe) {
         _isOurServe = true; 
         _performRotation(); 
         rotationHappened = true;
      }
    } else if (result.scoreDeltaOpp > 0) {
      _isOurServe = false; 
    }

    // 4. 記錄到你原本左側側邊欄的歷史紀錄
    _eventHistory.add(EventLog(
      id: const Uuid().v4(), matchId: matchId, setNumber: _currentSet.toString(), rallyId: _currentRallyId,
      timestamp: DateTime.now(), playerId: player.id, playerName: player.name, playerJerseyNo: player.jerseyNo,
      playerRole: player.role, positionAtTime: _getPlayerPos(player.id), category: category,
      detailType: detailType, outcome: result.outcome, scoreTeamA: _scoreTeamA, scoreTeamB: _scoreTeamB,
      isForcedError: result.isForcedError, pointReason: result.pointReason, rotationApplied: rotationHappened,
      beforeStateSnapshot: snapshot,
    ));

    // 5. 如果這球死球了 (得分或失誤)，就換一組新的 Rally ID 給下一球
    if (result.outcome != EventOutcome.neutral) {
      _currentRallyId = const Uuid().v4();
    }
    
    // 動作做完，取消選取球員
    _selectedPlayerId = null;
    notifyListeners(); 
  }

  void selectPlayer(String playerId) {
    _selectedPlayerId = playerId;
    notifyListeners();
  }

  void manualAdjustScore(bool isTeamA, int delta) {
    if (isTeamA) {
      _scoreTeamA = (_scoreTeamA + delta).clamp(0, 99);
    } else {
      _scoreTeamB = (_scoreTeamB + delta).clamp(0, 99);
    }
    notifyListeners();
  }

  // --- 新增：記錄每一個動作 (外層真正的函數宣告) ---
  // 🚨 修復核心：補上 playerName 和 jerseyNo 參數
  void recordAction({
    required String playerId,
    required String playerName,  
    required int jerseyNo,
    required int playerPosition,
    required String actionType,
    required String actionResult,
  }) {
    final log = PlayLog(
      setNumber: _setScoreHistory.length + 1, 
      ourScore: _scoreTeamA,
      opponentScore: _scoreTeamB,
      isOurServe: _isOurServe,
      teamRotation: currentTeamRotation,
      rallyId: currentRallyId,
      playerId: playerId,
      playerName: playerName, // ★ 正確傳入
      jerseyNo: jerseyNo,     // ★ 正確傳入
      playerPosition: playerPosition,
      actionType: actionType,
      actionResult: actionResult,
    );

    matchPlayLogs.add(log);

    if (actionResult == 'Score' || actionResult == 'Error') {
      currentRallyId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    notifyListeners();
  }
  
  void undo() {
    if (currentSetHistory.isEmpty) return;

    final lastLog = _eventHistory.removeLast();
    final snapshot = lastLog.beforeStateSnapshot as Map<String, dynamic>;
    
    _scoreTeamA = snapshot['scoreA'];
    _scoreTeamB = snapshot['scoreB'];
    _isOurServe = snapshot['isOurServe'];
    _isLiberoOnCourt = snapshot['isLiberoOnCourt'];
    _pairedPlayerId = snapshot['pairedPlayerId'];
    _currentRallyId = snapshot['rallyId']; 
    _positions = Map<CourtPosition, String?>.from(snapshot['positions']);
    
    notifyListeners();
  }

  void _performRotation() {
    if (_isLiberoOnCourt && _liberoId != null) {
      CourtPosition? liberoPos;
      _positions.forEach((k, v) { if (v == _liberoId) liberoPos = k; });
      if (liberoPos != null && LiberoService.shouldSwapOutBeforeRotation(liberoPos!)) {
        _swapLiberoOut(liberoPos!);
      }
    }
    _positions = RotationService.rotatePositions(_positions);
  }

  void _swapLiberoOut(CourtPosition pos) {
    if (_pairedPlayerId != null) {
      _positions[pos] = _pairedPlayerId; 
      _isLiberoOnCourt = false;
      _pairedPlayerId = null;
    }
  }

  CourtPosition _getPlayerPos(String id) {
    return _positions.entries.firstWhere((e) => e.value == id, orElse: () => const MapEntry(CourtPosition.bench, null)).key;
  }

  Map<String, dynamic> _createSnapshot() {
    return {
      'scoreA': _scoreTeamA, 'scoreB': _scoreTeamB, 'isOurServe': _isOurServe,
      'positions': Map<CourtPosition, String?>.from(_positions),
      'isLiberoOnCourt': _isLiberoOnCourt, 'pairedPlayerId': _pairedPlayerId,
      'rallyId': _currentRallyId,
    };
  }

  void manualRotate({bool reverse = false}) {
    _positions = RotationService.rotatePositions(_positions, reverse: reverse);
    notifyListeners();
  }

  void manualLiberoToggle(CourtPosition pos) {
    if (_liberoId == null) return;
    final currentPlayerId = _positions[pos];
    if (currentPlayerId == _liberoId) {
      _swapLiberoOut(pos);
    } else {
      _pairedPlayerId = currentPlayerId;
      _positions[pos] = _liberoId;
      _isLiberoOnCourt = true;
    }
    notifyListeners();
  }

  int get teamASetsWon {
    int wins = 0;
    for (String score in _setScoreHistory) {
      final parts = score.split('-');
      if (parts.length == 2) {
        int a = int.tryParse(parts[0].trim()) ?? 0;
        int b = int.tryParse(parts[1].trim()) ?? 0;
        if (a > b) wins++;
      }
    }
    if (_scoreTeamA > _scoreTeamB) wins++;
    return wins;
  }

  int get teamBSetsWon {
    int wins = 0;
    for (String score in _setScoreHistory) {
      final parts = score.split('-');
      if (parts.length == 2) {
        int a = int.tryParse(parts[0].trim()) ?? 0;
        int b = int.tryParse(parts[1].trim()) ?? 0;
        if (b > a) wins++;
      }
    }
    if (_scoreTeamB > _scoreTeamA) wins++;
    return wins;
  }

  bool get isMatchWon => teamASetsWon >= teamBSetsWon;
}

class PlayLog {
  final int setNumber;
  final int ourScore;
  final int opponentScore;
  final bool isOurServe;
  final int teamRotation;
  final String rallyId;
  final String playerId;
  final String playerName;    
  final int jerseyNo;
  final int playerPosition;
  final String actionType;
  final String actionResult;

  PlayLog({
    required this.setNumber,
    required this.ourScore,
    required this.opponentScore,
    required this.isOurServe,
    required this.teamRotation,
    required this.rallyId,
    required this.playerId,
    required this.playerName,   
    required this.jerseyNo, 
    required this.playerPosition,
    required this.actionType,
    required this.actionResult,
  });

  Map<String, dynamic> toJson() {
    return {
      'set_number': setNumber,
      'our_score': ourScore,
      'opponent_score': opponentScore,
      'is_our_serve': isOurServe ? 1 : 0, 
      'team_rotation': teamRotation,
      'rally_id': rallyId,
      'player_id': playerId,
      'player_name': playerName,   
      'jersey_no': jerseyNo, 
      'player_position': playerPosition,
      'action_type': actionType,
      'action_result': actionResult,
    };
  }
}