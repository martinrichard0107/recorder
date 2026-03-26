import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../services/rotation_service.dart';
import '../services/libero_service.dart';
import '../services/event_rules.dart';

class MatchProvider extends ChangeNotifier {
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
      if (r.detailType == 'Perfect') totalWeight += 3;
      else if (r.detailType == 'Good') totalWeight += 2;
      else if (r.detailType == 'Bad') totalWeight += 1;
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
    required List<Player> allPlayers, // ★ 這裡新增了接收球隊大名單
    required Map<int, MapEntry<Player, PlayerRole>?> rotation,
    required Player? libero,
    required String opponentName,
  }) {
    if (_scoreTeamA > 0 || _scoreTeamB > 0) {
      _setScoreHistory.add("$_scoreTeamA - $_scoreTeamB");
      _currentSet++;
    }
    
    _allPlayers = allPlayers; // ★ 把大名單存進大腦
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
    final player = selectedPlayer ?? Player(id: 'system', jerseyNo: 0, name: 'Team', role: PlayerRole.setter);
    final result = EventRules.calculateOutcome(category: category, detailType: detailType);
    final snapshot = _createSnapshot();

    _scoreTeamA += result.scoreDeltaTeam;
    _scoreTeamB += result.scoreDeltaOpp;
    
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

    _eventHistory.add(EventLog(
      id: const Uuid().v4(), matchId: matchId, setNumber: _currentSet.toString(), rallyId: _currentRallyId,
      timestamp: DateTime.now(), playerId: player.id, playerName: player.name, playerJerseyNo: player.jerseyNo,
      playerRole: player.role, positionAtTime: _getPlayerPos(player.id), category: category,
      detailType: detailType, outcome: result.outcome, scoreTeamA: _scoreTeamA, scoreTeamB: _scoreTeamB,
      isForcedError: result.isForcedError, pointReason: result.pointReason, rotationApplied: rotationHappened,
      beforeStateSnapshot: snapshot,
    ));

    if (result.outcome != EventOutcome.neutral) {
      _currentRallyId = const Uuid().v4();
    }
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

  void undo() {
    if (_eventHistory.isEmpty) return;
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
}