import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum Stage {
  draft,
  open,
  payment,
  active,
  confirmation,
  completed,
  disputed,
  refunded,
  cancelled,
}

const categoryAr = [
  'الجوازات والإقامة',
  'السجل التجاري',
  'المرور والمركبات',
  'البلديات',
  'العمل والتأمينات',
  'خدمات أخرى',
];
const categoryEn = [
  'Passports & residency',
  'Business registration',
  'Traffic & vehicles',
  'Municipal services',
  'Labor & insurance',
  'Other services',
];

class Offer {
  Offer({
    required this.id,
    required this.name,
    required this.amount,
    required this.days,
    this.notes = '',
    this.mine = false,
    this.providerId,
  });
  final String id, name, notes;
  final int amount, days;
  final bool mine;
  final String? providerId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'days': days,
    'notes': notes,
    'mine': mine,
    'providerId': providerId,
  };
  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
    id: j['id'],
    name: j['name'],
    amount: j['amount'],
    days: j['days'],
    notes: j['notes'],
    mine: j['mine'],
    providerId: j['providerId'],
  );
}

class Document {
  Document(this.name, this.path, this.size);
  final String name, path;
  final int size;
  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'size': size};
  factory Document.fromJson(Map<String, dynamic> j) =>
      Document(j['name'], j['path'], j['size']);
}

class Message {
  Message(this.text, this.provider, this.at);
  final String text, at;
  final bool provider;
  Map<String, dynamic> toJson() => {
    'text': text,
    'provider': provider,
    'at': at,
  };
  factory Message.fromJson(Map<String, dynamic> j) =>
      Message(j['text'], j['provider'], j['at']);
}

class Request {
  Request({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.city,
    required this.budget,
    this.urgent = false,
    this.stage = Stage.open,
    this.mine = true,
    this.consent = false,
    this.customerId,
  });
  final String id;
  String? customerId;
  String title, description, city;
  int category, budget;
  bool urgent, mine, consent;
  Stage stage;
  final List<Offer> offers = [];
  final List<Document> documents = [];
  final List<Message> messages = [];
  final List<String> timeline = [];
  String? selectedId;
  String proof = '', dispute = '', review = '';
  int rating = 0;
  Offer? get selected => offers.where((o) => o.id == selectedId).firstOrNull;
  int get total =>
      (selected?.amount ?? 0) + ((selected?.amount ?? 0) * .05).round();
  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'title': title,
    'description': description,
    'category': category,
    'city': city,
    'budget': budget,
    'urgent': urgent,
    'stage': stage.name,
    'mine': mine,
    'consent': consent,
    'selectedId': selectedId,
    'proof': proof,
    'dispute': dispute,
    'review': review,
    'rating': rating,
    'offers': offers.map((o) => o.toJson()).toList(),
    'documents': documents.map((d) => d.toJson()).toList(),
    'messages': messages.map((m) => m.toJson()).toList(),
    'timeline': timeline,
  };
  factory Request.fromJson(Map<String, dynamic> j) {
    final r = Request(
      id: j['id'],
      title: j['title'],
      description: j['description'],
      category: j['category'],
      city: j['city'],
      budget: j['budget'],
      urgent: j['urgent'],
      stage: Stage.values.byName(j['stage']),
      mine: j['mine'],
      consent: j['consent'],
      customerId: j['customerId'],
    );
    r.selectedId = j['selectedId'];
    r.proof = j['proof'];
    r.dispute = j['dispute'];
    r.review = j['review'];
    r.rating = j['rating'];
    r.offers.addAll(
      (j['offers'] as List).map(
        (o) => Offer.fromJson(Map<String, dynamic>.from(o)),
      ),
    );
    r.documents.addAll(
      (j['documents'] as List).map(
        (d) => Document.fromJson(Map<String, dynamic>.from(d)),
      ),
    );
    r.messages.addAll(
      (j['messages'] as List).map(
        (m) => Message.fromJson(Map<String, dynamic>.from(m)),
      ),
    );
    r.timeline.addAll(List<String>.from(j['timeline']));
    return r;
  }
}

