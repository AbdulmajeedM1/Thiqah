import 'package:flutter/material.dart';

import 'store.dart';
import 'motion.dart';

const green = Color(0xFF0B6E4F);
Color appAccent(BuildContext context, Color color) =>
    Theme.of(context).brightness == Brightness.dark
    ? HSLColor.fromColor(color).withLightness(.72).toColor()
    : color;
Color appPale(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF203D32)
    : const Color(0xFFE9F6F1);
Color appInk(BuildContext context) => Theme.of(context).colorScheme.onSurface;
const ink = Color(0xFF063D2C);
Color appMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFB3C2BB)
    : const Color(0xFF6B7775);
const categoryIcons = [
  Icons.badge_outlined,
  Icons.storefront_outlined,
  Icons.directions_car_outlined,
  Icons.apartment_rounded,
  Icons.work_outline_rounded,
  Icons.grid_view_rounded,
];

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color, this.padding = 20});
  final Widget child;
  final Color? color;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? (color == null || color == Colors.white
              ? Theme.of(context).colorScheme.surfaceContainer
              : color!.computeLuminance() > .5
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : color)
        : color ?? Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.store, this.stage, {super.key});
  final TrustStore store;
  final Stage stage;
  @override
  Widget build(BuildContext context) {
    final color = switch (stage) {
      Stage.disputed => const Color(0xFFC0392B),
      Stage.payment || Stage.confirmation => const Color(0xFF946200),
      Stage.active => const Color(0xFF2D6CDF),
      Stage.cancelled || Stage.draft => appMuted(context),
      _ => green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        store.status(stage),
        style: TextStyle(
          color: appAccent(context, color),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RequestTile extends StatelessWidget {
  const RequestTile(this.store, this.request, {super.key, required this.onTap});
  final TrustStore store;
  final Request request;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: appPale(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      categoryIcons[request.category],
                      color: appAccent(context, green),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      store.category(request.category),
                      style: TextStyle(color: appMuted(context), fontSize: 12),
                    ),
                  ),
                  StatusBadge(store, request.stage),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                request.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                request.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: appMuted(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  Text(
                    '⌖ ${request.city}',
                    style: TextStyle(color: appMuted(context), fontSize: 12),
                  ),
                  Text(
                    store.t(
                      '${request.offers.length} عروض',
                      '${request.offers.length} offers',
                    ),
                    style: TextStyle(color: appAccent(context, green)),
                  ),
                  Text(
                    store.money(request.budget),
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView(
    this.title,
    this.subtitle, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 54, color: appAccent(context, green)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: appMuted(context)),
          ),
        ],
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.animate = false});
  final List<Widget> children;
  final bool animate;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: animate
            ? [
                for (var i = 0; i < children.length; i++)
                  Entrance(delay: i.clamp(0, 5) * 45, child: children[i]),
              ]
            : children,
      ),
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  TrustStore s,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.t('رجوع', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.t('تأكيد', 'Confirm')),
          ),
        ],
      ),
    ) ??
    false;

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
