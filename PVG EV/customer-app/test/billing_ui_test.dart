import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/booking_detail.dart';

// Isolated HTTP/image fixtures: no customer records or payment provider calls.
Map<String, dynamic> reviewBooking() => {
  'id': 'isolated-bill',
  'reference': 'PVG-UI-TEST',
  'version': 4,
  'status': 'awaiting_acceptance',
  'slot': '2030-01-02T04:30:00Z',
  'ev': {'model': 'Isolated EV', 'registration': 'UNIT TEST'},
  'address': 'Isolated widget test address',
  'technician': null,
  'events': [],
  'reading': {
    'id': 'isolated-reading',
    'revision': 1,
    'kind': 'session',
    'photo':
        'data:image/png;base64,${base64Encode(File('../pvg-service/fixtures/demo-meter.png').readAsBytesSync())}',
    'bill': {
      'energy_milli': 10000,
      'unit_rate_paise': 2000,
      'energy_paise': 20000,
      'visit_fee_paise': 30000,
      'tax_basis_points': 1800,
      'tax_paise': 9000,
      'total_paise': 59000,
    },
  },
};

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'review action stays available on a small screen at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = PvgApi(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            return http.Response(jsonEncode(reviewBooking()), 200);
          }),
        );
        addTearDown(api.dispose);
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: BookingDetail(api: api, bookingId: 'isolated-bill'),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Accept units & continue',
        );
        await tester.ensureVisible(button);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(640));
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.ensureVisible(
          find.byKey(const Key('accept-units-checkbox')),
        );
        await tester.tap(find.byKey(const Key('accept-units-checkbox')));
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(find.textContaining('Pay ₹'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('meter preview is bounded and opens the full inspection view', (
    tester,
  ) async {
    final api = PvgApi(
      client: MockClient(
        (request) async => http.Response(jsonEncode(reviewBooking()), 200),
      ),
    );
    addTearDown(api.dispose);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetail(api: api, bookingId: 'isolated-bill'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    final image = find.byType(Image).first;
    await tester.ensureVisible(image);
    expect(tester.getSize(image).height, 132);
    await tester.tap(image);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a corrected reading after a version conflict needs its own valid evidence and fresh consent',
    (tester) async {
      var corrected = false, validCorrection = false, acceptRequests = 0;
      final api = PvgApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/accept')) {
            acceptRequests++;
            corrected = true;
            return http.Response(
              jsonEncode({
                'error': 'The reading changed. Review the latest reading.',
              }),
              409,
            );
          }
          final data = reviewBooking();
          if (corrected) {
            data['version'] = 5;
            final reading = data['reading'] as Map<String, dynamic>;
            reading['id'] = 'corrected-reading';
            reading['revision'] = 2;
            if (!validCorrection) {
              // Valid base64 containing no decodable image, confined to this test.
              reading['photo'] =
                  'data:image/png;base64,${base64Encode([1, 2, 3])}';
            }
          }
          return http.Response(jsonEncode(data), 200);
        }),
      );
      addTearDown(api.dispose);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BookingDetail(api: api, bookingId: 'isolated-bill'),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      final checkbox = find.byKey(const Key('accept-units-checkbox'));
      final accept = find.widgetWithText(
        FilledButton,
        'Accept units & continue',
      );
      expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNotNull);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
      await tester.runAsync(() async {
        await tester.tap(accept);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(acceptRequests, 1);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNull);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      expect(
        find.text('The reading changed. Review the latest reading.'),
        findsOneWidget,
      );
      expect(
        find.text('Meter evidence must load before you can accept.'),
        findsOneWidget,
      );

      // A later successfully loaded correction unlocks the checkbox, never
      // the action itself: the customer must consent again to the new record.
      validCorrection = true;
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Refresh booking'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(checkbox).onChanged, isNotNull);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);
      await tester.tap(checkbox);
      await tester.pump();
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
      expect(acceptRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
