import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/main.dart';
import 'package:pvg_customer/tracking_experience.dart';
import 'package:pvg_customer/visit_tracking.dart';
import 'tracking_test.dart' show OfflineTiles;

void main() {
  testWidgets('older bill never displaces a dispatched visit on Home', (
    tester,
  ) async {
    final current = <String, dynamic>{
      'id': 'isolated-current',
      'reference': 'UNIT-CURRENT',
      'status': 'on_the_way',
      'slot': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'address': 'Isolated widget-test address',
      'technician': {'name': 'Isolated technician'},
      'events': [],
      'tracking': {'state': 'not_sharing', 'position': null},
    };
    final older = {
      ...current,
      'id': 'isolated-older',
      'reference': 'UNIT-OLDER',
      'status': 'awaiting_payment',
      'invoice': {
        'bill': {'total_paise': 50000},
      },
    };
    final api = PvgApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(switch (request.url.path) {
            '/api/auth/verify' => {
              'token': 'isolated-token',
              'expires_in': 3600,
              'user': {
                'id': 'isolated-user',
                'name': 'UI test',
                'role': 'customer',
              },
            },
            '/api/config' => {
              'mode': 'supabase',
              'realtime': false,
              'tariff': {},
            },
            '/api/bookings' => {
              'bookings': [older, current],
            },
            '/api/evs' => {'vehicles': []},
            '/api/places' => {'places': []},
            _ => <String, dynamic>{},
          }),
          200,
        ),
      ),
    );
    await api.verifyOtp('isolated', '123456');
    await tester.pumpWidget(PvgCustomerApp(api: api));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TrackingExperience>(find.byType(TrackingExperience))
          .booking?['id'],
      'isolated-current',
    );
    expect(find.text('UNIT-OLDER needs your attention'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    api.dispose();
  });

  testWidgets(
    'empty tracker has no invented vehicle, pin or arrival estimate on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(home: EmptyTrackingScreen(onBook: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('Technician not assigned'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Call technician'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -380));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'known destination appears before vehicle GPS without inventing a vehicle pin',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisitTracking(
                prominent: true,
                tileProvider: OfflineTiles(),
                booking: {
                  'latitude': 13.01,
                  'longitude': 80.22,
                  'tracking': {'state': 'not_sharing', 'position': null},
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        1,
      );
      expect(find.textContaining('enable GPS sharing'), findsOneWidget);
      expect(find.textContaining('straight-line'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'signed-in active visit becomes Home instead of the marketing hero',
    (tester) async {
      final b = {
        'id': 'owned-booking',
        'reference': 'PVG-TEST',
        'status': 'assigned',
        'slot': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'address': 'Unit test address',
        'technician': {'name': 'Assigned technician', 'phone': '9000000001'},
        'fleet_name': 'Assigned vehicle',
        'fleet_registration': 'TEST REG',
        'events': [],
        'tracking': {'state': 'not_sharing', 'position': null},
      };
      final api = PvgApi(
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(switch (r.url.path) {
              '/api/auth/verify' => {
                'token': 'unit-test',
                'user': {'id': 'customer', 'name': 'Test', 'role': 'customer'},
                'expires_in': 3600,
              },
              '/api/config' => {
                'mode': 'supabase',
                'realtime': false,
                'tariff': {},
              },
              '/api/bookings' => {
                'bookings': [b],
              },
              '/api/evs' => {'vehicles': []},
              '/api/places' => {'places': []},
              _ => {},
            }),
            200,
          ),
        ),
      );
      await api.verifyOtp('test', '123456');
      await tester.pumpWidget(PvgCustomerApp(api: api));
      await tester.pumpAndSettle();
      expect(find.byType(TrackingExperience), findsOneWidget);
      expect(find.text('Your day. Fully charged.'), findsNothing);
      expect(find.text('Your charging team is assigned.'), findsOneWidget);
      expect(find.text('TEST REG'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'travelling view puts the map before team and the next action before history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingExperience(
                booking: {
                  'id': 'owned-travel',
                  'reference': 'PVG-UNIT',
                  'status': 'on_the_way',
                  'slot': '2030-01-02T04:30:00Z',
                  'address': 'Isolated parking address',
                  'latitude': 13.01,
                  'longitude': 80.22,
                  'technician': {
                    'name': 'Assigned technician',
                    'phone': '9000000001',
                  },
                  'fleet_name': 'Assigned vehicle',
                  'fleet_registration': 'UNIT REG',
                  'events': [
                    {
                      'action': 'on_the_way',
                      'created_at': '2030-01-02T04:00:00Z',
                    },
                  ],
                  'tracking': {'state': 'not_sharing', 'position': null},
                },
                tileProvider: OfflineTiles(),
                onDetails: () => opened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mapTop = tester.getTopLeft(find.byType(VisitTracking)).dy;
      final teamTop = tester.getTopLeft(find.byKey(const Key('visit-team'))).dy;
      final actionTop = tester
          .getTopLeft(find.byKey(const Key('visit-next-action')))
          .dy;
      expect(mapTop, lessThan(teamTop));
      expect(actionTop, lessThan(teamTop));
      expect(
        tester.getSize(find.byKey(const Key('tracking-status'))).height,
        lessThan(160),
      );
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
        1,
      );
      await tester.ensureVisible(find.text('View booking details'));
      await tester.tap(find.text('View booking details'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an actionable bill sits above the team without putting prices or a map on Home',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrackingExperience(
                booking: {
                  'id': 'owned-review',
                  'reference': 'PVG-UNIT',
                  'status': 'awaiting_acceptance',
                  'slot': '2030-01-02T04:30:00Z',
                  'address': 'Isolated parking address',
                  'technician': null,
                  'events': [],
                },
                onDetails: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review units & bill'), findsOneWidget);
      expect(find.byType(VisitTracking), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const Key('visit-next-action'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('visit-team'))).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'real status transitions respect reduced motion and retain actual service notes on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      String status = 'assigned';
      final booking = <String, dynamic>{
        'id': 'owned-status',
        'reference': 'PVG-UNIT',
        'slot': '2030-01-02T04:30:00Z',
        'address': 'Isolated parking address with gate details',
        'technician': {'name': 'Assigned technician', 'phone': '9000000001'},
        'fleet_name': 'Assigned vehicle',
        'fleet_registration': 'UNIT REG',
        'tracking': {'state': 'not_sharing', 'position': null},
        'events': [
          {
            'action': 'service_update',
            'created_at': '2030-01-02T04:00:00Z',
            'note': 'Your team is preparing for departure.',
          },
        ],
      };
      Widget screen() => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TrackingExperience(
                booking: {...booking, 'status': status},
                onDetails: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Your charging team is assigned.'), findsOneWidget);
      status = 'charging';
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Your EV is being charged.'), findsOneWidget);
      expect(
        find.text('Your team is preparing for departure.'),
        findsOneWidget,
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .every((w) => w.duration == Duration.zero),
        isTrue,
      );
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
