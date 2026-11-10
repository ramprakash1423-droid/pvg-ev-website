import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/main.dart';
import 'package:pvg_customer/booking_detail.dart';
import 'package:pvg_customer/booking_screen.dart';
import 'package:pvg_customer/personal_screens.dart';

void main() {
  testWidgets(
    'home pickers carry the selected place, EV and estimate into booking',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final vehicles = [
        {
          'id': 'ev1',
          'model': 'Nexon EV',
          'registration': 'TEST 01',
          'connector': 'CCS2',
        },
        {
          'id': 'ev2',
          'model': 'MG ZS EV',
          'registration': 'TEST 02',
          'connector': 'CCS2',
        },
      ];
      final places = [
        {
          'id': 'home1',
          'label': 'Home',
          'address': 'Home test address, Chennai',
          'pincode': '600020',
          'access_notes': 'Gate 1',
        },
        {
          'id': 'work1',
          'label': 'Work',
          'address': 'Work test address, Chennai',
          'pincode': '600042',
          'access_notes': 'Gate 2',
        },
      ];
      final api = PvgApi(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(switch (r.url.path) {
              '/api/auth/verify' => {
                'token': 'test-token',
                'expires_in': 3600,
                'user': {
                  'id': 'customer1',
                  'role': 'customer',
                  'name': 'Test customer',
                },
              },
              '/api/config' => {'mode': 'local_preview', 'tariff': {}},
              '/api/evs' => {'vehicles': vehicles},
              '/api/places' => {'places': places},
              '/api/preferences' => {'default_vehicle_id': 'ev1'},
              _ => {'bookings': []},
            }),
            200,
          ),
        ),
      );
      await api.verifyOtp('challenge', '123456');
      await tester.pumpWidget(PvgCustomerApp(api: api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home test address, Chennai'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Work'));
      await tester.pumpAndSettle();
      expect(find.text('Work test address, Chennai'), findsOneWidget);
      await tester.tap(find.text('Nexon EV'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'MG ZS EV'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('25 kWh').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('25 kWh'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Continue to booking').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue to booking'));
      await tester.pumpAndSettle();
      final screen = tester.widget<BookingScreen>(find.byType(BookingScreen));
      expect(screen.prefill?['id'], 'work1');
      expect(screen.prefill?['ev']['id'], 'ev2');
      expect(screen.initialEnergy, 25);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Work'))
            .selected,
        isTrue,
      );
      expect(find.text('Work test address, Chennai'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Gate 2'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gate 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'small phone remains usable with enlarged text and guest navigation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final api = PvgApi(
        client: MockClient(
          (r) async =>
              http.Response('{"mode":"local_preview","tariff":{}}', 200),
        ),
      );
      await tester.pumpWidget(PvgCustomerApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Garage'));
      await tester.pumpAndSettle();
      expect(find.text('A home for your EVs.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'three-step booking reuses a place and requires a future slot and explicit consent',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submitted;
      final ev = {
        'id': 'ev1',
        'model': 'Test Nexon',
        'registration': 'TEST EV',
        'connector': 'CCS2',
      };
      final place = {
        'id': 'home1',
        'label': 'Home',
        'address': '12 Test Street, Chennai',
        'pincode': '600020',
        'access_notes': 'Gate 2',
        'latitude': 13.1,
        'longitude': 80.2,
      };
      final api = PvgApi(
        client: MockClient((r) async {
          final path = r.url.path;
          final result = switch (path) {
            '/api/evs' => {
              'vehicles': [ev],
            },
            '/api/places' => {
              'places': [place],
            },
            '/api/preferences' => {'default_vehicle_id': 'ev1'},
            _ => {
              'id': 'new-booking',
              'reference': 'PVG-TEST',
              'status': 'requested',
              'version': 1,
              'ev': ev,
              'slot': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
              'address': place['address'],
              'estimate': {
                'energy_milli': 10000,
                'unit_rate_paise': 2200,
                'energy_paise': 22000,
                'visit_fee_paise': 25000,
                'tax_basis_points': 1800,
                'tax_paise': 8460,
                'total_paise': 55460,
              },
              'tariff': {'tax_note': 'Configured tax'},
              'events': [],
              'tracking': {'state': 'awaiting_assignment', 'position': null},
            },
          };
          if (path == '/api/bookings') submitted = jsonDecode(r.body);
          return http.Response(jsonEncode(result), 200);
        }),
      );
      api.config = {
        'tariff': {
          'unit_rate_paise': 2200,
          'visit_fee_paise': 25000,
          'tax_basis_points': 1800,
        },
      };
      await tester.pumpWidget(
        MaterialApp(home: BookingScreen(api: api, initialEnergy: 10)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(submitted, isNull);
      final dateButton = find.text('Choose a date & time');
      await tester.scrollUntilVisible(
        dateButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(dateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(
        FilledButton,
        'Request charging visit',
      );
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile).hitTestable(),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(submitted?['vehicle_id'], 'ev1');
      expect(submitted?['address'], place['address']);
      expect(submitted?['latitude'], 13.1);
      expect(submitted?['estimated_kwh'], '10.0');
      expect(
        DateTime.parse(submitted!['slot']).isAfter(DateTime.now()),
        isTrue,
      );
      expect(find.byType(BookingDetail), findsOneWidget);
      expect(find.text('Track my charging vehicle'), findsOneWidget);
      expect(find.text('We’ve received your request.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets('editing a saved address clears an old GPS pin before saving', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final api = PvgApi(
      client: MockClient((r) async {
        submitted = jsonDecode(r.body);
        return http.Response('{}', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceEditor(
          api: api,
          place: {
            'id': 'place1',
            'label': 'Home',
            'address': 'Old Chennai address',
            'pincode': '600020',
            'access_notes': '',
            'latitude': 13.1,
            'longitude': 80.2,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full address & landmark'),
      'New Chennai address',
    );
    final save = find.text('Save place');
    await tester.scrollUntilVisible(
      save,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(submitted?['address'], 'New Chennai address');
    expect(submitted?['latitude'], isNull);
    expect(submitted?['longitude'], isNull);
    api.dispose();
  });
  testWidgets(
    'guest can browse and booking opens sign in without sending OTP',
    (tester) async {
      final calls = <String>[];
      final api = PvgApi(
        client: MockClient((request) async {
          calls.add(request.url.path);
          return http.Response(
            jsonEncode({
              'mode': 'local_preview',
              'tariff': {},
              'integrations': {},
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(PvgCustomerApp(api: api));
      await tester.pumpAndSettle();
      expect(find.text('Your day.\nFully charged.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Continue to booking').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue to booking'));
      await tester.pumpAndSettle();
      expect(find.text('Power your day.'), findsOneWidget);
      expect(calls.where((s) => s.contains('/auth/otp')), isEmpty);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  testWidgets(
    'accept button stays disabled until customer confirms; exact reviewed total is sent',
    (tester) async {
      tester.view.physicalSize = const Size(430, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bill = {
        'energy_milli': 12500,
        'unit_rate_paise': 2200,
        'energy_paise': 27500,
        'visit_fee_paise': 25000,
        'tax_paise': 0,
        'total_paise': 52500,
      };
      final booking = {
        'id': 'booking1',
        'reference': 'PVG-2001',
        'status': 'awaiting_acceptance',
        'version': 6,
        'ev': {'model': 'Sample EV', 'registration': 'TEST'},
        'slot': '2026-11-10T09:00:00Z',
        'address': 'Chennai demo address',
        'technician': null,
        'reading': {
          'id': 'reading1',
          'revision': 1,
          'kind': 'session',
          'photo':
              'data:image/png;base64,${base64Encode(File('../pvg-service/fixtures/demo-meter.png').readAsBytesSync())}',
          'bill': bill,
        },
        'events': [],
      };
      Map<String, dynamic>? submitted;
      final api = PvgApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/accept')) {
            submitted = jsonDecode(request.body);
            booking['status'] = 'awaiting_payment';
            booking['invoice'] = {'bill': bill};
          }
          return http.Response(jsonEncode(booking), 200);
        }),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookingDetail(api: api, bookingId: 'booking1'),
          ),
        );
        // Native image decoding runs outside the widget tester's fake clock.
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final accept = find.widgetWithText(
        FilledButton,
        'Accept units & continue',
      );
      await tester.ensureVisible(accept);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(find.byKey(const Key('accept-units-checkbox')));
      await tester.pump();
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(accept);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(submitted, {
        'version': 6,
        'reading_id': 'reading1',
        'total_paise': 52500,
        'accepted': true,
      });
      expect(find.text('Pay ₹525.00 · test'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );
  test('API clears customer session after unauthorized response', () async {
    int call = 0;
    final api = PvgApi(
      client: MockClient((request) async {
        call++;
        if (call == 1) {
          return http.Response(
            jsonEncode({
              'token': 'test-token',
              'user': {'role': 'customer'},
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('{"error":"Session expired"}', 401);
      }),
    );
    await api.verifyOtp('challenge', '123456');
    expect(api.signedIn, true);
    await expectLater(api.bookings(), throwsException);
    expect(api.signedIn, false);
    api.dispose();
  });
}
