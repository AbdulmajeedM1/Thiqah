import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});
  final TrustStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final steps = s.provider
        ? [
            s.t(
              'افتح «الطلبات» للاطلاع على الطلبات المنشورة.',
              'Open Requests to browse published requests.',
            ),
            s.t(
              'اختر طلبًا، ثم اضغط «قدّم عرضك» وحدد السعر والمدة.',
              'Open a request, choose Submit offer, and enter your price and delivery time.',
            ),
            s.t(
              'بعد اختيار العميل لعرضك، يمكنك التواصل معه والاطلاع على المرفقات.',
              'Once the customer selects your offer, you can chat and view attachments.',
            ),
            s.t(
              'بعد الدفع التجريبي، أنجز المهمة وأرسل إثبات الإنجاز.',
              'After simulated payment, complete the task and submit completion proof.',
            ),
            s.t(
              'بعد تأكيد العميل، تظهر الأرباح التجريبية في المحفظة.',
              'When the customer confirms completion, demo earnings appear in your wallet.',
            ),
          ]
        : [
            s.t(
              'اضغط «طلب جديد» أو اختر فئة الخدمة من الرئيسية.',
              'Tap New request or choose a service category on Home.',
            ),
            s.t(
              'أدخل وصف الطلب والمدينة والميزانية، وأرفق الملفات عند الحاجة.',
              'Enter the description, city and budget, and attach files if needed.',
            ),
            s.t(
              'وافق على التفويض وانشر الطلب، أو احفظه كمسودة لإكماله لاحقًا.',
              'Accept authorization and publish, or save a draft to finish later.',
            ),
            s.t(
              'من «طلباتي»، قارن العروض واختر مقدم الخدمة ثم نفّذ الدفع التجريبي.',
              'Under My requests, compare offers, select a provider and complete simulated payment.',
            ),
            s.t(
              'تابع المهمة في المحادثة، ثم راجع إثبات الإنجاز وأكد الإكمال وأضف تقييمك.',
              'Follow progress in chat, review the completion proof, then confirm and leave a review.',
            ),
          ];
    final questions = <(String, String)>[
      (
        s.t(
          'لماذا لا يظهر طلبي لمقدم الخدمة؟',
          'Why can’t a provider see my request?',
        ),
        s.t(
          'تأكد من نشر الطلب؛ المسودة خاصة بك. يجب أن يسجل مقدم الخدمة الدخول على نفس الجهاز، لأن هذه النسخة لا تزامن البيانات بين الأجهزة.',
          'Make sure the request is published; drafts are private. The provider must sign in on the same device because this version does not sync between devices.',
        ),
      ),
      (
        s.t(
          'كيف أجرّب الخدمة بين العميل ومقدم الخدمة؟',
          'How do I try both sides of the service?',
        ),
        s.t(
          'أنشئ حساب عميل وحساب مقدم خدمة على نفس الجهاز، ثم بدّل بينهما بتسجيل الخروج والدخول. لا توجد عروض أو ردود تلقائية.',
          'Create a customer account and a provider account on the same device, then switch by signing out and back in. Offers and replies are not generated automatically.',
        ),
      ),
      (
        s.t('هل الدفع والسحب حقيقيان؟', 'Are payments and withdrawals real?'),
        s.t(
          'لا. الدفع والضمان والمحفظة والسحب محاكاة تعليمية، ولا يتم تحويل أي أموال.',
          'No. Payments, escrow, wallet balances and withdrawals are educational simulations. No money is transferred.',
        ),
      ),
      (
        s.t(
          'متى أقدر أرسل رسالة أو أشوف المرفقات؟',
          'When can I chat or view attachments?',
        ),
        s.t(
          'بعد اختيار عرض، تتاح المحادثة والمرفقات للعميل صاحب الطلب ومقدم الخدمة المختار فقط.',
          'After an offer is selected, chat and attachments are available only to the request owner and the selected provider.',
        ),
      ),
      (
        s.t(
          'هل أقدر ألغي الطلب أو أفتح نزاع؟',
          'Can I cancel a request or open a dispute?',
        ),
        s.t(
          'يمكن للعميل الإلغاء قبل الدفع التجريبي. أثناء التنفيذ أو انتظار التأكيد، يستطيع الطرفان فتح نزاع مع ذكر السبب. تسوية النزاعات غير متاحة في هذه النسخة.',
          'Customers can cancel before simulated payment. During execution or while awaiting confirmation, either participant can open a dispute with a reason. Dispute resolution is not available in this version.',
        ),
      ),
      (
        s.t(
          'هل تسجيل الخروج يحذف بياناتي؟',
          'Does signing out delete my data?',
        ),
        s.t(
          'لا، تعود بياناتك عند الدخول على نفس الجهاز. تجنّب حذف التطبيق أو مسح بياناته لأن التخزين محلي.',
          'No. Your data returns when you sign in on the same device. Avoid uninstalling the app or clearing its data because storage is local.',
        ),
      ),
      (
        s.t(
          'كيف أغيّر اللغة أو أفعّل الوضع الداكن؟',
          'How do I change language or enable Dark Mode?',
        ),
        s.t(
          'افتح «حسابي» ثم غيّر اللغة أو فعّل «الوضع الداكن». يُحفظ اختيار المظهر لحسابك.',
          'Open Account to change the language or enable Dark mode. Your theme preference is saved for your account.',
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('المساعدة', 'Help'))),
      body: PageBody(
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: 48,
            color: appAccent(context, green),
          ),
          const SizedBox(height: 12),
          Text(
            s.t('كيف تستخدم الخدمة؟', 'How to use the service'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            s.t(
              'خطوات بسيطة وإجابات على أسئلتك',
              'Simple steps and answers to your questions',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: appMuted(context)),
          ),
          Heading(
            s.provider
                ? s.t('دليل مقدم الخدمة', 'Provider guide')
                : s.t('دليل العميل', 'Customer guide'),
          ),
          Panel(
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : 18,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: appPale(context),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              color: appAccent(context, green),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(steps[i])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Heading(s.t('الأسئلة الشائعة', 'Frequently asked questions')),
          Panel(
            padding: 4,
            child: Column(
              children: [
                for (var i = 0; i < questions.length; i++)
                  ExpansionTile(
                    key: PageStorageKey('faq-$i'),
                    title: Text(
                      questions[i].$1,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [Text(questions[i].$2)],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
