import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'auth.dart';
import 'remote_api.dart';
import 'store.dart';

class RemoteStore extends TrustStore {
  RemoteStore(this.api) : super(memoryOnly: true);
  final RemoteApi api;
  Timer? _timer;
  int _generation = 0, _profileVersion = 1;
  bool _mutating = false, _refreshing = false;
  @override
  bool get online => true;
  @override
  bool get mutating => _mutating;
  final Map<String, dynamic> _summaries = {};
  @override
  Map<String, dynamic> get providerSummaries => _summaries;
  @override
  String id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  @override
  Future<void> activateAccount({
    required String accountId,
    required String fullName,
    required String accountCity,
    required bool isProvider,
  }) async {
    _timer?.cancel();
    _generation++;
    await super.activateAccount(
      accountId: accountId,
      fullName: fullName,
      accountCity: accountCity,
      isProvider: isProvider,
    );
    await refresh(restorePreferences: true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_mutating && !_refreshing) {
        unawaited(refresh().catchError((Object _) {}));
      }
    });
  }

  void _apply(Map<String, dynamic> data, {bool restorePreferences = false}) {
    final previous = {for (final request in requests) request.id: request};
    final incoming = <Request>[];
    for (final json in data['requests'] as List) {
      final next = Request.fromJson(Map<String, dynamic>.from(json));
      final current = previous[next.id];
      if (current == null) {
        incoming.add(next);
        continue;
      }
      current.title = next.title;
      current.description = next.description;
      current.city = next.city;
      current.category = next.category;
      current.budget = next.budget;
      current.urgent = next.urgent;
      current.consent = next.consent;
      current.stage = next.stage;
      current.selectedId = next.selectedId;
      current.proof = next.proof;
      current.dispute = next.dispute;
      current.rating = next.rating;
      current.review = next.review;
      current.offers
        ..clear()
        ..addAll(next.offers);
      current.documents
        ..clear()
        ..addAll(next.documents);
      current.messages
        ..clear()
        ..addAll(next.messages);
      current.timeline
        ..clear()
        ..addAll(next.timeline);
      incoming.add(current);
    }
    requests
      ..clear()
      ..addAll(incoming);
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    withdrawn = profile['withdrawn'] as int? ?? 0;
    _profileVersion = profile['version'] as int? ?? 1;
    if (restorePreferences) {
      darkMode = profile['darkMode'] as bool? ?? false;
      english = profile['english'] as bool? ?? false;
      notificationsEnabled = profile['notificationsEnabled'] as bool? ?? true;
    }
    _summaries
      ..clear()
      ..addAll(
        Map<String, dynamic>.from(data['providerSummaries'] as Map? ?? {}),
      );
    notifications
      ..clear()
      ..addAll(
        requests
            .where((r) => owns(r) || r.offers.any(ownsOffer))
            .where((r) => r.timeline.isNotEmpty)
            .map((r) => '${r.title}: ${r.timeline.last}'),
      );
    storageError = null;
    notifyListeners();
  }

  Future<void> refresh({bool restorePreferences = false}) async {
    if (_refreshing) return;
    final generation = _generation;
    _refreshing = true;
    try {
      final data = await api.request('GET', '/marketplace');
      if (generation == _generation && !_mutating) {
        _apply(data, restorePreferences: restorePreferences);
      }
    } catch (_) {
      if (generation == _generation) {
        storageError = t(
          'تعذر التحديث. تحقق من الاتصال بالإنترنت.',
          'Could not refresh. Check your internet connection.',
        );
        notifyListeners();
      }
      rethrow;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _action(String path, Map<String, dynamic> body) async {
    if (_mutating) throw const AuthFailure('busy');
    _mutating = true;
    final generation = ++_generation;
    notifyListeners();
    try {
      Map<String, dynamic> data;
      try {
        data = await api.request('POST', path, body: body);
      } on AuthFailure catch (error) {
        if (error.code != 'network_error') rethrow;
        data = await api.request('POST', path, body: body);
      }
      if (generation == _generation) _apply(data);
    } finally {
      _mutating = false;
      notifyListeners();
    }
  }

  Future<void> _requestAction(
    Request r,
    String action, [
    Map<String, dynamic> values = const {},
  ]) => _action('/requests/${r.id}/actions', {
    'action': action,
    'operation': id(),
    ...values,
  });

  Future<void> _uploadDocuments(Request request) async {
    for (var i = 0; i < request.documents.length; i++) {
      final document = request.documents[i];
      if (document.path.startsWith('cloud:')) continue;
      final response = await api.upload(
        document.name,
        await super.readDocument(document),
      );
      request.documents[i] = Document.fromJson(
        Map<String, dynamic>.from(response['document']),
      );
    }
  }

  @override
  Future<void> create(Request r) async {
    await _uploadDocuments(r);
    await _requestAction(r, 'create', {'request': r.toJson()});
  }

  @override
  Future<void> editDraft(Request request) async {
    await _uploadDocuments(request);
    await _requestAction(request, 'editDraft', {'request': request.toJson()});
  }

  @override
  Future<void> publish(Request r) async {
    await _uploadDocuments(r);
    await _requestAction(r, 'publish', {'request': r.toJson()});
  }

  @override
  Future<void> offer(Request r, int amount, int days, String notes) =>
      _requestAction(r, 'offer', {
        'amount': amount,
        'days': days,
        'notes': notes,
      });
  @override
  Future<void> withdrawOffer(Request r) => _requestAction(r, 'withdrawOffer');
  @override
  Future<void> select(Request r, Offer o) =>
      _requestAction(r, 'select', {'offerId': o.id});
  @override
  Future<void> pay(Request r) => _requestAction(r, 'pay');
  @override
  Future<void> complete(Request r, String proof) =>
      _requestAction(r, 'complete', {'proof': proof});
  @override
  Future<void> confirm(Request r) => _requestAction(r, 'confirm');
  @override
  Future<void> cancel(Request r) => _requestAction(r, 'cancel');
  @override
  Future<void> dispute(Request r, String reason) =>
      _requestAction(r, 'dispute', {'reason': reason});
  @override
  Future<void> review(Request r, int rating, String text) =>
      _requestAction(r, 'review', {'rating': rating, 'text': text});
  @override
  Future<void> send(Request r, String text) =>
      _requestAction(r, 'send', {'text': text});
  @override
  Future<void> withdraw(int amount) => _action('/withdraw', {
    'amount': amount,
    'version': _profileVersion,
    'operation': id(),
  });
  @override
  Future<Uint8List> readDocument(Document document) =>
      document.path.startsWith('cloud:')
      ? api.download(document.path.substring(6))
      : super.readDocument(document);
  @override
  Future<void> save() async {
    notifyListeners();
    if (api.sessionToken == null) return;
    try {
      await api.request(
        'PUT',
        '/profile',
        body: {
          'darkMode': darkMode,
          'english': english,
          'notificationsEnabled': notificationsEnabled,
        },
      );
    } catch (_) {
      storageError = t(
        'تعذر حفظ التفضيلات. تحقق من الاتصال.',
        'Could not save preferences. Check your connection.',
      );
      notifyListeners();
    }
  }

  @override
  Future<void> clearAccount() async {
    _generation++;
    _timer?.cancel();
    api.sessionToken = null;
    _summaries.clear();
    await super.clearAccount();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
