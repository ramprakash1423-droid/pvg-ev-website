import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pvg_customer/visit_tracking.dart';
import 'package:pvg_customer/ui.dart' show Panel;

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

class RecoverableTiles extends TileProvider {
  bool failing = true;
  int loads = 0, evictions = 0;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      RecoverableTile(
        this,
        '${coordinates.x}/${coordinates.y}/${coordinates.z}',
      );
}

class RecoverableTile extends ImageProvider<RecoverableTile> {
  const RecoverableTile(this.owner, this.coordinate);
  final RecoverableTiles owner;
  final String coordinate;
  @override
  Future<RecoverableTile> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    RecoverableTile key,
    ImageDecoderCallback decode,
  ) {
    owner.loads++;
    if (owner.failing) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('Isolated tile failure')),
      );
    }
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xffdce7dc), ui.BlendMode.src);
    final image = recorder.endRecording().toImageSync(1, 1);
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image)),
    );
  }

  @override
  Future<bool> evict({
    ImageCache? cache,
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) {
    owner.evictions++;
    return super.evict(cache: cache, configuration: configuration);
  }

  @override
  bool operator ==(Object other) =>
      other is RecoverableTile &&
      identical(other.owner, owner) &&
      other.coordinate == coordinate;
  @override
  int get hashCode => Object.hash(owner, coordinate);
}

class LateTileError extends Fake implements TileImage {}

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

  testWidgets(
    'embedded prominent waiting state stays compact without a fake map or duplicate identity',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: VisitTracking(
              prominent: true,
              embedded: true,
              showIdentity: false,
              booking: {
                'fleet_name': 'Assigned vehicle',
                'technician': {'name': 'Assigned technician'},
                'tracking': {'state': 'waiting', 'position': null},
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Panel), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.textContaining('first reliable GPS reading'), findsOneWidget);
      expect(find.textContaining('Assigned vehicle'), findsNothing);
      expect(tester.getSize(find.byType(VisitTracking)).height, lessThan(180));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'prominent tracking keeps GPS age visible and discloses verbose location metadata on request',
    (tester) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisitTracking(
                prominent: true,
                tileProvider: OfflineTiles(),
                booking: {
                  'latitude': 13.01,
                  'longitude': 80.22,
                  'tracking': {
                    'state': 'live',
                    'source': 'device',
                    'server_time': now,
                    'position': {
                      'latitude': 13.02,
                      'longitude': 80.23,
                      'accuracy': 8,
                      'captured_at': now,
                    },
                  },
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Last GPS update · just now'), findsOneWidget);
      expect(
        tester
            .widget<ExpansionTile>(find.byType(ExpansionTile))
            .expansionAnimationStyle
            ?.duration,
        Duration.zero,
      );
      expect(find.textContaining('GPS accuracy'), findsNothing);
      expect(find.textContaining('straight-line distance'), findsNothing);
      expect(tester.getSize(find.byType(FlutterMap)).height, 300);
      await tester.ensureVisible(find.text('Location details'));
      await tester.tap(find.text('Location details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GPS accuracy ±8 m'), findsOneWidget);
      expect(find.textContaining('not a road ETA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'retry map evicts failed image cache and reloads tiles without changing actual location',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = RecoverableTiles();
      final booking = <String, dynamic>{
        'id': 'owned-visit',
        'latitude': 13.01,
        'longitude': 80.22,
        'tracking': {'state': 'not_sharing', 'position': null},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VisitTracking(
                prominent: true,
                tileProvider: provider,
                booking: booking,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some map tiles could not load'),
        findsOneWidget,
      );
      expect(find.text('Retry map'), findsOneWidget);
      final attempts = provider.loads;
      expect(attempts, greaterThan(0));
      final oldError = tester
          .widget<TileLayer>(find.byType(TileLayer))
          .errorTileCallback!;
      await tester.tap(find.text('Retry map'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some map tiles could not load'),
        findsOneWidget,
      );
      expect(provider.loads, greaterThan(attempts));
      final failedRetryAttempts = provider.loads;
      provider.failing = false;
      await tester.tap(find.text('Retry map'));
      await tester.pumpAndSettle();
      expect(provider.evictions, greaterThan(0));
      expect(provider.loads, greaterThan(failedRetryAttempts));
      expect(
        find.textContaining('Some map tiles could not load'),
        findsNothing,
      );
      expect(find.text('Retry map'), findsNothing);
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point
            .latitude,
        13.01,
      );
      expect(booking['tracking']['position'], isNull);
      oldError(
        LateTileError(),
        StateError('Late callback from previous attempt'),
        StackTrace.current,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some map tiles could not load'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
