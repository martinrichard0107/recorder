import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../models/player.dart';
import '../providers/match_provider.dart';
import 'match_score_screen.dart';

class StartingLineupScreen extends StatefulWidget {
  const StartingLineupScreen({super.key});

  @override
  State<StartingLineupScreen> createState() => _StartingLineupScreenState();
}

class _StartingLineupScreenState extends State<StartingLineupScreen> {
  final TextEditingController _opponentController = TextEditingController();
  Map<int, MapEntry<Player, PlayerRole>?> selectedStarters = {
    1: null, 2: null, 3: null, 4: null, 5: null, 6: null
  };
  Player? selectedLibero;

  // ★ 1. 改成空的清單，等待資料庫傳入
  List<Player> teamPlayers = [];
  bool isLoading = true; // ★ 載入狀態

  @override
  void initState() {
    super.initState();
    _fetchPlayersFromDB(); // ★ 啟動時先去抓資料

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MatchProvider>(context, listen: false);
      if (provider.positions[CourtPosition.p1] != null) {
        setState(() {
          _opponentController.text = provider.opponentName;
          for (int i = 1; i <= 6; i++) {
            final p = provider.getPlayerAtPosition(_intToCourtPos(i));
            if (p != null) {
              selectedStarters[i] = MapEntry(p, p.role);
            }
          }
          selectedLibero = provider.currentLibero;
        });
      }
    });
  }

  // ★ 2. 去資料庫抓球員的非同步方法
  Future<void> _fetchPlayersFromDB() async {
    try {
      // 呼叫你的 Node.js API
      final response = await http.get(Uri.parse('http://localhost:3000/api/players'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          // 將 JSON 轉換成 Player 物件並存入清單
          teamPlayers = data.map((json) => Player.fromMap(json)).toList();
          isLoading = false; // 抓完資料，關閉載入動畫
        });
      } else {
        throw Exception('無法讀取球員名單');
      }
    } catch (e) {
      print('連線錯誤: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法連線到資料庫，請確認 API 是否啟動。'), backgroundColor: Colors.red),
        );
      }
    }
  }

  CourtPosition _intToCourtPos(int i) {
    switch (i) {
      case 1: return CourtPosition.p1; case 2: return CourtPosition.p2; case 3: return CourtPosition.p3;
      case 4: return CourtPosition.p4; case 5: return CourtPosition.p5; case 6: return CourtPosition.p6;
      default: return CourtPosition.p1;
    }
  }

  String _getRoleName(PlayerRole role) {
    switch (role) {
      case PlayerRole.setter: return '舉球';
      case PlayerRole.outside: return '大砲';
      case PlayerRole.opposite: return '副攻';
      case PlayerRole.middle: return '欄中';
      case PlayerRole.libero: return '自由';
    }
  }

  void _selectPlayer(int? position) {
    List<Player> sorted = List.from(teamPlayers);
    sorted.sort((a, b) {
      bool aUsed = selectedStarters.values.any((e) => e?.key.id == a.id) || selectedLibero?.id == a.id;
      bool bUsed = selectedStarters.values.any((e) => e?.key.id == b.id) || selectedLibero?.id == b.id;
      if (aUsed && !bUsed) return 1;
      if (!aUsed && bUsed) return -1;
      return 0;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: ListView.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final p = sorted[index];
            final bool isUsed = selectedStarters.values.any((e) => e?.key.id == p.id) || selectedLibero?.id == p.id;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isUsed ? Colors.grey[800] : Colors.orange, 
                child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
              title: Text(p.name, style: TextStyle(color: isUsed ? Colors.white24 : Colors.white)),
              subtitle: Text(_getRoleName(p.role), style: TextStyle(color: isUsed ? Colors.white24 : Colors.grey)),
              enabled: !isUsed,
              onTap: () {
                Navigator.pop(context); 
                if (position == null) {
                  setState(() => selectedLibero = p);
                } else {
                  setState(() => selectedStarters[position] = MapEntry(p, p.role));
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _showNodeOptions(int pos, Player p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Text('設定 ${p.name} (P$pos)', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.manage_accounts, color: Colors.orange),
            title: Text('更改他的場上角色 (目前: ${_getRoleName(selectedStarters[pos]!.value)})', style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showRoleSelection(p, pos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
            title: const Text('換成其他球員', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _selectPlayer(pos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear, color: Colors.redAccent),
            title: const Text('清空此位置', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              setState(() => selectedStarters[pos] = null);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showRoleSelection(Player player, int position) {
    PlayerRole currentRole = selectedStarters[position]!.value;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF333333),
          title: Text('設定 ${player.name} 的角色', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: PlayerRole.values.where((r) => r != PlayerRole.libero).map((r) {
              return RadioListTile<PlayerRole>(
                title: Text(_getRoleName(r), style: const TextStyle(color: Colors.white)),
                value: r,
                // ignore: deprecated_member_use
                groupValue: currentRole,
                activeColor: Colors.orange,
                // ignore: deprecated_member_use
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => currentRole = v);
                    setState(() => selectedStarters[position] = MapEntry(player, v));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNode(int pos, {bool isLibero = false}) {
    final entry = isLibero ? null : selectedStarters[pos];
    final p = isLibero ? selectedLibero : entry?.key;
    return GestureDetector(
      onTap: () {
        if (p == null) {
          _selectPlayer(isLibero ? null : pos); 
        } else {
          if (isLibero) {
            _selectPlayer(null); 
          } else {
            _showNodeOptions(pos, p); 
          }
        }
      },
      child: Column(
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: p == null ? Colors.transparent : (isLibero ? Colors.redAccent : Colors.orange[800]), 
              border: Border.all(color: p == null ? Colors.grey : Colors.transparent, width: 2)
            ),
            child: Center(
              child: Text(
                p == null ? (isLibero ? 'L' : 'P$pos') : '${p.jerseyNo}', 
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
              )
            ),
          ),
          const SizedBox(height: 4),
          Text(
            p == null ? '選人' : '${p.name}\n${isLibero ? "自由" : _getRoleName(entry!.value)}', 
            textAlign: TextAlign.center, 
            style: const TextStyle(color: Colors.white70, fontSize: 11)
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ★ 3. 正在讀取資料時，顯示橘色的轉圈圈
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    bool ready = !selectedStarters.values.contains(null) && selectedLibero != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(title: const Text('賽前先發設定'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: TextField(
                controller: _opponentController, 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(labelText: '對手名稱', labelStyle: TextStyle(color: Colors.grey))
              ),
            ),
            const Text('網子', style: TextStyle(color: Colors.white24, letterSpacing: 8)),
            const Divider(color: Colors.white24, indent: 80, endIndent: 80),
            const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNode(4), _buildNode(3), _buildNode(2)]),
            const SizedBox(height: 35),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildNode(5), _buildNode(6), _buildNode(1)]),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40), 
              child: Row(children: [_buildNode(0, isLibero: true), const SizedBox(width: 20), const Text('自由球員', style: TextStyle(color: Colors.white38))])
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ready ? Colors.orange[800] : Colors.grey[850]),
                  onPressed: ready ? () {
                    final provider = Provider.of<MatchProvider>(context, listen: false);
                    provider.startNewSet(allPlayers: teamPlayers, rotation: selectedStarters, libero: selectedLibero, opponentName: _opponentController.text);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MatchScoreScreen()));
                  } : null,
                  child: Text(ready ? '開始比賽' : '尚未選齊人員', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}