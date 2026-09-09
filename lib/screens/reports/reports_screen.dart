import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildReportGrid(context),
              const SizedBox(height: 24),
              _buildComingSoonCard(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Reports',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track sales, purchases, expenses, profit and payments from one place.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportGrid(BuildContext context) {
    final List<_ReportItem> reports = [
      const _ReportItem(
        title: 'Sales Report',
        subtitle: 'View sales by date and customer',
        icon: Icons.point_of_sale_outlined,
        color: AppColors.primary,
      ),
      const _ReportItem(
        title: 'Purchase Report',
        subtitle: 'Track purchases and suppliers',
        icon: Icons.shopping_cart_outlined,
        color: AppColors.info,
      ),
      const _ReportItem(
        title: 'Profit Report',
        subtitle: 'Analyze gross and net profit',
        icon: Icons.trending_up_rounded,
        color: AppColors.success,
      ),
      const _ReportItem(
        title: 'Expense Report',
        subtitle: 'Track business expenses',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.warning,
      ),
      const _ReportItem(
        title: 'Payment Report',
        subtitle: 'Received and pending payments',
        icon: Icons.payments_outlined,
        color: AppColors.secondary,
      ),
      const _ReportItem(
        title: 'Stock Report',
        subtitle: 'Current inventory and stock value',
        icon: Icons.inventory_2_outlined,
        color: AppColors.info,
      ),
      const _ReportItem(
        title: 'Customer Report',
        subtitle: 'Customer sales and outstanding',
        icon: Icons.people_outline_rounded,
        color: AppColors.primary,
      ),
      const _ReportItem(
        title: 'Product Report',
        subtitle: 'Product-wise business performance',
        icon: Icons.category_outlined,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool isWide = constraints.maxWidth >= 700;

        final double spacing = 14;

        final double itemWidth =
            isWide
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: reports.map(
            (report) {
              return SizedBox(
                width: itemWidth,
                child: _ReportCard(
                  item: report,
                  onTap: () {
                    _showComingSoon(
                      context,
                      report.title,
                    );
                  },
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  Widget _buildComingSoonCard(
    BuildContext context,
    ThemeData theme,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Detailed date filters, charts and PDF reports will be connected in the Reports implementation phase.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(
    BuildContext context,
    String reportName,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$reportName is ready for the detailed report implementation.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _ReportCard extends StatelessWidget {
  final _ReportItem item;
  final VoidCallback onTap;

  const _ReportCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color:
                    theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}