class CheckinEvent {
  CheckinEvent({
    required this.id,
    required this.logType,
    required this.time,
    this.isLateEntry = false,
    this.isEarlyExit = false,
  });

  final String id;
  final String logType; // IN / OUT
  final DateTime time;
  final bool isLateEntry; // True if check-in was after shift start time
  final bool isEarlyExit; // True if check-out was before shift end time
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


