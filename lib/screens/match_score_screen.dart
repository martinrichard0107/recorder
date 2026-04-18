import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/event.dart';
import '../providers/match_provider.dart';
import 'starting_lineup_screen.dart';
import 'match_summary_screen.dart';

class MatchScoreScreen extends StatefulWidget {
  const MatchScoreScreen({super.key});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  int _selectedTabIndex = 2; // 0:發球, 1:接球, 2:攻擊, 3:吊球, 4:攔網, 5:其他
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Color _colBgDeep = const Color(0xFF131722);
  final Color _colBgPanel = const Color(0xFF1E2330);
  final Color _colCourt = const Color(0xFFE0AA68);
  final Color _colSelected = const Color(0xFFFACC15);
  final Color _btnSuccess = const Color(0xFF3B82F6);
  final Color _btnNeutral = const Color(0xFF4B5563);
  final Color _btnError = const Color(0xFFEF4444);

  final Map<CourtPosition, Alignment> _courtAlignments = {
    CourtPosition.p4: const Alignment(-0.75, -0.6), CourtPosition.p3: const Alignment(0.0, -0.6), CourtPosition.p2: const Alignment(0.75, -0.6),
    CourtPosition.p5: const Alignment(-0.75, 0.6),  CourtPosition.p6: const Alignment(0.0, 0.6),  CourtPosition.p1: const Alignment(0.75, 0.6),
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MatchProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _colBgDeep,
      endDrawer: _buildHistoryDrawer(provider),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(provider),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 4, child: _buildLeftColumn(provider)),
                  Expanded(flex: 6, child: _buildControlPanel(provider)),
                ],
              ),
            ),
            _buildBottomBar(provider),
          ],
        ),
      ),
    );
  }

  void _showMatchControlMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colBgPanel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('比賽進度控制', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white10),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.greenAccent),
              title: const Text('本局結束，設定下一局先發', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StartingLineupScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.orangeAccent),
              title: const Text('比賽結束', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MatchSummaryScreen()));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ★ 實作換人選單
  void _showSubstitutionMenu(BuildContext context, MatchProvider provider) {
    final pos = _getSelectedPosition(provider);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請先點擊場上要被換下的球員！")));
      return;
    }
    final outPlayer = provider.selectedPlayer!;
    final bench = provider.benchPlayers;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('將 ${outPlayer.name} 換下，換上：', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(color: Colors.white24),
            if (bench.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('沒有板凳球員可換', style: TextStyle(color: Colors.white54))),
            ...bench.map((p) => ListTile(
              leading: CircleAvatar(backgroundColor: Colors.grey[800], child: Text('${p.jerseyNo}', style: const TextStyle(color: Colors.white))),
              title: Text(p.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                provider.substitutePlayer(pos, p.id);
                Navigator.pop(context);
              },
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(MatchProvider provider) {
    return Container(
      height: 65, padding: const EdgeInsets.symmetric(horizontal: 24), color: _colBgDeep,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 6, backgroundColor: provider.isOurServe ? Colors.yellow : Colors.transparent),
              const SizedBox(width: 12),
              const Text("我方隊伍", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              _buildScoreAdjuster(provider, true),
            ],
          ),
          GestureDetector(
            onTap: () => _showMatchControlMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(50), 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withAlpha(100)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ★ 動態顯示局數
                  Text("SET ${provider.currentSet}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 20),
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildScoreAdjuster(provider, false),
              const SizedBox(width: 16),
              // ★ 動態顯示對手名稱
              Text(provider.opponentName.isEmpty ? "對手" : provider.opponentName, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 12),
              CircleAvatar(radius: 6, backgroundColor: !provider.isOurServe ? Colors.yellow : Colors.transparent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreAdjuster(MatchProvider provider, bool isTeamA) {
    final score = isTeamA ? provider.scoreTeamA : provider.scoreTeamB;
    return Row(
      children: [
        Text("$score".padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(onTap: () => provider.manualAdjustScore(isTeamA, 1), child: const Icon(Icons.add_box, color: Colors.grey, size: 20)),
            InkWell(onTap: () => provider.manualAdjustScore(isTeamA, -1), child: const Icon(Icons.indeterminate_check_box, color: Colors.grey, size: 20)),
          ],
        )
      ],
    );
  }

  Widget _buildLeftColumn(MatchProvider provider) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _colCourt, borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                Column(
                  children: [
                    Container(height: 40, width: double.infinity, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withAlpha(75)), child: const Text("N E T", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4))),
                    const Spacer(flex: 1),
                    Container(height: 3, color: Colors.white.withAlpha(200)),
                    const Spacer(flex: 2),
                  ],
                ),
                ...provider.positions.entries.map((entry) {
                  return AnimatedAlign(
                    key: ValueKey(entry.value ?? 'empty_${entry.key}'), 
                    alignment: _courtAlignments[entry.key]!,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: _buildPlayerToken(provider, entry.key, entry.value),
                  );
                }),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => provider.manualRotate(reverse: false), icon: const Icon(Icons.rotate_right, color: Colors.white), style: IconButton.styleFrom(backgroundColor: _colBgPanel)),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () => provider.manualRotate(reverse: true), icon: const Icon(Icons.rotate_left, color: Colors.white), style: IconButton.styleFrom(backgroundColor: _colBgPanel)),
                ],
              ),
              Row(
                children: [
                  // ★ 換人按鈕綁定功能
                  ElevatedButton.icon(
                    onPressed: () => _showSubstitutionMenu(context, provider), 
                    icon: const Icon(Icons.swap_horiz, color: Colors.white, size: 18), label: const Text("換人", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                  ),
                  const SizedBox(width: 8),
                  _buildLiberoButton(provider),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildLiberoButton(MatchProvider provider) {
    final selectedPos = _getSelectedPosition(provider);
    final isBackRow = [CourtPosition.p1, CourtPosition.p5, CourtPosition.p6].contains(selectedPos);
    final isSelectedLibero = provider.selectedPlayer?.role == PlayerRole.libero;

    return ElevatedButton.icon(
      onPressed: (selectedPos != null && isBackRow) ? () => provider.manualLiberoToggle(selectedPos) : null,
      icon: Icon(isSelectedLibero ? Icons.shield_outlined : Icons.shield, color: Colors.black, size: 18),
      label: Text(isSelectedLibero ? "自由退" : "自由進", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[600], disabledBackgroundColor: Colors.white10),
    );
  }

  Widget _buildPlayerToken(MatchProvider provider, CourtPosition pos, String? playerId) {
    final player = playerId != null ? provider.getPlayerById(playerId) : null;
    final isSelected = player != null && provider.selectedPlayerId == player.id;
    final isLibero = player?.role == PlayerRole.libero;

    return GestureDetector(
      onTap: () {
        if (player != null && !isSelected) {
          provider.selectPlayer(player.id);
          _handleSmartTabSwitch(provider, pos);
        }
      },
      child: Container(
        width: 105, height: 105, 
        decoration: BoxDecoration(
          color: isSelected ? _colSelected : (isLibero ? Colors.amber[800] : const Color(0xFF2D3748)),
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? Colors.white : Colors.grey.shade700, width: isSelected ? 4 : 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(2, 4))],
        ),
        child: player == null ? const Center(child: Icon(Icons.add, color: Colors.grey, size: 36))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${player.jerseyNo}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white, height: 1.0)),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(player.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? Colors.black87 : Colors.white70)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildControlPanel(MatchProvider provider) {
    bool requirePlayer = _selectedTabIndex != 5; 
    bool hasPlayer = provider.selectedPlayer != null;
    bool isLocked = _isTabLocked(provider, _selectedTabIndex);

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      decoration: BoxDecoration(color: _colBgPanel, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              _buildTabItem(provider, '發球', 0), _buildTabItem(provider, '接球', 1), _buildTabItem(provider, '攻擊', 2), 
              _buildTabItem(provider, '吊球', 3), _buildTabItem(provider, '攔網', 4), _buildTabItem(provider, '其他', 5),
            ],
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: (requirePlayer && !hasPlayer) ? _buildEmptyMessage("請先點擊球場上的球員")
              : (isLocked ? _buildEmptyMessage("🔒 此球員無法執行此動作") 
              : Padding(padding: const EdgeInsets.all(16.0), child: _buildActionGrid(provider))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage(String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(msg.contains("🔒") ? Icons.lock : Icons.touch_app, size: 48, color: Colors.white24),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _buildTabItem(MatchProvider provider, String title, int index) {
    final isActive = _selectedTabIndex == index;
    final isLocked = _isTabLocked(provider, index);

    return Expanded(
      child: GestureDetector(
        onTap: () { if (!isLocked) setState(() => _selectedTabIndex = index); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? Colors.blue : Colors.transparent, width: 3))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: TextStyle(color: isLocked ? Colors.white12 : (isActive ? Colors.white : Colors.white38), fontWeight: FontWeight.bold, fontSize: 14)),
              if (isLocked) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 14, color: Colors.white12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(MatchProvider provider) {
    List<Widget> buttons = [];
    switch (_selectedTabIndex) {
      case 0: buttons = [_buildBigButton(provider, 'Ace 得分', EventCategory.serve, 'Ace', _btnSuccess), _buildBigButton(provider, '發球成功 In', EventCategory.serve, 'InPlay', _btnNeutral), _buildBigButton(provider, '發球失誤', EventCategory.serve, 'Error', _btnError)]; break;
      case 1: buttons = [_buildBigButton(provider, '到位 Perfect', EventCategory.receive, 'Perfect', _btnNeutral), _buildBigButton(provider, '可打 Playable', EventCategory.receive, 'Good', _btnNeutral), _buildBigButton(provider, '不到位 Bad', EventCategory.receive, 'Bad', _btnNeutral), _buildBigButton(provider, '接球失誤', EventCategory.receive, 'Error', _btnError)]; break;
      case 2: buttons = [_buildBigButton(provider, '攻擊得分 Kill', EventCategory.attack, 'Kill', _btnSuccess), _buildBigButton(provider, '有效攻擊 InPlay', EventCategory.attack, 'InPlay', _btnNeutral), _buildBigButton(provider, '被攔回 Blocked', EventCategory.attack, 'BlockedCover', _btnNeutral), _buildBigButton(provider, '出界 Out', EventCategory.attack, 'Out', _btnError), _buildBigButton(provider, '被攔死 Stuffed', EventCategory.attack, 'BlockedDown', _btnError)]; break;
      case 3: buttons = [_buildBigButton(provider, '吊球得分', EventCategory.tip, 'Kill', _btnSuccess), _buildBigButton(provider, '有效吊球', EventCategory.tip, 'InPlay', _btnNeutral), _buildBigButton(provider, '吊球失誤', EventCategory.tip, 'Error', _btnError)]; break;
      case 4: buttons = [_buildBigButton(provider, '攔網得分', EventCategory.block, 'Kill', _btnSuccess), _buildBigButton(provider, '有效攔網', EventCategory.block, 'Touch', _btnNeutral), _buildBigButton(provider, '攔網失誤', EventCategory.block, 'Error', _btnError)]; break;
      case 5: buttons = [_buildBigButton(provider, '對方失誤 (送分)', EventCategory.oppError, 'Error', _btnSuccess), _buildBigButton(provider, '我方一般失誤', EventCategory.error, 'Fault', _btnError)]; break;
    }
    return GridView.count(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5, children: buttons);
  }

  Widget _buildBigButton(MatchProvider provider, String label, EventCategory category, String detail, Color color) {
    return ElevatedButton(
      onPressed: () => provider.handleEvent(category: category, detailType: detail),
      style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildBottomBar(MatchProvider provider) {
    final lastLog = provider.lastEvent;
    String logText = "LOG: 尚無紀錄...";
    if (lastLog != null) logText = "LOG: [${_getCategoryName(lastLog.category)}] ${lastLog.playerName} -> ${lastLog.detailType}";

    return Container(
      height: 56, padding: const EdgeInsets.symmetric(horizontal: 24), color: Colors.black26,
      child: Row(
        children: [
          Text(logText, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 14)),
          const Spacer(),
          ElevatedButton.icon(onPressed: () => provider.undo(), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0), icon: const Icon(Icons.undo, color: Colors.grey), label: const Text("Undo", style: TextStyle(color: Colors.grey))),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () => _scaffoldKey.currentState?.openEndDrawer(), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.withAlpha(50), elevation: 0), icon: const Icon(Icons.list, color: Colors.blueAccent), label: const Text("History", style: TextStyle(color: Colors.blueAccent))),
        ],
      ),
    );
  }

  void _handleSmartTabSwitch(MatchProvider provider, CourtPosition pos) {
    final lastEvent = provider.lastEvent;
    if (lastEvent == null) return;
    final isFrontRow = [CourtPosition.p2, CourtPosition.p3, CourtPosition.p4].contains(pos);
    final isDeadBall = lastEvent.outcome != EventOutcome.neutral;

    setState(() {
      if (isDeadBall) {
        _selectedTabIndex = (provider.isOurServe && pos == CourtPosition.p1) ? 0 : 1;
      } else if (lastEvent.category == EventCategory.receive || lastEvent.detailType == 'BlockedCover') {
        _selectedTabIndex = 2; 
      } else if (['InPlay', 'Good', 'Perfect'].contains(lastEvent.detailType)) {
        _selectedTabIndex = isFrontRow ? 4 : 1;
      }
    });
  }

  bool _isTabLocked(MatchProvider provider, int tabIndex) {
    final player = provider.selectedPlayer;
    if (player == null) return false;
    CourtPosition? pos = _getSelectedPosition(provider);
    if (pos == null) return false;
    final isFrontRow = [CourtPosition.p2, CourtPosition.p3, CourtPosition.p4].contains(pos);
    final isLibero = player.role == PlayerRole.libero;

    if (tabIndex == 0) return pos != CourtPosition.p1 || isLibero;
    if (tabIndex == 4) return !isFrontRow || isLibero;
    if (tabIndex == 2) return isLibero;
    return false;
  }

  CourtPosition? _getSelectedPosition(MatchProvider provider) {
    CourtPosition? pos;
    provider.positions.forEach((k, v) { if (v == provider.selectedPlayerId) pos = k; });
    return pos;
  }

  String _getCategoryName(EventCategory cat) => cat.toString().split('.').last.toUpperCase();

  Widget _buildHistoryDrawer(MatchProvider provider) {
    return Drawer(
      backgroundColor: _colBgPanel,
      child: Column(
        children: [
          DrawerHeader(child: Center(child: Text("SET ${provider.currentSet} 歷史紀錄", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
          Expanded(child: ListView.builder(
            // ★ 只顯示當局歷史
            itemCount: provider.currentSetHistory.length, 
            itemBuilder: (ctx, index) {
              final log = provider.currentSetHistory[index];
              final isPoint = log.outcome == EventOutcome.teamPoint;
              final isLoss = log.outcome == EventOutcome.oppPoint;
              return ListTile(
                leading: CircleAvatar(backgroundColor: isPoint ? Colors.blue : (isLoss ? Colors.red : Colors.grey[800]), child: Text('${log.playerJerseyNo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text("[${_getCategoryName(log.category)}] ${log.detailType}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("${log.playerName}  |  比分: ${log.scoreTeamA} - ${log.scoreTeamB}", style: const TextStyle(color: Colors.white70)),
              );
            }
          )),
        ],
      ),
    );
  }
}