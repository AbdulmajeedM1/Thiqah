import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';
import 'number_input.dart';
import 'widgets.dart';
import 'secondary_screens.dart';

Future<List<Document>> pickDocuments() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'xlsx', 'zip'],
  );
  if (result == null) return [];
  if (result.files.length > 10 ||
      result.files.any((f) => f.size > 25 * 1024 * 1024)) {
    throw const FormatException(
      '10 files maximum; 25 MB per file. / الحد ١٠ ملفات، و٢٥ ميجابايت لكل ملف.',
    );
  }
  final directory = await getApplicationSupportDirectory();
  final docs = Directory('${directory.path}/documents');
  await docs.create(recursive: true);
  final copied = <Document>[];
  for (final f in result.files) {
    if (f.path == null) {
      throw const FormatException('Cannot read this file. / تعذر قراءة الملف.');
    }
    final extension = f.extension ?? 'bin';
    final dest =
        '${docs.path}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await File(f.path!).copy(dest);
    copied.add(Document(f.name, dest, f.size));
  }
  return copied;
}

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({
    super.key,
    required this.store,
    this.initialCategory = 0,
    this.draft,
  });
  final TrustStore store;
  final int initialCategory;
  final Request? draft;
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description, budget, city;
  late int category;
  bool urgent = false, consent = false, busy = false;
  final List<Document> docs = [];
  TrustStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    final r = widget.draft;
    title = TextEditingController(text: r?.title);
    description = TextEditingController(text: r?.description);
    budget = TextEditingController(
      text: r == null ? '' : (r.budget / 100).toStringAsFixed(2),
    );
    city = TextEditingController(text: r?.city ?? s.city);
    category = r?.category ?? widget.initialCategory;
    urgent = r?.urgent ?? false;
    consent = r?.consent ?? false;
    if (r != null) docs.addAll(r.documents);
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    budget.dispose();
    city.dispose();
    super.dispose();
  }

  String? requiredText(String? v, int min) => (v?.trim().length ?? 0) < min
      ? s.t('أدخل $min أحرف على الأقل', 'Enter at least $min characters')
      : null;
  Future<void> attach() async {
    setState(() => busy = true);
    try {
      final files = await pickDocuments();
      if (!mounted) return;
      if (docs.length + files.length > 10) {
        toast(context, s.t('الحد الأقصى ١٠ ملفات', 'Maximum 10 files'));
      } else {
        setState(() => docs.addAll(files));
      }
    } catch (e) {
      if (mounted) {
        toast(
          context,
          s.t(
            'تعذر إرفاق الملفات. الحد ٢٥ ميجابايت لكل ملف و١٠ ملفات.',
            'Could not attach files. Limit: 25 MB each, 10 files.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void submit(bool draft) {
    if (!form.currentState!.validate()) return;
    if (!draft && !consent) {
      toast(
        context,
        s.t(
          'وافق على التفويض قبل نشر الطلب',
          'Authorization is required to publish',
        ),
      );
      return;
    }
    final r =
        widget.draft ??
        Request(
          id: s.id(),
          title: '',
          description: '',
          category: category,
          city: '',
          budget: 0,
        );
    r.title = title.text.trim();
    r.description = description.text.trim();
    r.category = category;
    r.city = city.text.trim();
    r.budget = (parseLocalizedDecimal(budget.text)! * 100).round();
    r.urgent = urgent;
    r.consent = consent;
    r.documents
      ..clear()
      ..addAll(docs);
    if (widget.draft != null) {
      if (draft) {
        s.save();
      } else {
        s.publish(r);
      }
    } else {
      r.stage = draft ? Stage.draft : Stage.open;
      s.create(r);
    }
    Navigator.pop(context);
    toast(
      context,
      s.t(
        draft ? 'تم حفظ المسودة' : 'تم نشر طلبك بنجاح',
        draft ? 'Draft saved' : 'Request published',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        s.t(
          widget.draft == null ? 'طلب خدمة جديد' : 'تعديل المسودة',
          widget.draft == null ? 'New service request' : 'Edit draft',
        ),
      ),
    ),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          Text(
            s.t('وش المعاملة اللي تحتاجها؟', 'What do you need done?'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            s.t(
              'اكتب التفاصيل عشان توصلك عروض مناسبة.',
              'Add details to receive relevant offers.',
            ),
            style: const TextStyle(color: muted),
          ),
          Heading(s.t('١. تفاصيل المعاملة', '1. Request details')),
          DropdownButtonFormField<int>(
            initialValue: category,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: s.t('نوع الخدمة', 'Service category'),
            ),
            items: List.generate(
              6,
              (i) => DropdownMenuItem(value: i, child: Text(s.category(i))),
            ),
            onChanged: (v) => setState(() => category = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: title,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: s.t('عنوان الطلب', 'Request title'),
              hintText: s.t(
                'مثال: تجديد السجل التجاري',
                'Example: Renew business registration',
              ),
            ),
            validator: (v) => requiredText(v, 5),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: description,
            minLines: 4,
            maxLines: 7,
            maxLength: 3000,
            decoration: InputDecoration(
              labelText: s.t('وصف المعاملة', 'Description'),
              alignLabelWithHint: true,
            ),
            validator: (v) => requiredText(v, 15),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: city,
            decoration: InputDecoration(
              labelText: s.t('المدينة', 'City'),
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            validator: (v) => requiredText(v, 2),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: s.t('الميزانية المتوقعة', 'Expected budget'),
              suffixText: s.t('ر.س', 'SAR'),
            ),
            validator: (v) {
              final amount = parseLocalizedDecimal(v);
              return amount == null ||
                      !amount.isFinite ||
                      amount < 1 ||
                      amount > 100000
                  ? s.t(
                      'أدخل مبلغًا من ١ إلى ١٠٠٬٠٠٠',
                      'Enter an amount from 1 to 100,000',
                    )
                  : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('طلب عاجل', 'Urgent request')),
            subtitle: Text(
              s.t(
                'أحتاج إنجاز المعاملة بأقرب وقت',
                'I need this completed as soon as possible',
              ),
            ),
            value: urgent,
            onChanged: (v) => setState(() => urgent = v),
          ),
          Heading(s.t('٢. المستندات', '2. Documents')),
          Panel(
            color: pale,
            child: Column(
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 36, color: green),
                const SizedBox(height: 8),
                Text(s.t('أرفق ملفات تجريبية فقط', 'Attach sample files only')),
                Text(
                  s.t(
                    'حفظ محلي • ٢٥ ميجابايت للملف • حتى ١٠ ملفات',
                    'Local storage • 25 MB each • Up to 10 files',
                  ),
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy ? null : attach,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    s.t(
                      busy ? 'جارٍ الإرفاق…' : 'اختيار الملفات',
                      busy ? 'Attaching…' : 'Choose files',
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...docs.map(
            (d) => ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: green,
              ),
              title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${(d.size / 1024).ceil()} KB'),
              trailing: IconButton(
                tooltip: s.t('إزالة المرفق', 'Remove attachment'),
                onPressed: () => setState(() => docs.remove(d)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          Heading(s.t('٣. التفويض', '3. Authorization')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consent,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => consent = v!),
            title: Text(
              s.t(
                'أوافق على تفويض مقدم الخدمة المختار بمتابعة هذه المعاملة ضمن نطاق الطلب.',
                'I authorize the selected provider to handle this request within its stated scope.',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: busy ? null : () => submit(false),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(s.t('نشر الطلب', 'Publish request')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : () => submit(true),
            child: Text(s.t('حفظ كمسودة', 'Save as draft')),
          ),
        ],
      ),
    ),
  );
}

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.store, required this.request});
  final TrustStore store;
  final Request request;
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  TrustStore get s => widget.store;
  Request get r => widget.request;
  void open(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  Future<void> guarded(String title, String body, VoidCallback action) async {
    if (await confirmAction(context, s, title, body)) {
      action();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(s.t('تفاصيل الطلب', 'Request details')),
        actions: [
          if (s.canChat(r))
            IconButton(
              tooltip: s.t('المحادثة', 'Conversation'),
              onPressed: () => open(ChatScreen(store: s, request: r)),
              icon: const Icon(Icons.chat_bubble_outline),
            ),
        ],
      ),
      body: PageBody(
        children: [
          Row(
            children: [
              StatusBadge(s, r.stage),
              const Spacer(),
              Text(
                '#${r.id.length > 8 ? r.id.substring(r.id.length - 6) : r.id}',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(r.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${s.category(r.category)}  •  ${r.city}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 22),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('تفاصيل المعاملة', 'Description'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(r.description),
                const Divider(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Text(s.t('الميزانية المتوقعة', 'Expected budget')),
                    ),
                    Text(
                      s.money(r.budget),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: green,
                      ),
                    ),
                  ],
                ),
                if (r.urgent)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      s.t('طلب عاجل', 'Urgent request'),
                      style: const TextStyle(color: Color(0xFF946200)),
                    ),
                  ),
              ],
            ),
          ),
          if (r.stage == Stage.draft && !s.provider) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(NewRequestScreen(store: s, draft: r)),
              child: Text(
                s.t('تعديل المسودة ونشرها', 'Edit and publish draft'),
              ),
            ),
          ],
          if (r.stage == Stage.open) ...[
            Heading(
              s.t(
                'العروض المقدمة (${r.offers.length})',
                'Offers (${r.offers.length})',
              ),
            ),
            if (r.offers.isEmpty)
              EmptyView(
                s.t('بانتظار أول عرض', 'Waiting for the first offer'),
                s.t(
                  'يمكنك التبديل لمقدم الخدمة وإرسال عرض تجريبي.',
                  'Switch to the provider account to submit a demo offer.',
                ),
              ),
            ...r.offers
                .where((o) => !s.provider || s.ownsOffer(o))
                .map(offerCard),
            if (s.provider && !r.offers.any(s.ownsOffer))
              FilledButton.icon(
                onPressed: () => open(OfferScreen(store: s, request: r)),
                icon: const Icon(Icons.add),
                label: Text(s.t('قدّم عرضك', 'Submit an offer')),
              ),
            if (s.provider && r.offers.any(s.ownsOffer))
              TextButton(
                onPressed: () => guarded(
                  s.t('سحب العرض', 'Withdraw offer'),
                  s.t(
                    'يمكنك تقديم عرض جديد طالما الطلب مفتوح.',
                    'You can submit another offer while the request is open.',
                  ),
                  () => s.withdrawOffer(r),
                ),
                child: Text(s.t('سحب عرضي', 'Withdraw my offer')),
              ),
          ],
          if (r.selected != null) ...[
            Heading(s.t('مقدم الخدمة المختار', 'Selected provider')),
            offerCard(r.selected!, selectable: false),
            Panel(
              color: pale,
              child: Column(
                children: [
                  row(
                    s.t('قيمة الخدمة', 'Service price'),
                    s.money(r.selected!.amount),
                  ),
                  const SizedBox(height: 8),
                  row(
                    s.t('رسوم تجريبية ٥٪', 'Demo fee 5%'),
                    s.money(r.total - r.selected!.amount),
                  ),
                  const Divider(height: 28),
                  row(s.t('الإجمالي', 'Total'), s.money(r.total)),
                  const SizedBox(height: 10),
                  Text(
                    s.t(
                      'جميع المبالغ محاكاة ولا يتم خصم أموال.',
                      'All amounts are simulated. No money is charged.',
                    ),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ],
          if (!s.provider && r.stage == Stage.payment) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => guarded(
                s.t('محاكاة الدفع', 'Simulate payment'),
                s.t(
                  'سيبدأ الطلب بمحاكاة حجز ${s.money(r.total)} في الضمان. لن يتم الخصم من أي حساب.',
                  'Simulate holding ${s.money(r.total)} in escrow and start the order. No account will be charged.',
                ),
                () => s.pay(r),
              ),
              icon: const Icon(Icons.lock_outline),
              label: Text(
                s.t('دفع تجريبي وبدء الطلب', 'Simulate payment & start'),
              ),
            ),
          ],
          if (s.provider &&
              s.ownsOffer(r.selected) &&
              r.stage == Stage.active) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => open(
                ActionFormScreen(
                  store: s,
                  title: s.t('إثبات الإنجاز', 'Completion proof'),
                  label: s.t(
                    'مرجع الإنجاز وما تم تنفيذه',
                    'Completion reference and work performed',
                  ),
                  minLength: 8,
                  onSubmit: (v) => s.complete(r, v),
                ),
              ),
              icon: const Icon(Icons.task_alt),
              label: Text(s.t('تسليم المعاملة', 'Submit completed work')),
            ),
          ],
          if (r.proof.isNotEmpty && s.canReadPrivateDetails(r)) ...[
            Heading(s.t('إثبات الإنجاز', 'Completion proof')),
            Panel(child: SelectableText(r.proof)),
          ],
          if (!s.provider && r.stage == Stage.confirmation) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => guarded(
                s.t('تأكيد استلام المعاملة', 'Approve completed work'),
                s.t(
                  'بعد التأكيد سيُحرر الرصيد التجريبي لمقدم الخدمة.',
                  'The demo balance will be released to the provider.',
                ),
                () => s.confirm(r),
              ),
              child: Text(s.t('تأكيد الإنجاز', 'Approve completion')),
            ),
          ],
          if (r.stage == Stage.disputed && s.canReadPrivateDetails(r)) ...[
            Heading(s.t('تفاصيل النزاع', 'Dispute details')),
            Panel(
              color: const Color(0xFFFFF0EC),
              child: Text(
                '${r.dispute}\n\n${s.t('الرصيد التجريبي مجمّد. حل النزاعات يحتاج لوحة الإدارة المتصلة بالخادم.', 'Demo funds are frozen. Resolution requires the server-backed administration panel.')}',
              ),
            ),
          ],
          if (s.canReadPrivateDetails(r) &&
              [Stage.active, Stage.confirmation].contains(r.stage)) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => open(
                ActionFormScreen(
                  store: s,
                  title: s.t('فتح نزاع', 'Open dispute'),
                  label: s.t('اشرح سبب النزاع', 'Describe the issue'),
                  minLength: 10,
                  onSubmit: (v) => s.dispute(r, v),
                ),
              ),
              child: Text(
                s.t(
                  'الإبلاغ عن مشكلة / فتح نزاع',
                  'Report a problem / open dispute',
                ),
                style: const TextStyle(color: Color(0xFFC0392B)),
              ),
            ),
          ],
          if (r.stage == Stage.completed) ...[
            Heading(s.t('تقييم التجربة', 'Review the experience')),
            if (r.rating > 0)
              Panel(
                child: Column(
                  children: [
                    Text(
                      '★' * r.rating,
                      style: const TextStyle(
                        color: Color(0xFFB8860B),
                        fontSize: 28,
                      ),
                    ),
                    Text(r.review),
                  ],
                ),
              )
            else if (!s.provider)
              FilledButton(
                onPressed: () => open(ReviewScreen(store: s, request: r)),
                child: Text(s.t('قيّم مقدم الخدمة', 'Rate the provider')),
              ),
          ],
          if (r.documents.isNotEmpty && s.canReadPrivateDetails(r)) ...[
            Heading(s.t('المرفقات المحلية', 'Local attachments')),
            ...r.documents.map((d) => DocumentTile(store: s, document: d)),
          ],
          Heading(s.t('مسار الطلب', 'Request timeline')),
          ...r.timeline.asMap().entries.map(
            (e) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: pale,
                child: Text(
                  '${e.key + 1}',
                  style: const TextStyle(color: green, fontSize: 12),
                ),
              ),
              title: Text(e.value, style: const TextStyle(fontSize: 13)),
            ),
          ),
          if (!s.provider &&
              [Stage.draft, Stage.open, Stage.payment].contains(r.stage))
            TextButton(
              onPressed: () => guarded(
                s.t('إلغاء الطلب', 'Cancel request'),
                s.t(
                  'سيتم إغلاق الطلب ولن يقبل عروضًا جديدة.',
                  'This request will be closed to new offers.',
                ),
                () => s.cancel(r),
              ),
              child: Text(
                s.t('إلغاء الطلب', 'Cancel request'),
                style: const TextStyle(color: Color(0xFFC0392B)),
              ),
            ),
        ],
      ),
    ),
  );
  Widget row(String a, String b) => Row(
    children: [
      Expanded(child: Text(a)),
      Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
  Widget offerCard(Offer o, {bool selectable = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: pale,
                child: Icon(Icons.person_outline, color: green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  o.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                s.money(o.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.t(
              'المدة المتوقعة: ${o.days} أيام',
              'Estimated delivery: ${o.days} days',
            ),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (o.notes.isNotEmpty) Text(o.notes),
          if (selectable && !s.provider && r.stage == Stage.open) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => guarded(
                  s.t('اختيار العرض', 'Select offer'),
                  s.t(
                    'اختيار ${o.name} بقيمة ${s.money(o.amount)} قبل الرسوم؟',
                    'Select ${o.name} for ${s.money(o.amount)} before fees?',
                  ),
                  () => s.select(r, o),
                ),
                child: Text(s.t('اختيار العرض', 'Select offer')),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class OfferScreen extends StatefulWidget {
  const OfferScreen({super.key, required this.store, required this.request});
  final TrustStore store;
  final Request request;
  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  final key = GlobalKey<FormState>();
  final price = TextEditingController(),
      days = TextEditingController(),
      notes = TextEditingController();
  @override
  void dispose() {
    price.dispose();
    days.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('تقديم عرض', 'Submit an offer'))),
      body: Form(
        key: key,
        child: PageBody(
          children: [
            Heading(widget.request.title),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: s.t('سعر الخدمة بالريال', 'Service price in SAR'),
              ),
              validator: (v) {
                final n = parseLocalizedDecimal(v);
                return n == null || !n.isFinite || n < 1 || n > 100000
                    ? s.t('أدخل مبلغًا من ١ إلى ١٠٠٬٠٠٠', 'Enter 1 to 100,000')
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: s.t('مدة الإنجاز بالأيام', 'Delivery time in days'),
              ),
              validator: (v) {
                final n = parseLocalizedInteger(v);
                return n == null || n < 1 || n > 90
                    ? s.t('من يوم إلى ٩٠ يومًا', 'Enter 1 to 90 days')
                    : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: notes,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: s.t(
                  'ماذا يشمل عرضك؟',
                  'What does your offer include?',
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                s.offer(
                  widget.request,
                  (parseLocalizedDecimal(price.text)! * 100).round(),
                  parseLocalizedInteger(days.text)!,
                  notes.text.trim(),
                );
                Navigator.pop(context);
              },
              child: Text(s.t('إرسال العرض', 'Send offer')),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionFormScreen extends StatefulWidget {
  const ActionFormScreen({
    super.key,
    required this.store,
    required this.title,
    required this.label,
    required this.minLength,
    required this.onSubmit,
  });
  final TrustStore store;
  final String title, label;
  final int minLength;
  final ValueChanged<String> onSubmit;
  @override
  State<ActionFormScreen> createState() => _ActionFormScreenState();
}

class _ActionFormScreenState extends State<ActionFormScreen> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Form(
      key: form,
      child: PageBody(
        children: [
          const SizedBox(height: 20),
          TextFormField(
            controller: controller,
            minLines: 5,
            maxLines: 9,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: widget.label,
              alignLabelWithHint: true,
            ),
            validator: (v) => (v?.trim().length ?? 0) < widget.minLength
                ? widget.store.t(
                    'اكتب تفاصيل أكثر',
                    'Please provide more detail',
                  )
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              widget.onSubmit(controller.text.trim());
              Navigator.pop(context);
            },
            child: Text(widget.store.t('إرسال', 'Submit')),
          ),
        ],
      ),
    ),
  );
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store, required this.request});
  final TrustStore store;
  final Request request;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int stars = 5;
  final text = TextEditingController();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.store.t('تقييم الخدمة', 'Rate the service')),
    ),
    body: PageBody(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.task_alt, color: green, size: 60),
        Heading(widget.store.t('كيف كانت تجربتك؟', 'How was your experience?')),
        Wrap(
          alignment: WrapAlignment.center,
          children: List.generate(
            5,
            (i) => IconButton(
              tooltip: '${i + 1}/5',
              onPressed: () => setState(() => stars = i + 1),
              icon: Icon(
                i < stars ? Icons.star : Icons.star_outline,
                color: const Color(0xFFB8860B),
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: text,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: widget.store.t(
              'شاركنا رأيك (اختياري)',
              'Your feedback (optional)',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            widget.store.review(widget.request, stars, text.text.trim());
            Navigator.pop(context);
          },
          child: Text(widget.store.t('إرسال التقييم', 'Submit review')),
        ),
      ],
    ),
  );
}
