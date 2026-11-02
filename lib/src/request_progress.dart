import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';

class RequestProgress extends StatelessWidget {
  const RequestProgress({
    super.key,
    required this.store,
    required this.request,
  });
  final TrustStore store;
  final Request request;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final stage = request.stage;
    final paused = stage == Stage.disputed;
    final closed = stage == Stage.cancelled || stage == Stage.refunded;
    final current = switch (stage) {
      Stage.draft => -1,
      Stage.open => 0,
      Stage.payment => 1,
      Stage.active => 2,
      Stage.confirmation => 3,
      Stage.completed => 4,
      Stage.disputed => request.proof.isEmpty ? 2 : 3,
      _ => -1,
    };
    final labels = [
      s.t('نشر الطلب', 'Request published'),
      s.t('اختيار مقدم الخدمة', 'Provider selected'),
      s.t('قيد التنفيذ', 'Work in progress'),
      s.t('مراجعة الإنجاز', 'Review completed work'),
      s.t('اكتمل الطلب', 'Request completed'),
    ];
    final hint = switch (stage) {
      Stage.draft => s.t(
        'أكمل بيانات المسودة وانشرها لاستقبال العروض.',
        'Finish your draft and publish it to receive offers.',
      ),
      Stage.open => s.t(
        'الطلب منشور وبانتظار اختيار عرض مناسب.',
        'The request is published and awaiting offer selection.',
      ),
      Stage.payment => s.t(
        'تم اختيار العرض. الخطوة التالية هي الدفع التجريبي.',
        'An offer is selected. Simulated payment is next.',
      ),
      Stage.active => s.t(
        'بدأ التنفيذ. يمكن للطرفين متابعة التفاصيل في المحادثة.',
        'Work has started. Both participants can follow up in chat.',
      ),
      Stage.confirmation => s.t(
        'تم التسليم. بانتظار مراجعة العميل وتأكيد الإنجاز.',
        'Work was submitted. Awaiting the customer’s review and approval.',
      ),
      Stage.completed => s.t(
        'تم تأكيد الإنجاز. شكرًا لاستخدامك ثقة!',
        'Completion confirmed. Thank you for using Thiqah!',
      ),
      Stage.disputed => s.t(
        'المتابعة متوقفة بسبب نزاع، والرصيد التجريبي مجمّد.',
        'Progress is paused by a dispute; demo funds are frozen.',
      ),
      Stage.cancelled => s.t(
        'أُلغي الطلب. يمكنك إنشاء طلب جديد من الرئيسية.',
        'This request was cancelled. You can create a new request on Home.',
      ),
      Stage.refunded => s.t(
        'أُغلق الطلب بحالة مسترد.',
        'This request is closed with refunded status.',
      ),
    };
    final accent = paused || closed
        ? Theme.of(context).colorScheme.error
        : appAccent(context, green);
    return Semantics(
      label: s.t('تتبّع الطلب', 'Request progress'),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  paused
                      ? Icons.pause_circle_outline
                      : closed
                      ? Icons.info_outline
                      : Icons.route_rounded,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('رحلة طلبك', 'Your request journey'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hint,
              style: TextStyle(color: appMuted(context), fontSize: 13),
            ),
            if (!closed) ...[
              const SizedBox(height: 20),
              for (var i = 0; i < labels.length; i++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= current
                                ? accent
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                          ),
                          child: Icon(
                            i < current || stage == Stage.completed
                                ? Icons.check_rounded
                                : i == current && paused
                                ? Icons.pause_rounded
                                : i == current
                                ? Icons.radio_button_checked
                                : Icons.circle_outlined,
                            size: 17,
                            color: i <= current
                                ? Theme.of(context).colorScheme.surface
                                : appMuted(context),
                          ),
                        ),
                        if (i < labels.length - 1)
                          Container(
                            width: 2,
                            height: 20,
                            color: i < current
                                ? accent
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontWeight: i == current
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: i <= current
                                ? Theme.of(context).colorScheme.onSurface
                                : appMuted(context),
                          ),
                        ),
                      ),
                    ),
                    if (i == current && stage != Stage.completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          paused ? s.t('متوقف', 'Paused') : s.t('الآن', 'Now'),
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
