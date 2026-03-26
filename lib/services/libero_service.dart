import 'package:system_recorder/models/player.dart';
import 'package:system_recorder/models/event.dart';

class LiberoService {
  // 檢查是否允許該動作
  static bool isActionAllowed(Player player, CourtPosition currentPos, EventCategory action) {
    if (player.role != PlayerRole.libero) {
      // --- 非自由球員 ---
      // 1. 如果是後排，不能攔網
      if ([CourtPosition.p1, CourtPosition.p6, CourtPosition.p5].contains(currentPos)) {
        if (action == EventCategory.block) return false;
      }
      // 2. 只有 P1 可以發球
      if (action == EventCategory.serve && currentPos != CourtPosition.p1) {
        return false;
      }
      return true;
    }

    // --- 自由球員限制 (Libero) ---
    if (action == EventCategory.serve) return false; 
    if (action == EventCategory.block) return false;
    if (action == EventCategory.attack) return false; 

    return true;
  }

  // 檢查輪轉後，Libero 是否會非法進入前排 (P2, P3, P4)
  // 如果現在在 P5，輪轉後會去 P4 -> 必須換出
  static bool shouldSwapOutBeforeRotation(CourtPosition liberoCurrentPos) {
    return liberoCurrentPos == CourtPosition.p5; 
  }
}