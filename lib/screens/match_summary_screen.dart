import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/match_provider.dart';
import 'match_dashboard_screen.dart';

class MatchSummaryScreen extends StatefulWidget {
  const MatchSummaryScreen({super.key});

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  bool _isSaving = false;

  // --- 發射數據給 Node.js API 的方法 ---
  Future<void> _saveMatchData(MatchProvider provider) async {
    setState(() => _isSaving = true);

    // 1. 準備要發送的 JSON 資料包裹
    final matchData = {
      "id": provider.matchId,
      "team_id": "t1", // 嘉大資管的 ID
      "opponent_name": provider.opponentName,
      "our_sets_won": provider.teamASetsWon,
      "opponent_sets_won": provider.teamBSetsWon,
      "result": provider.isMatchWon ? "WIN" : "LOSS",
      
      // 組合每一局的比分
      "sets": provider.setScoreHistory.asMap().entries.map((entry) {
        final parts = entry.value.split('-');
        return {
          "set_number": entry.key + 1,
          "our_score": int.tryParse(parts[0].trim()) ?? 0,
          "opponent_score": int.tryParse(parts[1].trim()) ?? 0,
        };
      }).toList(),
      
      // 把逐球紀錄轉成 JSON 陣列
      "play_logs": provider.matchPlayLogs.map((log) => log.toJson()).toList(),
    };

    try {
      // 2. 向你的 API 發送 POST 請求
      // ⚠️ 如果你是用手機實機測試，請把 localhost 換成你電腦的區域網路 IP (例如 192.168.x.x)
      final response = await http.post(
        Uri.parse('http://127.0.0.1:3000/api/matches'), 
        headers: {'Content-Type': 'application/json'},
        body: json.encode(matchData),
      );

      if (response.statusCode == 201) {
        // 成功存入資料庫！
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 完美！比賽紀錄與進階數據已存入資料庫！'), backgroundColor: Colors.green),
          );
          // 回到 APP 首頁 (你原本的邏輯)
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception('API 回傳錯誤: ${response.statusCode}');
      }
    } catch (e) {
      print('儲存失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗，請確認 API 是否啟動 ($e)'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchProvider>();
    final boxScore = provider.getBoxScore();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117), 
      appBar: AppBar(
        title: const Text('比賽報告', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // 隱藏左上角返回鍵，強迫儲存
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
        child: Column(
          children: [
            // 1. 【最上方】總勝局數與真實勝負
            const Text('MATCH SCORE (總勝局數)', style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLargeScore(provider.teamASetsWon.toString()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(':', style: TextStyle(color: Colors.white24, fontSize: 40, fontWeight: FontWeight.w300)),
                ),
                _buildLargeScore(provider.teamBSetsWon.toString()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.isMatchWon ? ' WIN - 嘉大資管 ' : ' LOSS ',
              style: TextStyle(
                color: provider.isMatchWon ? Colors.orange : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            
            // 2. 【中間】統計數據卡片 (包含樣本數)
            const SizedBox(height: 10),
            _buildStatCard(
              icon: Icons.flash_on,
              color: Colors.redAccent,
              title: '攻擊效率',
              val: provider.attackEfficiency.toStringAsFixed(3),
              count: provider.totalAttacks,
              unit: '次攻擊',
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.ads_click,
              color: Colors.orangeAccent,
              title: '接發品質',
              val: provider.passQuality.toStringAsFixed(2),
              count: provider.totalReceives,
              unit: '次接發',
            ),

            const SizedBox(height: 30),
            
            // 3. 各局比分明細
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('各局比分明細', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
            const SizedBox(height: 10),
            ...provider.setScoreHistory.asMap().entries.map((e) => _buildSetRow('第 ${e.key + 1} 局', e.value)),
            _buildSetRow('第 ${provider.currentSet} 局 (目前)', '${provider.scoreTeamA} - ${provider.scoreTeamB}'),

            const SizedBox(height: 30),
            
            // 4. Box Score 數據表
            _buildBoxScoreTable(context, boxScore),
            
            const SizedBox(height: 40),
            
            // ★ 新增：前往儀表板的按鈕
            ElevatedButton.icon(
              onPressed: () {
                // 1. 整理目前的比賽比分狀態
                final liveInfo = {
                  'opponent_name': provider.opponentName,
                  'our_sets_won': provider.teamASetsWon,
                  'opponent_sets_won': provider.teamBSetsWon,
                };

                // 2. ⚠️ 關鍵：把你 Provider 裡面的 Event 轉換成儀表板看得懂的 JSON 格式
                final logsJson = provider.matchPlayLogs.map((log) => log.toJson()).toList();

                // 3. 把包好的包裹丟給儀表板！
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchDashboardScreen(
                      livePlayLogs: logsJson, 
                      liveMatchInfo: liveInfo,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics, color: Colors.white),
              label: const Text('查看數據報表', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16), // 按鈕之間的間距

            // ★ 原本的儲存按鈕
            ElevatedButton(
              onPressed: _isSaving ? null : () => _saveMatchData(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('儲存紀錄並結束比賽', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 特大比分組件
  Widget _buildLargeScore(String score) => Text(
    score,
    style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w900),
  );

  // 數據統計卡片
  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String val,
    required int count,
    required String unit,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13))]),
            const SizedBox(height: 4),
            Text('基於 $count $unit', style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildSetRow(String label, String score) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        Text(score, style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildBoxScoreTable(BuildContext context, List<Map<String, dynamic>> boxScore) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
        child: DataTable(
          columnSpacing: 20, 
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(Colors.white.withAlpha(10)), 
          columns: const [
            DataColumn(label: Text('號碼', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('姓名', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('總分', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('攻擊', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('攔網', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('發球', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('失誤', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.bold))),
          ],
          rows: boxScore.map((d) => DataRow(cells: [
            DataCell(Text('${d['jersey']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['name']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['pts']}', style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold))),
            DataCell(Text('${d['kill']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['blk']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['ace']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['err']}', style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
          ])).toList(),
        ),
      ),
    ),
  );
}