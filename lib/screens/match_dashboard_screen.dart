import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MatchDashboardScreen extends StatefulWidget {
  // ★ 雙引擎設計
  final String? matchId; // 引擎 A：未來接 API 用
  final List<dynamic>? livePlayLogs; // 引擎 B：Live 模式直接傳入逐球紀錄
  final Map<String, dynamic>? liveMatchInfo; // 引擎 B：Live 模式的比賽資訊

  const MatchDashboardScreen({
    super.key, 
    this.matchId, 
    this.livePlayLogs, 
    this.liveMatchInfo
  });

  @override
  State<MatchDashboardScreen> createState() => _MatchDashboardScreenState();
}

class _MatchDashboardScreenState extends State<MatchDashboardScreen> {
  bool _isLoading = true; 

  String opponentName = "載入中...";
  String matchResult = "-";
  String finalScore = "- : -";
  
  // 核心變數保留原名，但畫面上顯示白話文
  double sideOutPct = 0.0; 
  double breakPointPct = 0.0; 
  
  List<double> rotationPlusMinus = [0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> positionAttacks = [];
  List<Map<String, dynamic>> playerEfficiencies = [];

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateData(); 
  }

  // ==========================================
  // ★ 核心大腦：雙引擎資料分流與計算
  // ==========================================
  Future<void> _fetchAndCalculateData() async {
    try {
      List<dynamic> playLogs = [];
      Map<String, dynamic> matchInfo = {};

      // ----------------------------------------
      // 🚦 判斷啟動哪顆引擎
      // ----------------------------------------
      if (widget.livePlayLogs != null && widget.liveMatchInfo != null) {
        // 🚀 啟動引擎 B：Live 即時模式 (瞬間載入)
        playLogs = widget.livePlayLogs!;
        matchInfo = widget.liveMatchInfo!;
      } else if (widget.matchId != null) {
        // 🚀 啟動引擎 A：歷史回顧模式 (未來接 API 用，先寫好放著)
        final url = Uri.parse('http://127.0.0.1:3000/api/matches/${widget.matchId}');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          matchInfo = data['match_info'];
          playLogs = data['play_logs'];
        } else {
          throw Exception('找不到比賽紀錄');
        }
      } else {
        throw Exception('未提供任何資料來源');
      }

      // ----------------------------------------
      // 🧠 開始計算真實數據！
      // ----------------------------------------
      opponentName = matchInfo['opponent_name'] ?? '未知對手';
      final ourSets = matchInfo['our_sets_won'] ?? 0;
      final oppSets = matchInfo['opponent_sets_won'] ?? 0;
      finalScore = "$ourSets : $oppSets";
      matchResult = (ourSets > oppSets) ? 'WIN' : (ourSets < oppSets ? 'LOSE' : 'LIVE');

      int receiveRallies = 0, sideOutPoints = 0;
      int serveRallies = 0, breakPoints = 0;
      List<double> rotNet = [0, 0, 0, 0, 0, 0];
      
      Map<String, Map<String, dynamic>> posAtkMap = {
        '4號位 (大砲)': {'kills': 0, 'total': 0, 'color': Colors.redAccent},
        '3號位 (快攻)': {'kills': 0, 'total': 0, 'color': Colors.blueAccent},
        '2號位 (副攻)': {'kills': 0, 'total': 0, 'color': Colors.orangeAccent},
        '6號位 (後排)': {'kills': 0, 'total': 0, 'color': Colors.greenAccent},
      };

      Map<String, Map<String, dynamic>> pStats = {};

      for (var log in playLogs) {
        bool isOurServe = (log['is_our_serve'] == 1 || log['is_our_serve'] == true);

        String type = log['action_type'] ?? '';
        String result = log['action_result'] ?? '';
        int rot = log['team_rotation'] ?? 1;

        String pId = log['player_id']?.toString() ?? '未知';
        String pName = log['player_name'] ?? '未知';
        int jerseyNo = log['jersey_no'] ?? 0;
        String pos = log['player_position']?.toString() ?? '';

        bool isTeamPoint = false;
        bool isOpponentPoint = false;

        if (result == 'Kill' ||
            result == 'Ace' ||
            result == 'BlockPoint' ||
            result == 'TipKill') {
          isTeamPoint = true;
        }

        if (result == 'Error' ||
            result == 'Out' ||
            result == 'BlockedDown' ||
            result == 'ServeErr' ||
            result == 'RecvErr' ||
            result == 'TipErr') {
          isOpponentPoint = true;
        }

        // 🔄 輪轉位淨勝分
        if (isTeamPoint) rotNet[rot - 1] += 1;
        if (isOpponentPoint) rotNet[rot - 1] -= 1;

        // 🔥 防守反擊（我方發球）
        if (isOurServe && isTeamPoint) breakPoints++;
        if (isOurServe && type == 'serve') serveRallies++;

        // 🔥 首波進攻（對方發球）
        if (!isOurServe && isTeamPoint) sideOutPoints++;
        if (!isOurServe && type == 'receive') receiveRallies++;

        // 🎯 攻擊分佈
        if (type == 'attack') {
          String targetPos = '4號位 (大砲)';

          if (pos.contains('3')) targetPos = '3號位 (快攻)';
          if (pos.contains('2')) targetPos = '2號位 (副攻)';
          if (pos.contains('6')) targetPos = '6號位 (後排)';

          posAtkMap[targetPos]!['total']++;

          if (result == 'Kill') {
            posAtkMap[targetPos]!['kills']++;
          }
        }

        // 👤 球員效率
        if (!pStats.containsKey(pId)) {
          pStats[pId] = {
            'no': jerseyNo.toString(), 
            'name': pName, 
            'kills': 0,
            'errors': 0,
            'blocked': 0,
            'total': 0
          };
        }

        if (type == 'attack') {
          pStats[pId]!['total']++;

          if (result == 'Kill') {
            pStats[pId]!['kills']++;
          }

          if (result == 'Error' || result == 'Out') {
            pStats[pId]!['errors']++;
          }

          if (result == 'BlockedDown') {
            pStats[pId]!['blocked']++;
          }
        }
      }

      setState(() {
        sideOutPct = receiveRallies == 0 ? 0 : (sideOutPoints / receiveRallies) * 100;
        breakPointPct = serveRallies == 0 ? 0 : (breakPoints / serveRallies) * 100;
        rotationPlusMinus = rotNet;

        positionAttacks = posAtkMap.entries.map((e) {
          int total = e.value['total'];
          int kills = e.value['kills'];
          return {'pos': e.key, 'rate': total == 0 ? 0.0 : (kills / total), 'kills': kills, 'total': total, 'color': e.value['color']};
        }).toList();

        playerEfficiencies = pStats.values.toList();
        playerEfficiencies.removeWhere((p) => p['total'] == 0);
        playerEfficiencies.sort((a, b) => b['total'].compareTo(a['total']));

        _isLoading = false; 
      });
      
    } catch (e) {
      print('❌ 計算數據失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // UI 畫面部分
  // ==========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: const Color(0xFF0D1117), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(color: Colors.blueAccent), SizedBox(height: 16), Text('正在分析比賽數據...', style: TextStyle(color: Colors.white70))])));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(title: const Text('比賽進階報表', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroSection(),
            const SizedBox(height: 28),
            
            // ★ 已更新為白話文標題與說明
            _buildSectionHeader(
              '🔥 核心致勝率', 
              '首波進攻與防守反擊', 
              '首波進攻成功率 = (接發後贏得該球) / 總接發次數\n防守反擊得分率 = (發球後贏得該球) / 總發球次數', 
              '「首波進攻」評估接發球後的進攻轉化能力；「防守反擊」則衡量握有發球權時，透過防守創造連續得分的壓制力。'
            ),
            const SizedBox(height: 12),
            _buildCoreMetricsRow(),
            const SizedBox(height: 32),

            _buildSectionHeader('🔄 輪轉位體質檢查', '輪轉位淨勝分', '特定輪轉位下之 (我方得分 - 敵方得分)', '檢視弱勢輪轉與卡分點。'),
            const SizedBox(height: 12),
            _buildBarChartCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('🎯 位置火力分佈', '攻擊成功率', '(位置攻擊得分) / 該位置總攻擊次數', '分析火力分佈與戰術執行力。'),
            const SizedBox(height: 12),
            _buildPositionAttackCard(),
            const SizedBox(height: 32),

            _buildSectionHeader('🎖️ 球員真實效能', '攻擊效率', '(得分 - 失誤 - 被攔死) / 總數', '扣除耗損後的淨貢獻，衡量球員穩健度。'),
            const SizedBox(height: 12),
            _buildPlayerEfficiencyList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 小問號對話框 ---
  void _showInfoDialog(BuildContext context, String title, String formula, String interpretation) {
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF161B22), title: Text(title, style: const TextStyle(color: Colors.white)), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('🧮 公式', style: TextStyle(color: Colors.blueAccent)), Text(formula, style: TextStyle(color: Colors.white70, height: 1.5)), SizedBox(height: 16), Text('📖 解讀', style: TextStyle(color: Colors.orangeAccent)), Text(interpretation, style: TextStyle(color: Colors.white70, height: 1.5))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('了解', style: TextStyle(color: Colors.white)))]));
  }

  Widget _buildSectionHeader(String title, String dt, String f, String i) => Row(children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(width: 8), InkWell(onTap: () => _showInfoDialog(context, dt, f, i), child: Icon(Icons.help_outline, color: Colors.white54, size: 20))]);
  
  Widget _buildHeroSection() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('對戰 $opponentName', style: const TextStyle(color: Colors.white70, fontSize: 14)), SizedBox(height: 4), Text(matchResult, style: TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.bold))]), Text(finalScore, style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold))]));
  
  // ★ 已更新為白話文卡片
  Widget _buildCoreMetricsRow() => Row(children: [
    Expanded(child: _buildMetricCard('首波進攻\n成功率', '${sideOutPct.toStringAsFixed(1)}%', Colors.greenAccent)), 
    SizedBox(width: 12), 
    Expanded(child: _buildMetricCard('防守反擊\n得分率', '${breakPointPct.toStringAsFixed(1)}%', Colors.orangeAccent))
  ]);
  
  Widget _buildMetricCard(String t, String v, Color c) => Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text(v, style: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.bold))]));
  
  Widget _buildBarChartCard() => Container(height: 220, padding: const EdgeInsets.fromLTRB(16, 24, 16, 16), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)), child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: 6, minY: -6, titlesData: FlTitlesData(bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) => Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('P${v.toInt() + 1}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))))), leftTitles: AxisTitles(), rightTitles: AxisTitles(), topTitles: AxisTitles()), gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: v == 0 ? Colors.white38 : Colors.white10, strokeWidth: v == 0 ? 2 : 1)), borderData: FlBorderData(show: false), barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: rotationPlusMinus[i], color: rotationPlusMinus[i] >= 0 ? Colors.greenAccent : Colors.redAccent, width: 20)])))));
  
  Widget _buildPositionAttackCard() { if (positionAttacks.isEmpty) return const Text('尚無攻擊數據', style: TextStyle(color: Colors.white54)); return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)), child: Column(children: positionAttacks.map((d) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(d['pos'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text('${(d['rate'] * 100).toStringAsFixed(1)}% (${d['kills']}/${d['total']})', style: const TextStyle(color: Colors.white70, fontSize: 13))]), SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: d['rate'], backgroundColor: Colors.white10, color: d['color'], minHeight: 10))]))).toList()));}
  
  Widget _buildPlayerEfficiencyList() { if (playerEfficiencies.isEmpty) return const Text('尚無攻擊數據', style: TextStyle(color: Colors.white54)); return Column(children: playerEfficiencies.map((p) { double eff = p['total'] == 0 ? 0 : (p['kills'] - p['errors'] - p['blocked']) / p['total']; return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)), child: Row(children: [CircleAvatar(backgroundColor: Colors.blueAccent.withAlpha(30), child: Text(p['no'], style: const TextStyle(color: Colors.blueAccent))), SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), SizedBox(height: 6), Row(children: [Text('得:${p['kills']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)), SizedBox(width: 8), Text('失:${p['errors']}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)), SizedBox(width: 8), Text('攔:${p['blocked']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)), SizedBox(width: 8), Text('總:${p['total']}', style: const TextStyle(color: Colors.white54, fontSize: 12))])])), Column(children: [const Text('效率', style: TextStyle(color: Colors.white54, fontSize: 10)), Text(eff.toStringAsFixed(3), style: TextStyle(color: eff >= 0.3 ? Colors.greenAccent : (eff < 0 ? Colors.redAccent : Colors.white), fontSize: 18, fontWeight: FontWeight.bold))])])); }).toList());}
}