/// Local sandbox repository. No identity verification or real money is performed.
/// Domain transitions live here so widgets cannot bypass lifecycle constraints.
class TrustStore extends ChangeNotifier {
  TrustStore({this.memoryOnly = false, this.storagePath});
  final bool memoryOnly;
  final String? storagePath;
  bool english = false,
      provider = false,
      entered = false,
      notificationsEnabled = true;
  String customerName = 'عبدالله',
      providerName = 'أحمد العتيبي',
      city = 'الرياض';
  String? storageError;
  final List<Request> requests = [];
  final List<String> notifications = [];
  int readCount = 0, withdrawn = 0;
  File? _file;
  String? _activeAccountId;
  final Map<String, dynamic> _profiles = {};
  final Set<String> _importedAccounts = {};
  String? _memoryMarketplace;
  Future<void> _writes = Future.value();
  String t(String ar, String en) => english ? en : ar;
  String get name => provider ? providerName : customerName;
  bool owns(Request r) =>
      _activeAccountId == null ? r.mine : r.customerId == _activeAccountId;
  bool ownsOffer(Offer? offer) =>
      offer != null &&
      (_activeAccountId == null
          ? offer.mine
          : offer.providerId == _activeAccountId);
  bool canView(Request r) => provider
      ? r.stage != Stage.draft &&
            (r.stage == Stage.open || r.offers.any(ownsOffer))
      : owns(r);
  bool canReadPrivateDetails(Request r) =>
      provider ? ownsOffer(r.selected) : owns(r);
  bool canChat(Request r) => _activeAccountId == null
      ? r.offers.isNotEmpty && (provider ? r.offers.any(ownsOffer) : owns(r))
      : r.selected != null && canReadPrivateDetails(r);
  String category(int index) => (english ? categoryEn : categoryAr)[index];
  String money(int minor) =>
      '${(minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2)} ${t('ر.س', 'SAR')}';
  String status(Stage s) => t(
    [
      'مسودة',
      'بانتظار العروض',
      'بانتظار الدفع',
      'قيد التنفيذ',
      'بانتظار تأكيدك',
      'مكتمل',
      'نزاع مفتوح',
      'مسترد',
      'ملغي',
    ][s.index],
    [
      'Draft',
      'Awaiting offers',
      'Awaiting payment',
      'In progress',
      'Awaiting approval',
      'Completed',
      'Disputed',
      'Refunded',
      'Cancelled',
    ][s.index],
  );
  String id() => DateTime.now().microsecondsSinceEpoch.toString();
  int get available =>
      requests
          .where((r) => r.stage == Stage.completed && ownsOffer(r.selected))
          .fold(0, (n, r) => n + (r.selected!.amount * .9).round()) -
      withdrawn;
  int get held => requests
      .where(
        (r) =>
            [
              Stage.active,
              Stage.confirmation,
              Stage.disputed,
            ].contains(r.stage) &&
            canReadPrivateDetails(r),
      )
      .fold(0, (n, r) => n + r.total);
  List<Request> get visible => requests.where(canView).toList();

  Future<void> load({bool seedIfMissing = true}) async {
    if (memoryOnly) {
      if (seedIfMissing) seed();
      return;
    }
    try {
      final path =
          storagePath ??
          '${(await getApplicationSupportDirectory()).path}/thiqah_sandbox_v1.json';
      _file = File(path);
      if (await _file!.exists()) {
        final j =
            jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        final restored = (j['requests'] as List)
            .map((r) => Request.fromJson(Map<String, dynamic>.from(r)))
            .toList();
        english = j['english'];
        provider = j['provider'];
        entered = j['entered'];
        customerName = j['customerName'];
        providerName = j['providerName'];
        city = j['city'];
        notificationsEnabled = j['notificationsEnabled'];
        withdrawn = j['withdrawn'];
        readCount = j['readCount'];
        requests.addAll(restored);
        notifications.addAll(List<String>.from(j['notifications']));
      } else {
        if (seedIfMissing) seed();
      }
    } catch (_) {
      storageError = 'تعذر قراءة البيانات المحلية. لم تتم الكتابة فوق الملف الأصلي. / Local storage could not be read.';
      _file = null;
      requests.clear();
      if (seedIfMissing) seed();
    }
  }

  /// All signed-in accounts use one local marketplace. Ownership comes from
  /// account IDs, while preferences and balances remain specific to an account.
  Future<void> activateAccount({
    required String accountId,
    required String fullName,
    required String accountCity,
    required bool isProvider,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(accountId)) {
      throw ArgumentError('Invalid account identifier');
    }
    await _writes;
    if (_activeAccountId != accountId) {
      _clearAccountData();
      _activeAccountId = accountId;
      await _loadMarketplace();
    }
    provider = isProvider;
    customerName = fullName;
    providerName = fullName;
    city = accountCity;
    entered = true;
    notifyListeners();
  }

  Future<void> clearAccount() async {
    await _writes;
    _clearAccountData();
    _activeAccountId = null;
    notifyListeners();
  }

