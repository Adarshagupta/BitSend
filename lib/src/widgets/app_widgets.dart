import 'dart:ui';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/app_models.dart';

enum BitsendPrimaryTab { home, deposit, offline, pending, settings }

class BitsendPageScaffold extends StatelessWidget {
  const BitsendPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.bottom,
    this.showBack = true,
    this.showHeader = true,
    this.primaryTab,
    this.onPrimaryTabSelected,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showBack;
  final bool showHeader;
  final BitsendPrimaryTab? primaryTab;
  final ValueChanged<BitsendPrimaryTab>? onPrimaryTabSelected;

  @override
  Widget build(BuildContext context) {
    final bool hasPrimaryNav =
        primaryTab != null && onPrimaryTabSelected != null;
    final bool hasBottomContent = bottom != null;
    final double scrollBottomPadding = hasPrimaryNav
        ? hasBottomContent
              ? 224
              : 138
        : 28;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[AppColors.canvasTint, AppColors.canvas],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -72,
              right: -36,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.emeraldTint.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 140,
              left: -84,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.amberTint.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SizedBox.expand(
                    child: hasPrimaryNav
                        ? Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: ListView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  scrollBottomPadding,
                                ),
                                children: <Widget>[
                                  _PageChrome(
                                    showBack: showBack,
                                    actions: actions,
                                  ),
                                  SizedBox(height: showHeader ? 18 : 8),
                                  if (showHeader)
                                    _PageHeader(
                                      title: title,
                                      subtitle: subtitle,
                                    ),
                                  child,
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: SafeArea(
                                  top: false,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      if (hasBottomContent)
                                        _BottomSurface(child: bottom!),
                                      if (hasBottomContent)
                                        const SizedBox(height: 10),
                                      _PrimaryBottomNav(
                                        currentTab: primaryTab!,
                                        onSelected: onPrimaryTabSelected!,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        : Column(
                            children: <Widget>[
                              Expanded(
                                child: ListView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    10,
                                    20,
                                    scrollBottomPadding,
                                  ),
                                  children: <Widget>[
                                    _PageChrome(
                                      showBack: showBack,
                                      actions: actions,
                                    ),
                                    SizedBox(height: showHeader ? 18 : 8),
                                    if (showHeader)
                                      _PageHeader(
                                        title: title,
                                        subtitle: subtitle,
                                      ),
                                    child,
                                  ],
                                ),
                              ),
                              if (hasBottomContent)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: SafeArea(
                                    top: false,
                                    child: _BottomSurface(child: bottom!),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSurface extends StatelessWidget {
  const _BottomSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: child,
      ),
    );
  }
}

class _PrimaryBottomNav extends StatelessWidget {
  const _PrimaryBottomNav({required this.currentTab, required this.onSelected});

  final BitsendPrimaryTab currentTab;
  final ValueChanged<BitsendPrimaryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const List<({BitsendPrimaryTab tab, IconData icon, String label})> items =
        <({BitsendPrimaryTab tab, IconData icon, String label})>[
          (
            tab: BitsendPrimaryTab.home,
            icon: Icons.home_rounded,
            label: 'Home',
          ),
          (
            tab: BitsendPrimaryTab.deposit,
            icon: Icons.south_west_rounded,
            label: 'Deposit',
          ),
          (
            tab: BitsendPrimaryTab.offline,
            icon: Icons.account_balance_wallet_outlined,
            label: 'Offline',
          ),
          (
            tab: BitsendPrimaryTab.pending,
            icon: Icons.schedule_send_rounded,
            label: 'Queue',
          ),
          (
            tab: BitsendPrimaryTab.settings,
            icon: Icons.tune_rounded,
            label: 'Settings',
          ),
        ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: items
                        .map(
                          (
                            ({BitsendPrimaryTab tab, IconData icon, String label})
                            item,
                          ) => Expanded(
                            child: _PrimaryBottomNavItem(
                              icon: item.icon,
                              label: item.label,
                              selected: currentTab == item.tab,
                              onTap: () => onSelected(item.tab),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryBottomNavItem extends StatelessWidget {
  const _PrimaryBottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.ink
                        : Colors.white.withValues(alpha: 0.0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.white : AppColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.ink : AppColors.slate,
                    height: 1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageChrome extends StatelessWidget {
  const _PageChrome({required this.showBack, this.actions});

  final bool showBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        if (showBack)
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          )
        else
          Text(
            'bitsend',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.slate,
              letterSpacing: 1.0,
            ),
          ),
        const Spacer(),
        if (actions != null && actions!.isNotEmpty)
          IconButtonTheme(
            data: Theme.of(context).iconButtonTheme,
            child: Wrap(spacing: 8, children: actions!),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Semantics(
              header: true,
              namesRoute: true,
              child: Text(title, style: theme.textTheme.headlineSmall),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(subtitle!, style: theme.textTheme.bodyMedium),
            ),
          ],
        ],
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
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.045),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
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
    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      hint: caption,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: AppColors.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(caption, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: enabled ? AppColors.ink : AppColors.mutedInk,
                  ),
                ],
              ),
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
    return Semantics(
      button: onTap != null,
      selected: active,
      label: '$label status',
      value: active ? 'On' : 'Off',
      child: Material(
        color: active ? AppColors.ink : AppColors.canvasWarm,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(99),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: active
                  ? AppColors.ink
                  : Colors.white.withValues(alpha: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: active ? Colors.white : AppColors.ink,
                ),
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
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

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

    return Semantics(
      label: 'Transfer status',
      value: status.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          status.label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontSize: 12, color: foreground),
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
    return Semantics(
      container: true,
      label: title,
      hint: caption,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.amberTint.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: AppColors.ink, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          ],
        ),
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
    return Semantics(
      container: true,
      label: label,
      value: value,
      hint: caption,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.slate,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleLarge),
            if (caption != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(caption!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool stacked =
        MediaQuery.sizeOf(context).width < 380 || textScale > 1.1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleMedium),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
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
  const FadeSlideIn({super.key, required this.child, required this.delay});

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
          Icon(icon, color: AppColors.slate, size: 28),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class TimelineStepTile extends StatelessWidget {
  const TimelineStepTile({super.key, required this.step, required this.isLast});

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
                Text(
                  step.caption,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
