import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/main.dart';
import 'package:pvg_customer/ui.dart';
import 'package:pvg_customer/updates_screen.dart';

class LiveTestApi extends PvgApi {
  LiveTestApi({required super.client});
  final events = StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get changes => events.stream;
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

void main() {
  testWidgets(
    'updates show actual staff notes, retain GPS audit and refresh on events',
    (tester) async {
      final now = DateTime.now().toUtc().toIso8601String();
      var note = 'Your technician is checking the entrance.';
      var opened = false;
      final api = LiveTestApi(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/auth/verify')
                  ? {
                      'token': 'isolated-token',
                      'expires_in': 3600,
                      'user': {
                        'id': 'isolated-user',
                        'name': 'UI test',
                        'role': 'customer',
                      },
                    }
                  : request.url.path.endsWith('/bookings')
                  ? {
                      'bookings': [
                        {
                          'id': 'isolated-visit',
                          'reference': 'UNIT-ONLY',
                          'status': 'awaiting_acceptance',
                          'events': [
                            {'action': 'gps_started', 'created_at': now},
                            {
                              'action': 'support_updated',
                              'created_at': now,
                              'note': note,
                            },
                          ],
                        },
                      ],
                    }
                  : <String, dynamic>{},
            ),
            200,
          ),
        ),
      );
      await api.verifyOtp('isolated', '123456');
      await tester.pumpWidget(
        MaterialApp(
          theme: pvgTheme(),
          home: UpdatesScreen(
            api: api,
            onOpen: (_) async {
              opened = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(note), findsOneWidget);
      expect(find.text('Review units & bill'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Technician enabled GPS sharing'), findsNothing);
      await tester.tap(find.text('All activity'));
      await tester.pumpAndSettle();
      expect(find.text('Technician enabled GPS sharing'), findsOneWidget);
      note = 'Please meet the technician at gate two.';
      api.events.add({
        'kind': 'booking_changed',
        'booking_id': 'isolated-visit',
      });
      await tester.pumpAndSettle();
      expect(find.text(note), findsOneWidget);
      await tester.tap(find.text('Review units & bill'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      await api.signOut();
      await tester.pumpAndSettle();
      expect(find.text(note), findsNothing);
      expect(find.text('Review units & bill'), findsNothing);
      expect(find.textContaining('Your session has ended'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'late activity response cannot restore private notes after sign-out',
    (tester) async {
      final late = Completer<http.Response>();
      var bookingReads = 0;
      final api = LiveTestApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/verify')) {
            return http.Response(
              jsonEncode({
                'token': 'isolated-token',
                'expires_in': 3600,
                'user': {
                  'id': 'isolated-owner',
                  'name': 'UI test',
                  'role': 'customer',
                },
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/bookings')) {
            bookingReads++;
            if (bookingReads > 1) return late.future;
            return http.Response('{"bookings":[]}', 200);
          }
          return http.Response('{}', 200);
        }),
      );
      await api.verifyOtp('isolated', '123456');
      await tester.pumpWidget(
        MaterialApp(
          theme: pvgTheme(),
          home: UpdatesScreen(api: api, onOpen: (_) async {}),
        ),
      );
      await tester.pumpAndSettle();
      api.events.add({'kind': 'booking_changed'});
      await tester.pumpAndSettle();
      await api.signOut();
      late.complete(
        http.Response(
          jsonEncode({
            'bookings': [
              {
                'id': 'isolated-visit',
                'status': 'awaiting_acceptance',
                'reference': 'UNIT-PRIVATE',
                'events': [
                  {
                    'action': 'support_updated',
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                    'note': 'Private old-session response',
                  },
                ],
              },
            ],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private old-session response'), findsNothing);
      expect(find.text('Review units & bill'), findsNothing);
      expect(find.textContaining('Your session has ended'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  testWidgets(
    'compact garage supports large text and keeps destructive actions in a menu',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
              '/api/bookings' => {'bookings': []},
              '/api/evs' => {
                'vehicles': [
                  {
                    'id': 'isolated-ev',
                    'model': 'Saved electric vehicle',
                    'registration': 'UNIT ONLY',
                    'connector': 'Not sure',
                  },
                ],
              },
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
      await tester.tap(find.text('Garage'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm connector'), findsOneWidget);
      expect(find.text('Not sure connector'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit EV'), findsOneWidget);
      expect(find.text('Remove EV'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.dispose();
    },
  );

  test('secondary text meets readable contrast on the app surfaces', () {
    for (final background in [Colors.white, canvas]) {
      final contrast =
          (background.computeLuminance() + .05) /
          (muted.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
  });
}
