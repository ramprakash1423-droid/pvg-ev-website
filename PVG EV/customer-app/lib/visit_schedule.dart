import 'package:flutter/material.dart' show TimeOfDay;

const indiaOffset = Duration(hours: 5, minutes: 30);

/// Calendar fields for Chennai. This value represents wall time, not an instant.
DateTime indiaWallTime(DateTime instant) => instant.toUtc().add(indiaOffset);

DateTime indiaCalendarDay(DateTime instant) {
  final wall = indiaWallTime(instant);
  return DateTime(wall.year, wall.month, wall.day);
}

DateTime visitCalendarDayAfter(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

TimeOfDay indiaClock(DateTime instant) {
  final wall = indiaWallTime(instant);
  return TimeOfDay(hour: wall.hour, minute: wall.minute);
}

/// Convert a Chennai date/time selection into the UTC instant sent to the API.
DateTime indiaVisitInstant(DateTime day, TimeOfDay time) => DateTime.utc(
  day.year,
  day.month,
  day.day,
  time.hour,
  time.minute,
).subtract(indiaOffset);

class VisitSchedule {
  const VisitSchedule(this.opens, this.closes);
  final int opens, closes;

  static VisitSchedule? from(dynamic value) {
    if (value is! Map) return null;
    final open = value['open_minutes'], close = value['close_minutes'];
    if (open is! int ||
        close is! int ||
        open < 0 ||
        close > 1440 ||
        open >= close) {
      return null;
    }
    return VisitSchedule(open, close);
  }

  static String clockLabel(int minutes) {
    final hour = (minutes ~/ 60) % 24;
    return '${hour % 12 == 0 ? 12 : hour % 12}:${(minutes % 60).toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }

  String get hoursLabel => '${clockLabel(opens)} – ${clockLabel(closes)}';
  String get timeError => 'Choose a visit between $hoursLabel (India time).';

  TimeOfDay get initialTime {
    final minutes = opens <= 600 && 600 < closes ? 600 : opens;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  bool containsClock(TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;
    return minutes >= opens && minutes < closes;
  }

  String? validate(DateTime? instant, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    if (instant == null ||
        !instant.isAfter(clock) ||
        !instant.isBefore(clock.add(const Duration(days: 31)))) {
      return 'Choose a future visit time within 30 days.';
    }
    return containsClock(indiaClock(instant)) ? null : timeError;
  }
}
