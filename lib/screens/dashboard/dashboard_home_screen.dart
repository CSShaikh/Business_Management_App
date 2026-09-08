import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 1200,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  context,
                  theme,
                ),

                const SizedBox(
                  height: 24,
                ),

                _buildOverviewSection(
                  context,
                  theme,
                ),

                const SizedBox(
                  height: 24,
                ),

                _buildQuickActions(
                  context,
                  theme,
                ),

                const SizedBox(
                  height: 24,
                ),

                _buildMainContent(
                  context,
                  theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'Good Morning 👋',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Business Dashboard',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Here is your business overview for today.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Container(
          decoration: BoxDecoration(
            color: theme
                .colorScheme
                .surface,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: theme
                  .colorScheme
                  .outline
                  .withValues(
                alpha: 0.15,
              ),
            ),
          ),
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TODAY'S OVERVIEW
  // ============================================================

  Widget _buildOverviewSection(
    BuildContext context,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Overview",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final bool compact =
                constraints.maxWidth < 650;

            final int columns =
                compact ? 2 : 3;

            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio:
                  compact ? 1.45 : 1.8,
              children: const [
                _MetricCard(
                  title: "Today's Sales",
                  value: '₹0',
                  subtitle:
                      'No sales recorded',
                  icon:
                      Icons.trending_up_rounded,
                  color:
                      AppColors.success,
                ),

                _MetricCard(
                  title: "Today's Purchase",
                  value: '₹0',
                  subtitle:
                      'No purchases recorded',
                  icon:
                      Icons.shopping_cart_outlined,
                  color:
                      AppColors.info,
                ),

                _MetricCard(
                  title: "Today's Profit",
                  value: '₹0',
                  subtitle:
                      'Calculated from sales',
                  icon:
                      Icons.account_balance_wallet_outlined,
                  color:
                      AppColors.primary,
                ),

                _MetricCard(
                  title: 'Received',
                  value: '₹0',
                  subtitle:
                      'Payments received',
                  icon:
                      Icons.payments_rounded,
                  color:
                      AppColors.secondary,
                ),

                _MetricCard(
                  title: 'Pending',
                  value: '₹0',
                  subtitle:
                      'Customer outstanding',
                  icon:
                      Icons.pending_actions_rounded,
                  color:
                      AppColors.warning,
                ),

                _MetricCard(
                  title: 'Expenses',
                  value: '₹0',
                  subtitle:
                      'Business expenses',
                  icon:
                      Icons.receipt_long_rounded,
                  color:
                      AppColors.danger,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions(
    BuildContext context,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'Common business operations',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickActionButton(
                  icon:
                      Icons.point_of_sale_rounded,
                  label: 'Sale',
                  color:
                      AppColors.success,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Sale',
                    );
                  },
                ),

                _QuickActionButton(
                  icon:
                      Icons.shopping_cart_rounded,
                  label: 'Purchase',
                  color:
                      AppColors.info,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Purchase',
                    );
                  },
                ),

                _QuickActionButton(
                  icon:
                      Icons.payments_rounded,
                  label: 'Payment',
                  color:
                      AppColors.primary,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Payment',
                    );
                  },
                ),

                _QuickActionButton(
                  icon:
                      Icons.receipt_long_rounded,
                  label: 'Expense',
                  color:
                      AppColors.warning,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Expense',
                    );
                  },
                ),

                _QuickActionButton(
                  icon:
                      Icons.person_add_alt_1_rounded,
                  label: 'Customer',
                  color:
                      AppColors.secondary,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Customer',
                    );
                  },
                ),

                _QuickActionButton(
                  icon:
                      Icons.inventory_2_outlined,
                  label: 'Product',
                  color:
                      AppColors.primaryDark,
                  onTap: () {
                    _showComingSoon(
                      context,
                      'Product',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent(
    BuildContext context,
    ThemeData theme,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final bool wide =
            constraints.maxWidth >= 850;

        if (wide) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildSalesOverview(
                  context,
                  theme,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                flex: 2,
                child: _buildInventoryCard(
                  context,
                  theme,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildSalesOverview(
              context,
              theme,
            ),

            const SizedBox(
              height: 16,
            ),

            _buildInventoryCard(
              context,
              theme,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SALES OVERVIEW
  // ============================================================

  Widget _buildSalesOverview(
    BuildContext context,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales Overview',
                        style: theme
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Sales performance will appear here.',
                        style: theme
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color: AppColors.primary
                        .withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Text(
                    'This Week',
                    style: TextStyle(
                      color:
                          AppColors.primary,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            Container(
              height: 210,
              width: double.infinity,
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(
                  alpha: 0.35,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child:
                  const _EmptyChart(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INVENTORY
  // ============================================================

  Widget _buildInventoryCard(
    BuildContext context,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Inventory',
                    style: theme
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const Icon(
                  Icons.inventory_2_outlined,
                  color:
                      AppColors.primary,
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            Row(
              children: [
                Expanded(
                  child: _InventoryStat(
                    title:
                        'Current Stock',
                    value: '0',
                    icon:
                        Icons.inventory_outlined,
                    color:
                        AppColors.info,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: _InventoryStat(
                    title:
                        'Low Stock',
                    value: '0',
                    icon:
                        Icons.warning_amber_rounded,
                    color:
                        AppColors.warning,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 18,
            ),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(
                  alpha: 0.35,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      'Your inventory data will appear here after adding products.',
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(
    BuildContext context,
    String feature,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature feature will be connected soon.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }
}

// ============================================================
// METRIC CARD
// ============================================================

class _MetricCard
    extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    color:
                        color.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 21,
                  ),
                ),

                const Spacer(),

                Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 13,
                  color: theme
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              title,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 3,
            ),

            Text(
              value,
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              subtitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: theme
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// QUICK ACTION BUTTON
// ============================================================

class _QuickActionButton
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration:
            BoxDecoration(
          color: color.withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(
              alpha: 0.14,
            ),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: color,
            ),

            const SizedBox(
              width: 8,
            ),

            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INVENTORY STAT
// ============================================================

class _InventoryStat
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _InventoryStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 23,
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY CHART
// ============================================================

class _EmptyChart
    extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons
                .insert_chart_outlined_rounded,
            size: 46,
            color: theme
                .colorScheme
                .onSurfaceVariant
                .withValues(
              alpha: 0.45,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            'No sales data yet',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            'Sales chart will appear after transactions.',
            textAlign:
                TextAlign.center,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}