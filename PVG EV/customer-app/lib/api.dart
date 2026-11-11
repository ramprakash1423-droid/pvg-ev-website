import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session_storage.dart';
import 'http_client.dart'
    if (dart.library.js_interop) 'http_client_web.dart'
    as transport;

class PvgApi extends ChangeNotifier {
  PvgApi({
    http.Client? client,
    String? endpoint,
    SessionStorage? sessionStorage,
  }) : _client = client ?? transport.createClient(),
       persistent = client == null || sessionStorage != null,
       storage = sessionStorage ?? const SessionStorage(),
       baseUrl =
           endpoint ??
           const String.fromEnvironment(
             'PVG_API_URL',
             defaultValue: 'http://127.0.0.1:8201',
           );
  final http.Client _client;
  final bool persistent;
  final SessionStorage storage;
  bool _restored = false, _cookieSession = false;
  bool get cookieMode => kIsWeb && persistent;
  final String baseUrl;
  String? _token;
  Map<String, dynamic>? user;
  Map<String, dynamic>? config;
  Timer? _expiry;
  final _changes = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get changes => _changes.stream;
  http.Client? _liveClient;
  int _liveGeneration = 0;
  bool _disposed = false;
  bool get signedIn => _token != null || _cookieSession;
  bool get isPreview => config?['mode'] == 'local_preview';
  Uri uri(String path) => Uri.parse('$baseUrl/api$path');

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw Exception(
        'A secure production service must be configured before release.',
      );
    }
    final headers = {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    http.Response response;
    try {
      response =
          await (data == null
                  ? _client.get(uri(path), headers: headers)
                  : _client.post(
                      uri(path),
                      headers: headers,
                      body: jsonEncode(data),
                    ))
              .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw Exception('The connection timed out. Please try again.');
    } on http.ClientException {
      throw Exception('Cannot reach PVG. Check your connection and try again.');
    }
    Map<String, dynamic> result;
    try {
      result = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('The PVG service returned an unexpected response.');
    }
    if (response.statusCode == 401 && signedIn) {
      _clearSession();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(result['error'] ?? 'Unable to complete this request.');
    }
    return result;
  }

  Future<void> loadConfig() async {
    config = await request('/config');
    if (signedIn) startLiveUpdates();
    notifyListeners();
  }

  Future<Map<String, dynamic>> sendOtp(
    String phone,
    String name, {
    bool sms = false,
  }) => request(
    '/auth/otp',
    data: {
      'phone': phone,
      'name': name,
      'delivery': sms || !isPreview ? 'sms' : 'preview',
    },
  );
  Future<void> verifyOtp(String challenge, String code) async {
    final result = await request(
      '/auth/verify',
      data: {
        'challenge_id': challenge,
        'code': code,
        if (cookieMode) 'client': 'web',
      },
    );
    _applySession(result);
    if (persistent && !kIsWeb && _token != null) {
      try {
        await storage.write(_token!);
      } catch (_) {
        /* Current sign-in remains usable. */
      }
    }
  }

  void _applySession(Map<String, dynamic> result) {
    _token = result['token'] as String? ?? _token;
    _cookieSession = cookieMode;
    user = Map<String, dynamic>.from(result['user']);
    _expiry?.cancel();
    _expiry = Timer(
      Duration(seconds: result['expires_in'] as int),
      _clearSession,
    );
    _restored = true;
    startLiveUpdates();
    notifyListeners();
  }

  Future<void> restoreSession() async {
    if (_restored || signedIn || !persistent) return;
    _restored = true;
    try {
      if (!kIsWeb) {
        _token = await storage.read();
        if (_token == null) return;
      }
      final result = await request('/auth/session');
      _applySession(result);
    } catch (_) {
      _token = null;
      _cookieSession = false;
      user = null;
      // A temporary connection error must not delete a stored valid session.
      _restored = false;
    }
  }

  void startLiveUpdates() {
    _liveGeneration++;
    _liveClient?.close();
    _liveClient = null;
    if (config?['realtime'] != true || !signedIn || _disposed) return;
    unawaited(_listen(_liveGeneration));
  }

  Future<void> _listen(int generation) async {
    while (!_disposed && signedIn && generation == _liveGeneration) {
      final client = transport.createClient();
      _liveClient = client;
      try {
        final request = http.Request('GET', uri('/events'));
        if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
        request.headers['Accept'] = 'text/event-stream';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 401) {
          _clearSession();
          return;
        }
        if (response.statusCode != 200) {
          throw Exception('Live updates unavailable');
        }
        await for (final line
            in response.stream
                .timeout(const Duration(seconds: 45))
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (_disposed || generation != _liveGeneration) return;
          if (!line.startsWith('data: ')) continue;
          final event = Map<String, dynamic>.from(
            jsonDecode(line.substring(6)),
          );
          if (event['kind'] == 'session_expired') {
            _clearSession();
            return;
          }
          _changes.add(event);
        }
      } catch (_) {
        // A disconnected feed never makes the last GPS point look live.
      } finally {
        client.close();
      }
      if (_disposed || generation != _liveGeneration || !signedIn) return;
      _changes.add({'kind': 'connection_lost'});
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> signOut() async {
    try {
      if (signedIn) await request('/auth/logout', data: {});
    } catch (_) {
      if (cookieMode) rethrow;
    }
    _clearSession();
  }

  void _clearSession() {
    _liveGeneration++;
    _liveClient?.close();
    _liveClient = null;
    _token = null;
    _cookieSession = false;
    if (persistent && !kIsWeb) unawaited(storage.clear().catchError((_) {}));
    user = null;
    _expiry?.cancel();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> vehicles() async =>
      ((await request('/evs'))['vehicles'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> updateProfile(String name) async {
    user = await request('/profile', data: {'name': name});
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> bookings() async =>
      ((await request('/bookings'))['bookings'] as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<Uint8List> receipt(String bookingId) async {
    final response = await _client
        .get(
          uri('/bookings/$bookingId/receipt'),
          headers: {if (_token != null) 'Authorization': 'Bearer $_token'},
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Receipt is not available yet.');
    }
    return response.bodyBytes;
  }

  @override
  void dispose() {
    _disposed = true;
    _liveGeneration++;
    _liveClient?.close();
    _changes.close();
    _expiry?.cancel();
    _client.close();
    super.dispose();
  }
}
