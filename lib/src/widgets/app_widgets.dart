import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/app_models.dart';

class BitsendPageScaffold extends StatelessWidget {
  const BitsendPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.bottom,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: <Widget>[
                  Text(title, style: theme.textTheme.headlineSmall),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(subtitle!, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
            if (bottom != null)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: bottom,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String caption;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: AppColors.canvasWarm,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.ink),
                ),
                const SizedBox(height: 18),
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(caption, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusRailChip extends StatelessWidget {
  const StatusRailChip({
    super.key,
    required this.label,
    required this.active,
    required this.icon,
    this.onTap,
  });

  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.ink : AppColors.canvasWarm,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active ? AppColors.ink : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: active ? Colors.white : AppColors.ink),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: active ? Colors.white : AppColors.ink,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
  });

  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    switch (status) {
      case TransferStatus.created:
      case TransferStatus.sentOffline:
        background = AppColors.emeraldTint;
        foreground = AppColors.emerald;
      case TransferStatus.receivedPendingBroadcast:
        background = AppColors.amberTint;
        foreground = AppColors.amber;
      case TransferStatus.broadcasting:
      case TransferStatus.broadcastSubmitted:
        background = AppColors.blueTint;
        foreground = AppColors.blue;
      case TransferStatus.expired:
      case TransferStatus.broadcastFailed:
        background = AppColors.redTint;
        foreground = AppColors.red;
      case TransferStatus.confirmed:
        background = AppColors.emeraldTint;
        foreground = AppColors.emerald;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 12,
              color: foreground,
            ),
      ),
    );
  }
}

class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    this.action,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(caption, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleLarge),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(caption!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    required this.delay,
  });

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
  });

  final String title;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class TimelineStepTile extends StatelessWidget {
  const TimelineStepTile({
    super.key,
    required this.step,
    required this.isLast,
  });

  final TransferTimelineState step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color dotColor = step.isError
        ? AppColors.red
        : step.isComplete || step.isCurrent
            ? AppColors.ink
            : AppColors.line;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 28,
          child: Column(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 58,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: step.isComplete ? AppColors.ink : AppColors.line,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: step.isError ? AppColors.red : null,
                      ),
                ),
                const SizedBox(height: 4),
                Text(step.caption, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
