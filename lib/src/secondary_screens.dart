import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key, required this.store, this.embedded = false});
  final TrustStore store;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final s = store;
    final items = s.visible.where(s.canChat).toList();
    final body = PageBody(
      children: [
        Heading(s.t('المحادثات', 'Conversations')),
        Text(
          s.t(
            'رسائل بين العميل ومقدم الخدمة المختار على هذا الجهاز.',
            'Messages between the customer and selected provider on this device.',
          ),
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: 4,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: const CircleAvatar(
                  backgroundColor: pale,
                  child: Icon(Icons.chat_bubble_outline, color: green),
                ),
                title: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  r.messages.isEmpty
                      ? s.t('ابدأ المحادثة', 'Start a conversation')
                      : r.messages.last.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(store: s, request: r),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          EmptyView(
            s.t('لا توجد محادثات بعد', 'No conversations yet'),
            s.t(
              'تظهر المحادثة بعد اختيار العميل لعرض مقدم الخدمة.',
              'Conversations appear after the customer selects a provider offer.',
            ),
            icon: Icons.chat_bubble_outline,
          ),
      ],
    );
    return embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(s.t('الرسائل', 'Messages'))),
            body: body,
          );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store, required this.request});
  final TrustStore store;
  final Request request;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    if (text.text.trim().isEmpty) return;
    widget.store.send(widget.request, text.text);
    text.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store;
      if (!s.canChat(widget.request)) {
        return Scaffold(
          appBar: AppBar(title: Text(s.t('المحادثة', 'Conversation'))),
          body: Center(
            child: Text(
              s.t(
                'المحادثة غير متاحة لهذا الحساب.',
                'Conversation unavailable for this account.',
              ),
            ),
          ),
        );
      }
      final messages = widget.request.messages.reversed.toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.request.title,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: pale,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      s.t(
                        'محادثة تجريبية محلية • بدّل الحساب للرد من الطرف الآخر',
                        'Local demo chat • Switch roles to reply as the other party',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: green),
                    ),
                  ),
                  Expanded(
                    child: messages.isEmpty
                        ? EmptyView(
                            s.t('ابدأ المحادثة', 'Start the conversation'),
                            s.t(
                              'ناقش تفاصيل المعاملة هنا.',
                              'Discuss the request here.',
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            controller: scroll,
                            padding: const EdgeInsets.all(18),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = messages[i];
                              final mine = m.provider == s.provider;
                              final date = DateTime.tryParse(m.at)?.toLocal();
                              return Align(
                                alignment: mine
                                    ? AlignmentDirectional.centerEnd
                                    : AlignmentDirectional.centerStart,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width
                                            .clamp(0, 720) *
                                        .74,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: mine ? green : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.text,
                                        style: TextStyle(
                                          color: mine ? Colors.white : ink,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        date == null
                                            ? ''
                                            : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: mine ? Colors.white70 : muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: text,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              hintText: s.t('اكتب رسالتك…', 'Write a message…'),
                              counterText: '',
                            ),
                            onSubmitted: (_) => send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: s.t('إرسال', 'Send'),
                          onPressed: send,
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.store});
  final TrustStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(store.t('الإشعارات', 'Notifications')),
        actions: [
          TextButton(
            onPressed: () {
              store.readCount = store.notifications.length;
              store.save();
            },
            child: Text(store.t('قراءة الكل', 'Read all')),
          ),
        ],
      ),
      body: PageBody(
        children: [
          if (store.notifications.isEmpty)
            EmptyView(
              store.t('أنت على اطلاع بكل جديد', 'You are all caught up'),
              store.t(
                'ستظهر تحديثات طلباتك هنا.',
                'Request updates will appear here.',
              ),
              icon: Icons.notifications_none,
            ),
          ...store.notifications.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                color: e.key < store.notifications.length - store.readCount
                    ? pale
                    : Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications_outlined, color: green),
                    const SizedBox(width: 14),
                    Expanded(child: Text(e.value)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.store});
  final TrustStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final s = store;
      final transactions = s.visible
          .where(
            (r) =>
                r.selected != null &&
                s.canReadPrivateDetails(r) &&
                ![Stage.payment, Stage.cancelled].contains(r.stage),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            s.t(
              s.provider ? 'الأرباح والمحفظة' : 'المدفوعات',
              s.provider ? 'Earnings & wallet' : 'Payments',
            ),
          ),
        ),
        body: PageBody(
          children: [
            Panel(
              color: ink,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(
                      s.provider
                          ? 'رصيد تجريبي متاح'
                          : 'مبالغ تجريبية في الضمان',
                      s.provider
                          ? 'Available demo balance'
                          : 'Demo balance held in escrow',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.money(s.provider ? s.available : s.held),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFC9A227),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.t(
                'هذه محاكاة فقط. لا يوجد ربط ببوابة دفع أو حساب بنكي.',
                'Simulation only. No payment gateway or bank account is connected.',
              ),
              style: const TextStyle(color: muted),
            ),
            if (s.provider) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: s.available > 0
                    ? () async {
                        final amount = s.available;
                        if (await confirmAction(
                          context,
                          s,
                          s.t('سحب تجريبي', 'Demo withdrawal'),
                          s.t(
                            'محاكاة سحب ${s.money(amount)}؟ لن يحدث تحويل بنكي.',
                            'Simulate withdrawing ${s.money(amount)}? No bank transfer will occur.',
                          ),
                        )) {
                          s.withdraw(amount);
                        }
                      }
                    : null,
                child: Text(s.t('محاكاة سحب الرصيد', 'Simulate withdrawal')),
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'إجمالي السحب التجريبي: ${s.money(s.withdrawn)}',
                  'Total demo withdrawals: ${s.money(s.withdrawn)}',
                ),
              ),
            ],
            Heading(s.t('سجل المعاملات', 'Transaction history')),
            if (transactions.isEmpty)
              EmptyView(
                s.t('لا توجد معاملات', 'No transactions'),
                s.t(
                  'تظهر هنا الطلبات بعد الدفع التجريبي.',
                  'Orders appear here after simulated payment.',
                ),
                icon: Icons.receipt_long_outlined,
              ),
            ...transactions.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: StatusBadge(s, r.stage)),
                          const SizedBox(width: 8),
                          Text(
                            s.money(r.total),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      if (s.provider && r.stage == Stage.completed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            s.t(
                              'صافي مقدم الخدمة: ${s.money((r.selected!.amount * .9).round())}',
                              'Provider net: ${s.money((r.selected!.amount * .9).round())}',
                            ),
                            style: const TextStyle(color: green, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, required this.store});
  final TrustStore store;
  @override
  Widget build(BuildContext context) {
    final docs = store.visible
        .where(store.canReadPrivateDetails)
        .expand((r) => r.documents)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(store.t('المستندات', 'Documents'))),
      body: PageBody(
        children: [
          Text(
            store.t(
              'مرفقات محفوظة على هذا الجهاز. أضف المستندات أثناء إنشاء الطلب.',
              'Attachments stored on this device. Add documents when creating a request.',
            ),
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (docs.isEmpty)
            EmptyView(
              store.t('لا توجد مستندات', 'No documents yet'),
              store.t(
                'ستجد مرفقات طلباتك هنا.',
                'Your request attachments will appear here.',
              ),
              icon: Icons.folder_open,
            ),
          ...docs.map((d) => DocumentTile(store: store, document: d)),
        ],
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.store, required this.document});
  final TrustStore store;
  final Document document;
  Future<void> export(BuildContext context) async {
    try {
      final bytes = await File(document.path).readAsBytes();
      final destination = await FilePicker.platform.saveFile(
        dialogTitle: store.t('حفظ نسخة', 'Save a copy'),
        fileName: document.name,
        bytes: bytes,
      );
      if (destination != null && !(Platform.isAndroid || Platform.isIOS)) {
        await File(destination).writeAsBytes(bytes);
      }
      if (context.mounted && destination != null) {
        toast(
          context,
          store.t('تم حفظ نسخة من المستند', 'Document copy saved'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        toast(
          context,
          store.t(
            'تعذر قراءة أو حفظ المستند',
            'Could not read or save the document',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Panel(
      padding: 6,
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: green),
        title: Text(
          document.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${(document.size / 1024).ceil()} KB'),
        trailing: IconButton(
          tooltip: store.t('حفظ نسخة', 'Save a copy'),
          onPressed: () => export(context),
          icon: const Icon(Icons.download_outlined),
        ),
      ),
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store});
  final TrustStore store;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController name, city;
  final key = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.name);
    city = TextEditingController(text: widget.store.city);
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('الملف الشخصي', 'Profile'))),
      body: Form(
        key: key,
        child: PageBody(
          children: [
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              maxLength: 60,
              decoration: InputDecoration(labelText: s.t('الاسم', 'Name')),
              validator: (v) => (v?.trim().length ?? 0) < 2
                  ? s.t('أدخل الاسم', 'Enter your name')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: city,
              maxLength: 60,
              decoration: InputDecoration(labelText: s.t('المدينة', 'City')),
              validator: (v) => (v?.trim().length ?? 0) < 2
                  ? s.t('أدخل المدينة', 'Enter a city')
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                if (s.provider) {
                  s.providerName = name.text.trim();
                } else {
                  s.customerName = name.text.trim();
                }
                s.city = city.text.trim();
                s.save();
                Navigator.pop(context);
              },
              child: Text(s.t('حفظ التغييرات', 'Save changes')),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({
    super.key,
    required this.store,
    required this.title,
    required this.body,
  });
  final TrustStore store;
  final String title, body;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: PageBody(
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.verified_user_outlined, size: 64, color: green),
        const SizedBox(height: 28),
        Panel(child: Text(body)),
      ],
    ),
  );
}
