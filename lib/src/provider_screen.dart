import 'package:flutter/material.dart';

import 'store.dart';
import 'widgets.dart';

/// Only public aggregates and reviews leave the marketplace through this model.
/// Legacy offers without a provider ID are never grouped by display name.
class ProviderSummary {
  ProviderSummary(TrustStore store, Offer offer) {
    bool matches(Offer candidate) => offer.providerId == null
        ? identical(candidate, offer)
        : candidate.providerId == offer.providerId;
    for (final request in store.requests) {
      if (request.stage == Stage.draft) continue;
      if (request.offers.any(matches)) categories.add(request.category);
      if (request.stage == Stage.completed &&
          request.selected != null &&
          matches(request.selected!)) {
        completed++;
        if (request.rating >= 1 && request.rating <= 5) {
          reviews.add((request.rating, request.review));
        }
      }
    }
  }
  int completed = 0;
  final Set<int> categories = {};
  final List<(int, String)> reviews = [];
  double? get average => reviews.isEmpty
      ? null
      : reviews.fold<int>(0, (sum, r) => sum + r.$1) / reviews.length;
}

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key, required this.store, required this.offer});
  final TrustStore store;
  final Offer offer;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final s = store;
      final summary = ProviderSummary(s, offer);
      final color = appAccent(context, green);
      return Scaffold(
        appBar: AppBar(title: Text(s.t('ملف مقدم الخدمة', 'Provider profile'))),
        body: PageBody(
          children: [
            Panel(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: appPale(context),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 40,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    offer.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.t('مقدم خدمات على ثقة', 'Service provider on Thiqah'),
                    style: TextStyle(color: appMuted(context)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          context,
                          '${summary.completed}',
                          s.t('طلبات مكتملة', 'Completed jobs'),
                          Icons.task_alt,
                        ),
                      ),
                      Expanded(
                        child: _stat(
                          context,
                          summary.average?.toStringAsFixed(1) ?? '—',
                          s.t('متوسط التقييم', 'Average rating'),
                          Icons.star_outline,
                        ),
                      ),
                      Expanded(
                        child: _stat(
                          context,
                          '${summary.reviews.length}',
                          s.t('تقييمات', 'Reviews'),
                          Icons.rate_review_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              s.t(
                'إحصاءات من الطلبات الموجودة على هذا الجهاز. الملف لا يعني توثيق الهوية.',
                'Statistics reflect requests on this device. A profile does not imply identity verification.',
              ),
              style: TextStyle(fontSize: 12, color: appMuted(context)),
            ),
            Heading(s.t('فئات شارك بها', 'Categories offered')),
            Panel(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in summary.categories.toList()..sort())
                    Chip(
                      avatar: Icon(categoryIcons[category], size: 18),
                      label: Text(s.category(category)),
                    ),
                  if (summary.categories.isEmpty)
                    Text(s.t('لا توجد مشاركات بعد.', 'No categories yet.')),
                ],
              ),
            ),
            Heading(s.t('تقييمات العملاء', 'Customer reviews')),
            if (summary.reviews.isEmpty)
              Panel(
                child: EmptyView(
                  s.t('بداية جديدة', 'A fresh start'),
                  s.t(
                    'لا توجد تقييمات بعد. تظهر هنا بعد اكتمال الطلب وتقييم العميل.',
                    'Reviews appear after a completed request is rated by its customer.',
                  ),
                  icon: Icons.star_outline,
                ),
              )
            else
              for (final review in summary.reviews.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: s.t(
                            '${review.$1} من ٥',
                            '${review.$1} out of 5',
                          ),
                          child: Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < review.$1
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 21,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          review.$2.trim().isEmpty
                              ? s.t(
                                  'تقييم بدون تعليق',
                                  'Rating without a comment',
                                )
                              : review.$2,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );

  Widget _stat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) => Column(
    children: [
      Icon(icon, color: appAccent(context, green), size: 22),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: appMuted(context)),
      ),
    ],
  );
}
