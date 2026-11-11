import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/booking_screen.dart';
import 'package:pvg_customer/ui.dart';
import 'package:pvg_customer/visit_schedule.dart';

PvgApi isolatedApi({
  Future<http.Response> Function(http.Request)? availability,
}) {
  final api = PvgApi(
    client: MockClient((r) async {
      if (r.url.path == '/api/availability' && availability != null) {
        return availability(r);
      }
      return http.Response(
        jsonEncode(switch (r.url.path) {
          '/api/evs' => {
            'vehicles': [
              {
                'id': 'unit-ev',
                'model': 'Unit EV',
                'registration': 'UNIT TEST',
                'connector': 'CCS2',
              },
            ],
          },
          '/api/places' => {'places': []},
          _ => {},
        }),
        200,
      );
    }),
  );
  api.config = {
    if (availability != null) 'mode': 'supabase',
    'service': {'open_minutes': 360, 'close_minutes': 1380},
    'tariff': {
      'unit_rate_paise': 2000,
      'visit_fee_paise': 30000,
      'tax_basis_points': 1800,
    },
  };
  return api;
}

String calendarKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
String slotFor(DateTime day) => indiaVisitInstant(
  day,
  const TimeOfDay(hour: 10, minute: 0),
).toIso8601String();
http.Response availabilityResponse(String date, List<String> slots) =>
    http.Response(
      jsonEncode({
        'date': date,
        'state': 'slots_available',
        'settings': {'open_minutes': 360, 'close_minutes': 1380},
        'slots': slots,
        'message': 'Available request times for $date.',
      }),
      200,
    );

Future<void> requestDay(
  WidgetTester tester,
  DateTime day, {
  bool pending = false,
}) async {
  final button = find.widgetWithText(OutlinedButton, 'Choose a date & time');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  tester
      .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
      .onDateChanged(day);
  await tester.pump();
  await tester.tap(find.text('OK'));
  if (pending) {
    await tester.pump(const Duration(milliseconds: 350));
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> openPlaceStep(WidgetTester tester, PvgApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: pvgTheme(),
      home: BookingScreen(
        api: api,
        prefill: const {
          'address': 'Isolated Chennai parking address',
          'pincode': '600020',
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'small-phone booking focuses each missing field where the error is shown',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = isolatedApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: pvgTheme(),
          home: BookingScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CHARGING AT YOUR DOORSTEP'), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final address = find.widgetWithText(
        TextFormField,
        'Full address & landmark',
      );
      final pincode = find.widgetWithText(TextFormField, 'Chennai pincode');
      expect(find.text('Enter the full charging address'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: address, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(address, 'Isolated unit-test parking address');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Use a Chennai pincode (600xxx)'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: pincode, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(pincode, '600020');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a future visit time within 30 days.'),
        findsOneWidget,
      );
      final time = find.widgetWithText(OutlinedButton, 'Choose a date & time');
      expect(time.hitTestable(), findsOneWidget);
      expect(tester.widget<OutlinedButton>(time).focusNode!.hasFocus, isTrue);
      expect(find.textContaining('₹'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets('compact parking controls remove only the optional pin', (
    tester,
  ) async {
    final api = isolatedApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: pvgTheme(),
        home: BookingScreen(
          api: api,
          prefill: const {
            'address': 'Unchanged unit-test Chennai address',
            'pincode': '600020',
            'latitude': 13.08,
            'longitude': 80.27,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final remove = find.byTooltip('Remove GPS location');
    await tester.scrollUntilVisible(
      remove,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Use GPS'), findsOneWidget);
    expect(find.text('Choose on map'), findsOneWidget);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Parking pin · optional'), findsOneWidget);
    expect(find.byTooltip('Remove GPS location'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Full address & landmark'),
          )
          .controller!
          .text,
      'Unchanged unit-test Chennai address',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });
  testWidgets(
    'changing date clears old slots even when the new request fails',
    (tester) async {
      final firstDay = visitCalendarDayAfter(
        indiaCalendarDay(DateTime.now()),
        1,
      );
      final nextDay = visitCalendarDayAfter(firstDay, 1);
      final pending = Completer<http.Response>();
      var calls = 0;
      final queriedDates = <String>[];
      final api = isolatedApi(
        availability: (r) async {
          queriedDates.add(r.url.queryParameters['date']!);
          if (++calls == 2) return pending.future;
          return availabilityResponse(calendarKey(firstDay), [
            slotFor(firstDay),
          ]);
        },
      );
      await openPlaceStep(tester, api);
      await requestDay(tester, firstDay);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(firstDay))),
        findsOneWidget,
      );
      await requestDay(tester, nextDay, pending: true);
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(firstDay))),
        findsNothing,
      );
      pending.complete(
        http.Response(
          jsonEncode({'error': 'Availability temporarily unavailable.'}),
          503,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.text('Availability temporarily unavailable.'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(queriedDates, [calendarKey(firstDay), calendarKey(nextDay)]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'old pincode response cannot replace newer-date slots or reopen its time picker',
    (tester) async {
      final firstDay = visitCalendarDayAfter(
        indiaCalendarDay(DateTime.now()),
        1,
      );
      final nextDay = visitCalendarDayAfter(firstDay, 1);
      final old = Completer<http.Response>();
      final pins = <String>[];
      final api = isolatedApi(
        availability: (r) async {
          final pin = r.url.queryParameters['pincode']!;
          pins.add(pin);
          if (pin == '600020') return old.future;
          // Incorrectly returned old-day slots are also filtered out defensively.
          return availabilityResponse(calendarKey(nextDay), [
            slotFor(nextDay),
            slotFor(firstDay),
          ]);
        },
      );
      await openPlaceStep(tester, api);
      await requestDay(tester, firstDay, pending: true);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Chennai pincode'),
        '600042',
      );
      await tester.pumpAndSettle();
      await requestDay(tester, nextDay);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(nextDay))),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(firstDay))),
        findsNothing,
      );
      old.complete(
        availabilityResponse(calendarKey(firstDay), [slotFor(firstDay)]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(nextDay))),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ChoiceChip, timeLabel(slotFor(firstDay))),
        findsNothing,
      );
      expect(pins, ['600020', '600042']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
}
