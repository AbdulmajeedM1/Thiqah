import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';
import 'request_screens.dart';
import 'secondary_screens.dart';
import 'auth.dart';
import 'auth_screens.dart';
import 'help_screen.dart';
import 'motion.dart';

class TrustShell extends StatefulWidget {
  const TrustShell({super.key, required this.store, this.auth});
  final TrustStore store;
  final AuthController? auth;
  @override
  State<TrustShell> createState() => _TrustShellState();
}

class _TrustShellState extends State<TrustShell> {
  int tab = 0;
  bool homeEntranceShown = false;
  String query = '';
  Stage? filter;
  int? category;
  TrustStore get s => widget.store;
  void open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
  void detail(Request r) => open(RequestScreen(store: s, request: r));
  @override
  Widget build(BuildContext context) {
    if (!s.entered) return WelcomeScreen(store: s);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_rounded,
              color: appAccent(context, green),
              size: 30,
            ),
            const SizedBox(width: 8),
            Text(
              s.t('ثقة', 'TRUST'),
              style: TextStyle(
                color: appInk(context),
                fontWeight: FontWeight.w900,
                fontSize: 27,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.t('الإشعارات', 'Notifications'),
            onPressed: () => open(NotificationsScreen(store: s)),
            icon: Badge(
              isLabelVisible: s.notifications.length > s.readCount,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFFAF1DB),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                s.t(
                  'نسخة تجريبية • بيانات محلية • لا توجد دفعات حقيقية',
                  'Demo • Local data • No real payments',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF755300)),
              ),
            ),
            if (s.storageError != null)
              MaterialBanner(
                content: Text(s.storageError!),
                actions: [
                  TextButton(
                    onPressed: s.save,
                    child: Text(s.t('إعادة المحاولة', 'Retry')),
                  ),
                ],
              ),
            Expanded(
              child: TabTransition(
                index: tab,
                child: switch (tab) {
                  0 => home(),
                  1 => requests(),
                  2 => MessagesScreen(store: s, embedded: true),
                  _ => account(),
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: tab == 0
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: tab == 0
          ? SizedBox(
              width: MediaQuery.sizeOf(context).width - 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton.small(
                    key: const ValueKey('home-help'),
                    heroTag: 'home-help',
                    tooltip: s.t('المساعدة والأسئلة الشائعة', 'Help and FAQs'),
                    onPressed: () => open(HelpScreen(store: s)),
                    child: const Icon(Icons.help_outline_rounded),
                  ),
                  if (!s.provider)
                    FloatingActionButton.extended(
                      heroTag: 'new-request',
                      onPressed: () => open(NewRequestScreen(store: s)),
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.add),
                      label: Text(s.t('طلب جديد', 'New request')),
                    ),
                ],
              ),
            )
          : tab == 1 && !s.provider
          ? FloatingActionButton.extended(
              onPressed: () => open(NewRequestScreen(store: s)),
              backgroundColor: green,
              foregroundColor: Colors.white,
              icon: Icon(Icons.add),
              label: Text(s.t('طلب جديد', 'New request')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) {
          if (i == tab) return;
          setState(() {
            if (tab == 0) homeEntranceShown = true;
            tab = i;
          });
        },
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        indicatorColor: appPale(context),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: appAccent(context, green),
            ),
            label: s.t('الرئيسية', 'Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(
              Icons.description,
              color: appAccent(context, green),
            ),
            label: s.t(
              s.provider ? 'الطلبات' : 'طلباتي',
              s.provider ? 'Requests' : 'My requests',
            ),
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(
              Icons.chat_bubble,
              color: appAccent(context, green),
            ),
            label: s.t('الرسائل', 'Messages'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person, color: appAccent(context, green)),
            label: s.t('حسابي', 'Account'),
          ),
        ],
      ),
    );
  }

  Widget home() {
    final active = s.visible
        .where((r) => [Stage.active, Stage.confirmation].contains(r.stage))
        .length;
    return PageBody(
      animate: !homeEntranceShown,
      children: [
        const SizedBox(height: 12),
        Text(
          s.t('أهلًا ${s.name} 👋', 'Hello, ${s.name} 👋'),
          style: TextStyle(color: appMuted(context)),
        ),
        const SizedBox(height: 6),
        Text(
          s.t(
            s.provider ? 'فرص جديدة، وإنجاز أكبر.' : 'معاملاتك أسهل مع ثقة.',
            s.provider
                ? 'New opportunities await.'
                : 'Your paperwork, simplified.',
          ),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ink, green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFC9A227)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.t('راحة بالك تبدأ هنا', 'Peace of mind starts here'),
                      style: TextStyle(color: Color(0xFFBCE5D5), fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                s.t(
                  s.provider ? 'خبرتك تصنع الفرق' : 'خلّ معاملاتك علينا',
                  s.provider
                      ? 'Put your expertise to work'
                      : 'Leave the paperwork to us',
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  s.provider
                      ? 'تصفح الطلبات وقدّم عرضك وتابع أعمالك من مكان واحد.'
                      : 'اختر خدمتك، قارن العروض، وتابع كل خطوة من جوالك.',
                  s.provider
                      ? 'Find requests, submit offers and manage your jobs in one place.'
                      : 'Choose a service, compare offers and track every step.',
                ),
                style: TextStyle(color: Color(0xFFDAEDE5)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ink,
                ),
                onPressed: () {
                  if (s.provider) {
                    setState(() => tab = 1);
                  } else {
                    open(NewRequestScreen(store: s));
                  }
                },
                icon: Icon(s.provider ? Icons.search : Icons.add),
                label: Text(
                  s.t(
                    s.provider ? 'استكشف الطلبات' : 'ابدأ طلبك الآن',
                    s.provider ? 'Explore requests' : 'Create your request',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: metric(
                '$active',
                s.t('قيد التنفيذ', 'Active jobs'),
                Icons.timelapse_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: metric(
                s.money(s.held),
                s.t('ضمان تجريبي', 'Demo escrow'),
                Icons.lock_outline,
              ),
            ),
          ],
        ),
        Heading(s.t('كيف نقدر نخدمك؟', 'What can we help with?')),
        LayoutBuilder(
          builder: (context, c) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.maxWidth > 520 ? 3 : 2,
              mainAxisExtent: 116,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, i) => Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  if (s.provider) {
                    setState(() {
                      category = i;
                      tab = 1;
                    });
                  } else {
                    open(NewRequestScreen(store: s, initialCategory: i));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        categoryIcons[i],
                        size: 29,
                        color: appAccent(context, green),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.category(i),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Heading(
          s.t(
            s.provider ? 'طلبات تناسبك' : 'آخر طلباتك',
            s.provider ? 'Available opportunities' : 'Recent requests',
          ),
          action: s.t('عرض الكل', 'View all'),
          onTap: () => setState(() => tab = 1),
        ),
        ...s.visible
            .take(3)
            .map((r) => RequestTile(s, r, onTap: () => detail(r))),
        if (s.visible.isEmpty)
          EmptyView(
            s.t('ابدأ أول طلب', 'Create your first request'),
            s.t(
              'كل معاملاتك في مكان واحد.',
              'All your paperwork in one place.',
            ),
          ),
        const SizedBox(height: 76),
      ],
    );
  }

  Widget metric(String value, String label, IconData icon) => Panel(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: appAccent(context, green), size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: appInk(context),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: appMuted(context))),
      ],
    ),
  );

  Widget requests() {
    final items = s.visible
        .where(
          (r) =>
              (filter == null || r.stage == filter) &&
              (category == null || r.category == category) &&
              '${r.title} ${r.description} ${r.city}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return PageBody(
      children: [
        Heading(
          s.t(
            s.provider ? 'سوق الطلبات' : 'طلباتي',
            s.provider ? 'Request marketplace' : 'My requests',
          ),
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
            hintText: s.t(
              'ابحث بالعنوان أو المدينة',
              'Search by title or city',
            ),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(s.t('الكل', 'All')),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
              ),
              ...Stage.values.map(
                (st) => Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(s.status(st)),
                    selected: filter == st,
                    onSelected: (_) => setState(() => filter = st),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (category != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InputChip(
              label: Text(s.category(category!)),
              onDeleted: () => setState(() => category = null),
            ),
          ),
        const SizedBox(height: 18),
        ...items.map((r) => RequestTile(s, r, onTap: () => detail(r))),
        if (items.isEmpty)
          EmptyView(
            s.t('لا توجد طلبات', 'No requests found'),
            s.t(
              'جرّب تغيير البحث أو الفلاتر.',
              'Try a different search or filter.',
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget account() => PageBody(
    children: [
      Heading(s.t('حسابي', 'My account')),
      Panel(
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: appPale(context),
              child: Text(
                s.name.characters.first,
                style: TextStyle(
                  fontSize: 26,
                  color: appAccent(context, green),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    s.t(
                      s.provider ? 'حساب مقدم خدمة' : 'حساب عميل',
                      s.provider ? 'Provider account' : 'Customer account',
                    ),
                    style: TextStyle(color: appMuted(context), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Panel(
        padding: 4,
        child: Column(
          children: [
            setting(Icons.person_outline, s.t('الملف الشخصي', 'Profile'), () {
              final user = widget.auth?.user;
              if (user == null) {
                open(ProfileScreen(store: s));
              } else {
                open(
                  InfoScreen(
                    store: s,
                    title: s.t('بيانات الحساب', 'Account details'),
                    body:
                        '${user.fullName}\n@${user.username}\n${user.email}\n${user.phone}\n${user.city}',
                  ),
                );
              }
            }),
            setting(
              Icons.account_balance_wallet_outlined,
              s.t(
                s.provider ? 'الأرباح والمحفظة' : 'المدفوعات والضمان',
                s.provider ? 'Earnings & wallet' : 'Payments & escrow',
              ),
              () => open(WalletScreen(store: s)),
            ),
            setting(
              Icons.folder_outlined,
              s.t('مستنداتي', 'My documents'),
              () => open(DocumentsScreen(store: s)),
            ),
            setting(
              Icons.verified_user_outlined,
              s.t('توثيق الهوية', 'Identity verification'),
              () => open(
                InfoScreen(
                  store: s,
                  title: s.t('توثيق الهوية', 'Identity verification'),
                  body: s.t(
                    'التوثيق عبر نفاذ ويقين غير مفعّل في النسخة المحلية. تفعيل حسابات موثقة يتطلب ربط الخادم بمزود الهوية. الحساب الحالي تجريبي ولا يمثل هوية موثقة.',
                    'Nafath and Yakeen are not connected in this local build. Verified accounts require a server-side identity integration. This demo account is not identity verified.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Panel(
        padding: 4,
        child: Column(
          children: [
            SwitchListTile(
              title: Text(s.t('English / الإنجليزية', 'العربية / Arabic')),
              secondary: Icon(Icons.language),
              value: s.english,
              onChanged: (v) {
                s.english = v;
                s.save();
              },
            ),
            SwitchListTile(
              key: const ValueKey('dark-mode-switch'),
              title: Text(s.t('الوضع الداكن', 'Dark mode')),
              secondary: Icon(Icons.dark_mode_outlined),
              value: s.darkMode,
              onChanged: (value) {
                s.darkMode = value;
                s.save();
              },
            ),
            SwitchListTile(
              title: Text(
                s.t('الإشعارات داخل التطبيق', 'In-app notifications'),
              ),
              secondary: Icon(Icons.notifications_outlined),
              value: s.notificationsEnabled,
              onChanged: (v) {
                s.notificationsEnabled = v;
                s.save();
              },
            ),
            if (widget.auth == null)
              setting(
                Icons.swap_horiz_rounded,
                s.t(
                  s.provider ? 'تجربة حساب العميل' : 'تجربة حساب مقدم الخدمة',
                  s.provider
                      ? 'Switch to demo customer'
                      : 'Switch to demo provider',
                ),
                () {
                  s.provider = !s.provider;
                  setState(() {
                    tab = 0;
                    filter = null;
                    category = null;
                    query = '';
                  });
                  s.save();
                },
              ),
            if (widget.auth != null)
              setting(
                Icons.password_rounded,
                s.t('تغيير كلمة المرور', 'Change password'),
                () => open(ChangePasswordScreen(store: s, auth: widget.auth!)),
              ),
            setting(
              Icons.info_outline,
              s.t('عن ثقة والخصوصية', 'About & privacy'),
              () => open(
                InfoScreen(
                  store: s,
                  title: s.t('عن ثقة', 'About Thiqah'),
                  body: s.t(
                    'هذه نسخة مشروع جامعي تعمل دون إنترنت. تظهر الطلبات المنشورة لمقدمي الخدمة المسجلين على هذا الجهاز. المسودات خاصة بصاحبها، والمحادثات والمرفقات متاحة للعميل ومقدم الخدمة المختار. لا توجد مزامنة بين أجهزة مختلفة. يستطيع مدير المشروع إدارة الحسابات المحلية. الدفع وسحب الأرباح محاكاة، ولا يوجد توثيق هوية أو إشعارات خارجية. حذف بيانات التطبيق قد يحذف الحسابات والطلبات. الرسوم التجريبية: ٥٪ على العميل و١٠٪ عمولة مقدم الخدمة.',
                    'This university project works offline. Published requests are visible to providers registered on this device. Drafts belong to their customer; conversations and attachments are available to the customer and selected provider. There is no synchronization between devices. The administrator manages local accounts. Payments and withdrawals are simulated. Identity and external notifications are not connected. Clearing app data may delete accounts and requests. Demo fees: 5% customer fee and 10% provider commission.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: () {
          if (widget.auth != null) {
            widget.auth!.logout();
          } else {
            s.entered = false;
            s.save();
          }
        },
        icon: Icon(Icons.logout),
        label: Text(s.t('تسجيل الخروج', 'Sign out')),
      ),
      const SizedBox(height: 8),
      Text(
        'THIQAH  /  1.0.0',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: appMuted(context),
          fontSize: 11,
          letterSpacing: 3,
        ),
      ),
    ],
  );

  Widget setting(IconData icon, String title, VoidCallback tap) => ListTile(
    leading: Icon(icon, color: appAccent(context, green)),
    title: Text(title, style: TextStyle(fontSize: 14)),
    trailing: Icon(Icons.chevron_right, size: 20),
    onTap: tap,
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.store});
  final TrustStore store;
  @override
  Widget build(BuildContext context) {
    final s = store;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () {
                  s.english = !s.english;
                  s.save();
                },
                child: Text(s.english ? 'العربية' : 'English'),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              s.t('ثقة', 'TRUST'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                color: appInk(context),
              ),
            ),
            Text(
              'YOUR TRUST. OUR COMMITMENT.',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 10,
                color: appMuted(context),
              ),
            ),
            const SizedBox(height: 34),
            Text(
              s.t(
                'معاملاتك تنجز.\nوأنت مرتاح.',
                'Paperwork handled.\nPeace of mind delivered.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              s.t(
                'مكان واحد يوصلك بمقدمي الخدمات، ويخليك تتابع معاملتك خطوة بخطوة.',
                'One place to find service providers and follow your request from start to finish.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: appMuted(context)),
            ),
            const SizedBox(height: 32),
            Panel(
              color: const Color(0xFFFAF8F4),
              child: Text(
                s.t(
                  'تجربة محلية تفاعلية: جرّب الطلبات والعروض والمحادثات دون إنشاء حساب حقيقي أو دفع أموال.',
                  'Interactive local demo: explore requests, offers and conversations without creating a real account or paying money.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                s.entered = true;
                s.provider = false;
                s.save();
              },
              child: Text(s.t('ابدأ كعميل', 'Continue as customer')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () {
                s.entered = true;
                s.provider = true;
                s.save();
              },
              child: Text(s.t('أنا مقدم خدمة', 'Continue as provider')),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