  void _clearAccountData() {
    _file = null;
    _profiles.clear();
    _importedAccounts.clear();
    requests.clear();
    notifications.clear();
    readCount = 0;
    withdrawn = 0;
    entered = false;
    provider = false;
    storageError = null;
    notificationsEnabled = true;
    customerName = '';
    providerName = '';
    city = '';
  }

  Map<String, dynamic> _profile() => {
    'english': english,
    'notificationsEnabled': notificationsEnabled,
    'withdrawn': withdrawn,
    'readCount': readCount,
    'notifications': List<String>.from(notifications),
  };

  Map<String, dynamic> _marketplace() => {
    'version': 2,
    'requests': requests.map((r) => r.toJson()).toList(),
    'profiles': _profiles,
    'importedAccounts': _importedAccounts.toList(),
  };

  Future<void> _atomicWrite(File target, String content) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(content, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _loadMarketplace() async {
    try {
      File? target;
      String? raw = _memoryMarketplace;
      Directory? oldAccounts;
      if (!memoryOnly) {
        final root = storagePath == null
            ? (await getApplicationSupportDirectory()).path
            : File(storagePath!).parent.path;
        target = File('$root/thiqah_marketplace_v2.json');
        await target.parent.create(recursive: true);
        raw = await target.exists() ? await target.readAsString() : null;
        oldAccounts = Directory('$root/accounts');
      }
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 2) {
          throw const FormatException('Unsupported marketplace version');
        }
        requests.addAll(
          (data['requests'] as List).map(
            (r) => Request.fromJson(Map<String, dynamic>.from(r)),
          ),
        );
        if (requests.any(
              (r) => r.customerId == null || r.customerId!.isEmpty,
            ) ||
            requests.map((r) => r.id).toSet().length != requests.length) {
          throw const FormatException('Invalid request ownership');
        }
        _profiles.addAll(Map<String, dynamic>.from(data['profiles']));
        _importedAccounts.addAll(List<String>.from(data['importedAccounts']));
      }
      var migrated = false;
      if (oldAccounts != null && await oldAccounts.exists()) {
        final files = await oldAccounts.list(followLinks: false).toList();
        files.sort((a, b) => a.path.compareTo(b.path));
        for (final entry in files.whereType<File>()) {
          final filename = entry.uri.pathSegments.last;
          if (!filename.endsWith('.json')) continue;
          final owner = filename.substring(0, filename.length - 5);
          if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(owner) ||
              _importedAccounts.contains(owner)) {
            continue;
          }
          final old =
              jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
          final previousRequests = old['requests'] as List;
          // The old files are retained as a backup. Import each exactly once;
          // anonymous demo requests are never attributed to a real account.
          for (final value in previousRequests) {
            final request = Map<String, dynamic>.from(value);
            if (old['provider'] == true || request['mine'] != true) continue;
            request['customerId'] = owner;
            if (requests.any((r) => r.id == request['id'])) {
              final originalId = request['id'];
              var suffix = 0;
              do {
                request['id'] = '$owner-$originalId-${suffix++}';
              } while (requests.any((r) => r.id == request['id']));
            }
            requests.add(Request.fromJson(request));
          }
          _profiles.putIfAbsent(
            owner,
            () => {
              'english': old['english'] ?? false,
              'notificationsEnabled': old['notificationsEnabled'] ?? true,
              'withdrawn': old['withdrawn'] ?? 0,
              'readCount': old['readCount'] ?? 0,
              'notifications': old['notifications'] ?? <String>[],
            },
          );
          _importedAccounts.add(owner);
          migrated = true;
        }
      }
      final profile = _profiles[_activeAccountId] as Map<String, dynamic>?;
      if (profile != null) {
        english = profile['english'] as bool;
        notificationsEnabled = profile['notificationsEnabled'] as bool;
        withdrawn = profile['withdrawn'] as int;
        readCount = profile['readCount'] as int;
        notifications.addAll(List<String>.from(profile['notifications']));
      }
      if (raw == null || migrated) {
        final content = jsonEncode(_marketplace());
        if (target != null) await _atomicWrite(target, content);
        if (memoryOnly) _memoryMarketplace = content;
      }
      _file = target;
    } catch (_) {
      _file = null;
      requests.clear();
      _profiles.clear();
      _importedAccounts.clear();
      storageError = t(
        'تعذر قراءة سوق الطلبات المحلي. أعد فتح التطبيق للمحاولة؛ لم تُحذف البيانات الأصلية.',
        'Could not read the local marketplace. Reopen the app to retry; original data was preserved.',
      );
    }
  }

  void seed() {
    if (requests.isNotEmpty) return;
    final a = Request(
      id: '1042',
      title: 'تجديد السجل التجاري',
      description: 'أحتاج إلى تجديد السجل التجاري لمؤسستي ومراجعة المتطلبات وتسليم إيصال التجديد.',
      category: 1,
      city: 'الرياض',
      budget: 50000,
      consent: true,
    );
    a.offers.addAll([
      Offer(
        id: 'a1',
        name: 'أحمد العتيبي',
        amount: 35000,
        days: 2,
        mine: true,
        notes: 'متابعة الطلب حتى استلام السجل المحدث.',
      ),
      Offer(
        id: 'a2',
        name: 'مكتب الإنجاز',
        amount: 42000,
        days: 1,
        notes: 'خدمة سريعة مع متابعة جميع المتطلبات.',
      ),
    ]);
    a.timeline.add('تم نشر الطلب التجريبي');
    a.messages.add(
      Message(
        'مرحبًا، يسعدني مساعدتك في إنجاز معاملتك.',
        true,
        DateTime.now().toIso8601String(),
      ),
    );
    final b = Request(
      id: '1041',
      title: 'تجديد رخصة سير مركبة',
      description: 'تجديد استمارة المركبة بعد استكمال الفحص والتأمين.',
      category: 2,
      city: 'الرياض',
      budget: 25000,
      stage: Stage.active,
      consent: true,
    );
    b.offers.add(
      Offer(id: 'b1', name: 'أحمد العتيبي', amount: 20000, days: 3, mine: true),
    );
    b.selectedId = 'b1';
    b.timeline.addAll([
      'تم نشر الطلب التجريبي',
      'تم اختيار العرض',
      'محاكاة إيداع المبلغ في الضمان',
    ]);
    final c = Request(
      id: '1040',
      title: 'إصدار رخصة بلدية',
      description:
          'إصدار رخصة نشاط تجاري لمحل جديد ومراجعة المستندات المطلوبة.',
      category: 3,
      city: 'جدة',
      budget: 80000,
      mine: false,
      consent: true,
    );
    requests.addAll([a, b, c]);
    notifications.add(
      'مرحبًا بك في ثقة. هذه بيئة تجريبية محلية دون دفعات حقيقية.',
    );
  }

  Future<void> save() {
    notifyListeners();
    if (_activeAccountId != null && storageError != null && _file == null) {
      return Future.value();
    }
    if (_activeAccountId != null) {
      _profiles[_activeAccountId!] = _profile();
    }
    final content = jsonEncode(
      _activeAccountId != null
          ? _marketplace()
          : {
              'english': english,
              'provider': provider,
              'entered': entered,
              'customerName': customerName,
              'providerName': providerName,
              'city': city,
              'notificationsEnabled': notificationsEnabled,
              'withdrawn': withdrawn,
              'readCount': readCount,
              'requests': requests.map((r) => r.toJson()).toList(),
              'notifications': notifications,
            },
    );
    if (memoryOnly) {
      if (_activeAccountId != null) _memoryMarketplace = content;
      return Future.value();
    }
    if (_file == null) return Future.value();
    final targetFile = _file!;
    _writes = _writes.then((_) async {
      try {
        await _atomicWrite(targetFile, content);
        if (storageError != null) {
          storageError = null;
          notifyListeners();
        }
      } catch (_) {
        storageError = t(
          'تعذر حفظ التغييرات على الجهاز.',
          'Could not save changes on this device.',
        );
        notifyListeners();
      }
    });
    return _writes;
  }

  void _require(bool condition) {
    if (!condition || (_activeAccountId != null && storageError != null)) {
      throw StateError(
        t(
          'هذه العملية غير متاحة لحالة الطلب أو الحساب الحالي.',
          'This action is not available for the current request or role.',
        ),
      );
    }
  }

  void event(Request r, String ar, String en) {
    final text = t(ar, en);
    r.timeline.add(text);
    if (notificationsEnabled) notifications.insert(0, '${r.title}: $text');
    save();
  }

  void create(Request r) {
    _require(
      !provider &&
          (_activeAccountId == null
              ? r.mine
              : r.customerId == null || owns(r)) &&
          !requests.any((existing) => existing.id == r.id) &&
          [Stage.draft, Stage.open].contains(r.stage) &&
          r.title.trim().length >= 5 &&
          r.description.trim().length >= 15 &&
          r.budget > 0 &&
          (r.stage == Stage.draft || r.consent),
    );
    r.customerId = _activeAccountId;
    requests.insert(0, r);
    event(
      r,
      r.stage == Stage.draft ? 'حُفظت المسودة' : 'تم نشر الطلب',
      r.stage == Stage.draft ? 'Draft saved' : 'Request published',
    );
  }

  void publish(Request r) {
    _require(
      requests.contains(r) &&
          !provider &&
          owns(r) &&
          r.stage == Stage.draft &&
          r.consent,
    );
    r.stage = Stage.open;
    event(r, 'تم نشر الطلب', 'Request published');
  }

  void offer(Request r, int amount, int days, String notes) {
    _require(
      provider &&
          requests.contains(r) &&
          (_activeAccountId == null || !owns(r)) &&
          r.stage == Stage.open &&
          amount > 0 &&
          days > 0 &&
          days <= 90 &&
          !r.offers.any(ownsOffer),
    );
    r.offers.add(
      Offer(
        id: id(),
        name: providerName,
        amount: amount,
        days: days,
        notes: notes,
        mine: true,
        providerId: _activeAccountId,
      ),
    );
    event(r, 'وصل عرض جديد', 'New offer received');
  }

  void withdrawOffer(Request r) {
    _require(
      requests.contains(r) &&
          provider &&
          r.stage == Stage.open &&
          r.offers.any(ownsOffer),
    );
    r.offers.removeWhere(ownsOffer);
    event(r, 'تم سحب العرض', 'Offer withdrawn');
  }

  void select(Request r, Offer o) {
    _require(
      requests.contains(r) &&
          !provider &&
          owns(r) &&
          r.stage == Stage.open &&
          r.offers.contains(o),
    );
    r.selectedId = o.id;
    r.stage = Stage.payment;
    event(r, 'تم اختيار مقدم الخدمة', 'Provider selected');
  }

  void pay(Request r) {
    _require(
      requests.contains(r) &&
          !provider &&
          owns(r) &&
          r.stage == Stage.payment &&
          r.selected != null,
    );
    r.stage = Stage.active;
    event(r, 'محاكاة إيداع المبلغ في الضمان', 'Simulated escrow deposit');
  }

  void complete(Request r, String proof) {
    _require(
      provider &&
          requests.contains(r) &&
          ownsOffer(r.selected) &&
          r.stage == Stage.active &&
          proof.trim().length >= 8,
    );
    r.proof = proof.trim();
    r.stage = Stage.confirmation;
    event(
      r,
      'رفع مقدم الخدمة إثبات الإنجاز',
      'Provider submitted completion proof',
    );
  }

  void confirm(Request r) {
    _require(
      requests.contains(r) &&
          !provider &&
          owns(r) &&
          r.stage == Stage.confirmation,
    );
    r.stage = Stage.completed;
    event(
      r,
      'تم تأكيد الإنجاز وتحرير الرصيد التجريبي',
      'Completion approved; demo balance released',
    );
  }

  void cancel(Request r) {
    _require(
      !provider &&
          requests.contains(r) &&
          owns(r) &&
          [Stage.draft, Stage.open, Stage.payment].contains(r.stage),
    );
    r.stage = Stage.cancelled;
    event(r, 'تم إلغاء الطلب', 'Request cancelled');
  }

  void dispute(Request r, String reason) {
    _require(
      requests.contains(r) &&
          canReadPrivateDetails(r) &&
          [Stage.active, Stage.confirmation].contains(r.stage) &&
          reason.trim().length >= 10,
    );
    r.dispute = reason;
    r.stage = Stage.disputed;
    event(
      r,
      'فُتح نزاع وجُمّد الرصيد التجريبي',
      'Dispute opened; demo balance frozen',
    );
  }

  void review(Request r, int rating, String text) {
    _require(
      !provider &&
          requests.contains(r) &&
          owns(r) &&
          r.stage == Stage.completed &&
          r.rating == 0 &&
          rating >= 1 &&
          rating <= 5,
    );
    r.rating = rating;
    r.review = text;
    event(r, 'تم إضافة التقييم', 'Review added');
  }

  void send(Request r, String text) {
    _require(text.trim().isNotEmpty && requests.contains(r) && canChat(r));
    r.messages.add(
      Message(text.trim(), provider, DateTime.now().toIso8601String()),
    );
    save();
  }

  void withdraw(int amount) {
    _require(provider && amount > 0 && amount <= available);
    withdrawn += amount;
    notifications.insert(
      0,
      t(
        'تمت محاكاة سحب ${money(amount)}. لم يحدث تحويل بنكي.',
        'Simulated withdrawal of ${money(amount)}. No bank transfer occurred.',
      ),
    );
    save();
  }
}
