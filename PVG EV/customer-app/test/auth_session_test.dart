import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pvg_customer/api.dart';
import 'package:pvg_customer/session_storage.dart';

class TestSessionStorage extends SessionStorage {
  TestSessionStorage({
    this.token,
    this.failRead = false,
    this.failWrite = false,
  });
  String? token;
  bool failRead, failWrite;
  int reads = 0, writes = 0;

  @override
  Future<String?> read() async {
    reads++;
    if (failRead) throw StateError('Secure storage unavailable');
    return token;
  }

  @override
  Future<void> write(String value) async {
    writes++;
    if (failWrite) throw StateError('Secure storage unavailable');
    token = value;
  }

  @override
  Future<void> clear() async => token = null;
}

Map<String, dynamic> session({bool includeToken = true}) => {
  if (includeToken) 'token': 'isolated-session-token',
  'user': {'id': 'owned-customer', 'name': 'Isolated test', 'role': 'customer'},
  'expires_in': 3600,
};

void main() {
  test(
    'successful OTP remains signed in when secure persistence is unavailable',
    () async {
      final storage = TestSessionStorage(failWrite: true, failRead: true);
      var restorations = 0;
      final api = PvgApi(
        sessionStorage: storage,
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/verify') {
            return http.Response(jsonEncode(session()), 200);
          }
          if (request.url.path == '/api/auth/session') restorations++;
          expect(
            request.headers['Authorization'],
            'Bearer isolated-session-token',
          );
          return http.Response('{"bookings":[]}', 200);
        }),
      );
      addTearDown(api.dispose);
      await api.verifyOtp('isolated-challenge', 'isolated-code');
      await api.restoreSession();
      await api.restoreSession();
      expect(api.signedIn, isTrue);
      expect(api.user?['id'], 'owned-customer');
      expect(await api.bookings(), isEmpty);
      expect(storage.writes, 1);
      expect(storage.reads, 0);
      expect(restorations, 0);
    },
  );

  test(
    'fresh startup validates a stored token before restoring the customer',
    () async {
      final storage = TestSessionStorage(token: 'persisted-session-token');
      var validations = 0;
      final api = PvgApi(
        sessionStorage: storage,
        client: MockClient((request) async {
          expect(request.url.path, '/api/auth/session');
          expect(
            request.headers['Authorization'],
            'Bearer persisted-session-token',
          );
          validations++;
          return http.Response(jsonEncode(session(includeToken: false)), 200);
        }),
      );
      addTearDown(api.dispose);
      expect(api.signedIn, isFalse);
      await api.restoreSession();
      await api.restoreSession();
      expect(api.signedIn, isTrue);
      expect(api.user?['id'], 'owned-customer');
      expect(validations, 1);
      expect(storage.reads, 1);
    },
  );

  test(
    'a revoked persisted token is rejected and removed on startup',
    () async {
      final storage = TestSessionStorage(token: 'revoked-session-token');
      final api = PvgApi(
        sessionStorage: storage,
        client: MockClient(
          (request) async => http.Response('{"error":"Session expired"}', 401),
        ),
      );
      addTearDown(api.dispose);
      await api.restoreSession();
      expect(api.signedIn, isFalse);
      expect(api.user, isNull);
      expect(storage.token, isNull);
    },
  );

  test(
    'temporary startup failure preserves the stored session for a validated retry',
    () async {
      final storage = TestSessionStorage(token: 'persisted-session-token');
      var calls = 0;
      final api = PvgApi(
        sessionStorage: storage,
        client: MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response('{"error":"Temporarily unavailable"}', 503);
          }
          return http.Response(jsonEncode(session(includeToken: false)), 200);
        }),
      );
      addTearDown(api.dispose);
      await api.restoreSession();
      expect(api.signedIn, isFalse);
      expect(storage.token, 'persisted-session-token');
      await api.restoreSession();
      expect(api.signedIn, isTrue);
      expect(calls, 2);
    },
  );
}
