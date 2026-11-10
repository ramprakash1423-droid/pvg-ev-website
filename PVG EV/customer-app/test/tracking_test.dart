import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pvg_customer/visit_tracking.dart';

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

void main() {
  testWidgets(
    'tracking distinguishes unassigned, not sharing and ended without inventing a location',
    (tester) async {
      for (final entry in {
        'awaiting_assignment': 'after assignment',
        'not_sharing': 'enable GPS sharing',
        'ended': 'has ended',
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VisitTracking(
                booking: {
                  'tracking': {'state': entry.key, 'position': null},
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(entry.value), findsOneWidget);
        expect(find.byType(FlutterMap), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'tracking map marks stale and sample feeds honestly on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final provider = OfflineTiles();
      Future<void> render({
        String source = 'device',
        bool stale = false,
        bool lost = false,
        bool incorrectPhoneClock = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VisitTracking(
                  tileProvider: provider,
                  connectionLost: lost,
                  booking: {
                    'fleet_name': 'PVG Mobile 01',
                    'technician': {'name': 'Sample technician'},
                    'latitude': 13.0067,
                    'longitude': 80.2575,
                    'tracking': {
                      'state': 'live',
                      'source': source,
                      if (incorrectPhoneClock)
                        'server_time': DateTime.now()
                            .subtract(const Duration(hours: 2))
                            .toIso8601String(),
                      'position': {
                        'latitude': 13.0188,
                        'longitude': 80.255,
                        'accuracy': 20,
                        'captured_at': DateTime.now()
                            .subtract(
                              Duration(
                                seconds: stale ? 120 : 5,
                                hours: incorrectPhoneClock ? 2 : 0,
                              ),
                            )
                            .toIso8601String(),
                      },
                    },
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await render();
      expect(find.text('Live vehicle location'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      await render(incorrectPhoneClock: true);
      expect(find.text('Live vehicle location'), findsOneWidget);
      expect(find.text('Last GPS update · just now'), findsOneWidget);
      await render(stale: true);
      expect(find.text('Last known location'), findsOneWidget);
      expect(find.textContaining('may no longer be current'), findsOneWidget);
      await render(lost: true);
      expect(find.text('Location connection lost'), findsOneWidget);
      await render(source: 'sample');
      expect(find.text('Sample GPS preview'), findsOneWidget);
      expect(find.textContaining('No real vehicle or phone'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
