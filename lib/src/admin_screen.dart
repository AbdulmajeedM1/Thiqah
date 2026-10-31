import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_screens.dart';
import 'store.dart';
import 'widgets.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.store, required this.auth});
  final TrustStore store;
  final AuthController auth;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();
  List<Account> _users = [];
  bool _loading = true;
  String? _error;
  String? _changingId;
  int _loadGeneration = 0;
  TrustStore get s => widget.store;
  AuthController get auth => widget.auth;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await auth.listUsers();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _users = users);
    } on AuthFailure catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error.code);
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = 'local_data_unavailable');
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeStatus(Account account) async {
    if (_changingId != null ||
        account.role == 'admin' ||
        account.id == auth.user?.id) {
      return;
    }
    final suspend = account.status == 'active';
    final confirmed = await confirmAction(
      context,
      s,
      suspend
          ? s.t('إيقاف الحساب', 'Suspend account')
          : s.t('تفعيل الحساب', 'Activate account'),
      suspend
          ? s.t(
              'هل تريد إيقاف حساب ${account.fullName}؟ سيُمنع المستخدم من الدخول وتُلغى جلساته الحالية.',
              'Suspend ${account.fullName}? The user will be unable to sign in and existing sessions will be revoked.',
            )
          : s.t(
              'هل تريد السماح لـ ${account.fullName} بتسجيل الدخول من جديد؟',
              'Allow ${account.fullName} to sign in again?',
            ),
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _changingId = account.id;
      _error = null;
    });
    try {
      await auth.setUserStatus(account.id, suspend ? 'suspended' : 'active');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? s.t('تم إيقاف الحساب', 'Account suspended')
                : s.t('تم تفعيل الحساب', 'Account activated'),
          ),
        ),
      );
      await _load();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'local_data_unavailable');
    } finally {
      if (mounted) setState(() => _changingId = null);
    }
  }

  Future<void> _logout() async {
    if (auth.busy) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }

  String _roleLabel(Account user) => switch (user.role) {
    'admin' => s.t('مدير النظام', 'Administrator'),
    'provider' => s.t('مقدم خدمة', 'Provider'),
    _ => s.t('عميل', 'Customer'),
  };

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool leftToRight = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
              SelectableText(
                value.isEmpty ? '—' : value,
                textDirection: leftToRight ? TextDirection.ltr : null,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _showDetails(Account user) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.t('بيانات الحساب', 'Account details')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow(
                Icons.person_outline,
                s.t('الاسم الكامل', 'Full name'),
                user.fullName,
              ),
              _detailRow(
                Icons.alternate_email,
                s.t('اسم المستخدم', 'Username'),
                user.username,
                leftToRight: true,
              ),
              _detailRow(
                Icons.mail_outline,
                s.t('البريد الإلكتروني', 'Email'),
                user.email,
                leftToRight: true,
              ),
              _detailRow(
                Icons.phone_outlined,
                s.t('رقم الجوال', 'Mobile number'),
                user.phone,
                leftToRight: true,
              ),
              _detailRow(
                Icons.location_on_outlined,
                s.t('المدينة', 'City'),
                user.city,
              ),
              _detailRow(
                Icons.badge_outlined,
                s.t('نوع الحساب', 'Account type'),
                _roleLabel(user),
              ),
              _detailRow(
                Icons.manage_accounts_outlined,
                s.t('الحالة', 'Status'),
                user.status == 'active'
                    ? s.t('نشط', 'Active')
                    : s.t('موقوف', 'Suspended'),
              ),
              _detailRow(
                Icons.calendar_today_outlined,
                s.t('تاريخ التسجيل', 'Joined'),
                _formatDate(user.createdAt),
                leftToRight: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.t('إغلاق', 'Close')),
        ),
      ],
    ),
  );

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _userCard(Account user) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: pale,
                child: Icon(
                  user.role == 'admin'
                      ? Icons.admin_panel_settings_outlined
                      : Icons.person_outline,
                  color: green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '@${user.username}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(_roleLabel(user), green),
              _badge(
                user.status == 'active'
                    ? s.t('نشط', 'Active')
                    : s.t('موقوف', 'Suspended'),
                user.status == 'active' ? green : const Color(0xFFB42318),
              ),
              if (user.id == auth.user?.id) _badge(s.t('حسابك', 'You'), muted),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user.email.isEmpty
                ? s.t('لم يُضف بريد إلكتروني', 'No email added')
                : user.email,
            textDirection: TextDirection.ltr,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                key: ValueKey('userDetails-${user.id}'),
                onPressed: () => _showDetails(user),
                icon: const Icon(Icons.info_outline, size: 18),
                label: Text(s.t('عرض البيانات', 'View details')),
              ),
              if (user.role != 'admin' && user.id != auth.user?.id)
                OutlinedButton.icon(
                  key: ValueKey('userStatus-${user.id}'),
                  onPressed: _changingId != null || _loading
                      ? null
                      : () => _changeStatus(user),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: user.status == 'active'
                        ? const Color(0xFFB42318)
                        : green,
                  ),
                  icon: _changingId == user.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          user.status == 'active'
                              ? Icons.block
                              : Icons.check_circle_outline,
                          size: 18,
                        ),
                  label: Text(
                    user.status == 'active'
                        ? s.t('إيقاف الحساب', 'Suspend')
                        : s.t('تفعيل الحساب', 'Activate'),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _stat(String label, int count, IconData icon, double width) =>
      SizedBox(
        width: width,
        child: Panel(
          padding: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: green, size: 22),
              const SizedBox(height: 12),
              Text('$count', style: Theme.of(context).textTheme.headlineMedium),
              Text(label, style: const TextStyle(color: muted, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([auth, s]),
    builder: (context, _) {
      // The app also gates this route; never retain user records after logout.
      if (auth.user?.role != 'admin') return const SizedBox.shrink();
      final query = _search.text.trim().toLowerCase();
      final visible = _users
          .where(
            (user) => [
              user.fullName,
              user.username,
              user.email,
              user.phone,
              user.city,
            ].any((value) => value.toLowerCase().contains(query)),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(s.t('إدارة ثقة', 'Trust admin')),
          actions: [
            IconButton(
              tooltip: s.t('تحديث الحسابات', 'Refresh accounts'),
              onPressed: _loading || _changingId != null ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              tooltip: s.t('خيارات الحساب', 'Account options'),
              onSelected: (value) {
                if (value == 'password') {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ChangePasswordScreen(store: s, auth: auth),
                    ),
                  );
                } else if (value == 'language') {
                  s.english = !s.english;
                  s.save();
                } else if (value == 'logout') {
                  _logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'password',
                  child: Text(s.t('تغيير كلمة المرور', 'Change password')),
                ),
                PopupMenuItem(
                  value: 'language',
                  child: Text(s.english ? 'العربية' : 'English'),
                ),
                PopupMenuItem(
                  value: 'logout',
                  enabled: !auth.busy,
                  child: Text(s.t('تسجيل الخروج', 'Sign out')),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: PageBody(
              children: [
                const SizedBox(height: 10),
                Panel(
                  color: pale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: green,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.t(
                          'أهلًا، ${auth.user!.fullName}',
                          'Welcome, ${auth.user!.fullName}',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.t(
                          'تابع الحسابات المسجّلة وفعّل أو أوقف وصول المستخدمين.',
                          'Review registered accounts and manage user access.',
                        ),
                        style: const TextStyle(color: ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (!_loading || _users.isNotEmpty) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 20) / 3;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _stat(
                            s.t('الحسابات', 'Accounts'),
                            _users.length,
                            Icons.people_outline,
                            width,
                          ),
                          _stat(
                            s.t('مقدمو الخدمة', 'Providers'),
                            _users
                                .where((user) => user.role == 'provider')
                                .length,
                            Icons.work_outline,
                            width,
                          ),
                          _stat(
                            s.t('الموقوفون', 'Suspended'),
                            _users
                                .where((user) => user.status != 'active')
                                .length,
                            Icons.block,
                            width,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                ],
                Text(
                  s.t('الحسابات المسجّلة', 'Registered accounts'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('adminUserSearch'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: s.t(
                      'ابحث بالاسم أو البريد أو الجوال',
                      'Search by name, email or phone',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: s.t('مسح البحث', 'Clear search'),
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  AuthErrorNotice(authErrorText(_error!, s.english)),
                  TextButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(s.t('إعادة المحاولة', 'Try again')),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_loading && _error == null && visible.isEmpty)
                  EmptyView(
                    s.t('لا توجد حسابات مطابقة', 'No matching accounts'),
                    s.t(
                      'جرّب البحث باسم آخر أو حدّث القائمة.',
                      'Try another search or refresh the list.',
                    ),
                    icon: Icons.person_search_outlined,
                  ),
                ...visible.map(_userCard),
              ],
            ),
          ),
        ),
      );
    },
  );
}
