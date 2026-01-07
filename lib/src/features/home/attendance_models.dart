class CheckinEvent {
  CheckinEvent({
    required this.id,
    required this.logType,
    required this.time,
  });

  final String id;
  final String logType; // IN / OUT
  final DateTime time;
}

class AttendanceAnalytics {
  const AttendanceAnalytics({
    required this.todayWorked,
    required this.weekWorked,
    required this.todayGoal,
    required this.weekGoal,
  });

  final Duration todayWorked;
  final Duration weekWorked;
  final Duration todayGoal;
  final Duration weekGoal;
}


