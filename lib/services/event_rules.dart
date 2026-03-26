// lib/services/event_rules.dart
import 'package:system_recorder/models/event.dart';

class EventResult {
  final int scoreDeltaTeam;
  final int scoreDeltaOpp;
  final EventOutcome outcome;
  final String pointReason;
  final bool isForcedError;

  EventResult({
    required this.scoreDeltaTeam,
    required this.scoreDeltaOpp,
    required this.outcome,
    required this.pointReason,
    required this.isForcedError,
  });
}

class EventRules {
  static EventResult calculateOutcome({
    required EventCategory category,
    required String detailType,
  }) {
    int teamDelta = 0;
    int oppDelta = 0;
    EventOutcome outcome = EventOutcome.neutral;
    String pointReason = '';
    bool isForcedError = false;

    switch (category) {
      // 1. 發球
      case EventCategory.serve:
        if (detailType == 'Ace') {
          teamDelta = 1; outcome = EventOutcome.teamPoint; pointReason = 'OUR_SERVE';
        } else if (detailType == 'Error') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OUR_UNFORCED_ERROR'; isForcedError = false;
        }
        break;

      // 2. 接球
      case EventCategory.receive:
        if (detailType == 'Error') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OPP_SERVE'; isForcedError = true;
        }
        break;

      // 3. 攻擊
      case EventCategory.attack:
        if (detailType == 'Kill') {
          teamDelta = 1; outcome = EventOutcome.teamPoint; pointReason = 'OUR_ATTACK';
        } else if (detailType == 'Out') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OUR_UNFORCED_ERROR'; isForcedError = false;
        } else if (detailType == 'BlockedDown') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OPP_BLOCK'; isForcedError = true;
        }
        break;

      // 4. 吊球
      case EventCategory.tip:
        if (detailType == 'Kill') {
          teamDelta = 1; outcome = EventOutcome.teamPoint; pointReason = 'OUR_ATTACK';
        } else if (detailType == 'Error') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OUR_UNFORCED_ERROR'; isForcedError = false;
        }
        break;

      // 5. 攔網
      case EventCategory.block:
        if (detailType == 'Kill') {
          teamDelta = 1; outcome = EventOutcome.teamPoint; pointReason = 'OUR_BLOCK';
        } else if (detailType == 'Error') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OUR_UNFORCED_ERROR'; isForcedError = false;
        }
        break;

      // 6. 其他 (對方失誤 / 我方失誤)
      case EventCategory.oppError:
        if (detailType == 'Error') {
          teamDelta = 1; outcome = EventOutcome.teamPoint; pointReason = 'OPP_UNFORCED_ERROR'; isForcedError = false;
        }
        break;
      case EventCategory.error:
        if (detailType == 'Fault') {
          oppDelta = 1; outcome = EventOutcome.oppPoint; pointReason = 'OUR_UNFORCED_ERROR'; isForcedError = false;
        }
        break;
      
      default:
        break;
    }

    return EventResult(
      scoreDeltaTeam: teamDelta,
      scoreDeltaOpp: oppDelta,
      outcome: outcome,
      pointReason: pointReason,
      isForcedError: isForcedError,
    );
  }
}