import 'package:system_recorder/models/player.dart';

class RotationService {
  // 加入 reverse 參數，支援手動逆向輪轉
  static Map<CourtPosition, String?> rotatePositions(
      Map<CourtPosition, String?> currentPositions, {bool reverse = false}) {
    final newPositions = Map<CourtPosition, String?>.from(currentPositions);

    if (reverse) {
      // 逆時針 (退回上一個輪轉) 1->2->3->4->5->6->1
      newPositions[CourtPosition.p2] = currentPositions[CourtPosition.p1];
      newPositions[CourtPosition.p3] = currentPositions[CourtPosition.p2];
      newPositions[CourtPosition.p4] = currentPositions[CourtPosition.p3];
      newPositions[CourtPosition.p5] = currentPositions[CourtPosition.p4];
      newPositions[CourtPosition.p6] = currentPositions[CourtPosition.p5];
      newPositions[CourtPosition.p1] = currentPositions[CourtPosition.p6];
    } else {
      // 標準順時針 1->6->5->4->3->2->1
      newPositions[CourtPosition.p6] = currentPositions[CourtPosition.p1];
      newPositions[CourtPosition.p5] = currentPositions[CourtPosition.p6];
      newPositions[CourtPosition.p4] = currentPositions[CourtPosition.p5];
      newPositions[CourtPosition.p3] = currentPositions[CourtPosition.p4];
      newPositions[CourtPosition.p2] = currentPositions[CourtPosition.p3];
      newPositions[CourtPosition.p1] = currentPositions[CourtPosition.p2];
    }

    return newPositions;
  }
}