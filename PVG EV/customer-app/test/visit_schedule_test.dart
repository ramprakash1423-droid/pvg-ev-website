import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/service_availability.dart';
import 'package:pvg_customer/ui.dart';
import 'package:pvg_customer/visit_schedule.dart';

void main() {
  test(
    'Chennai date/time becomes the same UTC instant across device timezones',
    () {
      final instant = indiaVisitInstant(
        DateTime(2030, 1, 2),
        const TimeOfDay(hour: 6, minute: 0),
      );
      expect(instant, DateTime.utc(2030, 1, 2, 0, 30));
      expect(indiaClock(instant), const TimeOfDay(hour: 6, minute: 0));
      // UTC is still the previous date while the Chennai calendar has advanced.
      expect(
        indiaCalendarDay(DateTime.utc(2030, 1, 1, 20)),
        DateTime(2030, 1, 2),
      );
      expect(timeLabel('2030-01-01T20:00:00Z'), '2 Jan · 1:30 AM');
      expect(
        visitCalendarDayAfter(DateTime(2026, 11, 1), 1),
        DateTime(2026, 11, 2),
      );
      expect(timeLabel('2030-01-01T12:00:00-08:00'), '2 Jan · 1:30 AM');
    },
  );

  test('configured minutes govern both opening and closing boundaries', () {
    final schedule = VisitSchedule.from({
      'open_minutes': 570,
      'close_minutes': 1080,
    })!;
    final day = DateTime(2030, 1, 2), now = DateTime.utc(2030, 1, 1);
    expect(schedule.hoursLabel, '9:30 AM – 6:00 PM');
    expect(
      schedule.validate(
        indiaVisitInstant(day, const TimeOfDay(hour: 9, minute: 29)),
        now: now,
      ),
      schedule.timeError,
    );
    expect(
      schedule.validate(
        indiaVisitInstant(day, const TimeOfDay(hour: 9, minute: 30)),
        now: now,
      ),
      isNull,
    );
    expect(
      schedule.validate(
        indiaVisitInstant(day, const TimeOfDay(hour: 17, minute: 59)),
        now: now,
      ),
      isNull,
    );
    expect(
      schedule.validate(
        indiaVisitInstant(day, const TimeOfDay(hour: 18, minute: 0)),
        now: now,
      ),
      schedule.timeError,
    );
    expect(schedule.validate(now, now: now), contains('future'));
    expect(
      schedule.validate(now.add(const Duration(days: 31)), now: now),
      contains('30 days'),
    );
    expect(VisitSchedule.from(null), isNull);
    expect(
      VisitSchedule.from({'open_minutes': 1000, 'close_minutes': 600}),
      isNull,
    );
  });

  testWidgets(
    'service card shows configured hours without a hardcoded Chennai schedule',
    (tester) async {
      final api = PvgApi(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      api.config = {
        'service': {'open_minutes': 570, 'close_minutes': 1080},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceAvailability(api: api, onBook: () {}),
          ),
        ),
      );
      expect(find.text('9:30 AM – 6:00 PM IST'), findsOneWidget);
      expect(find.textContaining('11:00 PM'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
