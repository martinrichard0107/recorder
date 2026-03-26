import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/match_provider.dart';

class MatchSummaryScreen extends StatelessWidget {
  const MatchSummaryScreen({super.key});

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
                // ★ 改成顯示我方贏了幾局
                _buildLargeScore(provider.teamASetsWon.toString()),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(':', style: TextStyle(color: Colors.white24, fontSize: 40, fontWeight: FontWeight.w300)),
                ),
                // ★ 改成顯示對手贏了幾局
                _buildLargeScore(provider.teamBSetsWon.toString()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              provider.isMatchWon ? ' WIN ' : ' LOSS ',
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
            
            // 4. Box Score 數據表 (中文 + 撐滿螢幕)
            _buildBoxScoreTable(context, boxScore),
            
            const SizedBox(height: 40),
            
            // 底部按鈕
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('開始新比賽', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 30),
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

  // ★ 修正後的球員明細表：全中文、自適應寬度、數字上色
  Widget _buildBoxScoreTable(BuildContext context, List<Map<String, dynamic>> boxScore) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        // 強制表格最小寬度等於螢幕寬度減去 padding (24*2 = 48)，這樣就不會縮在左邊
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
        child: DataTable(
          columnSpacing: 20, // 拉開欄位間距
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(Colors.white.withAlpha(10)), // 標題列給一點底色區分
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
            // 總分用橘色標記
            DataCell(Text('${d['pts']}', style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold))),
            DataCell(Text('${d['kill']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['blk']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            DataCell(Text('${d['ace']}', style: const TextStyle(fontSize: 13, color: Colors.white))),
            // 失誤用紅色標記
            DataCell(Text('${d['err']}', style: const TextStyle(fontSize: 13, color: Colors.redAccent))),
          ])).toList(),
        ),
      ),
    ),
  );
}