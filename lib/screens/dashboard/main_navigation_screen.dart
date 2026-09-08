import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../products/product_screen.dart';
import 'dashboard_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = const [
      DashboardHomeScreen(),
      ProductsScreen(),
      _ReportsPlaceholderScreen(),
      ProfileScreen(),
    ];
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _onNavigationItemTapped(
    int index,
  ) {
    setState(() {
      _currentIndex = index;
    });
  }

  // ============================================================
  // QUICK ADD
  // ============================================================

  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    'Choose what you want to add.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.point_of_sale_rounded,
                    title: 'Add Sale',
                    subtitle:
                        'Create a new customer sale',
                    color:
                        AppColors.success,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Sale',
                      );
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.shopping_cart_rounded,
                    title: 'Add Purchase',
                    subtitle:
                        'Record a new purchase',
                    color:
                        AppColors.info,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Purchase',
                      );
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.payments_rounded,
                    title: 'Add Payment',
                    subtitle:
                        'Record customer payment',
                    color:
                        AppColors.primary,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Payment',
                      );
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.receipt_long_rounded,
                    title: 'Add Expense',
                    subtitle:
                        'Record business expense',
                    color:
                        AppColors.warning,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Expense',
                      );
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.person_add_alt_1_rounded,
                    title:
                        'Add Hotel / Customer',
                    subtitle:
                        'Create a customer profile',
                    color:
                        AppColors.secondary,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _showComingSoon(
                        'Hotel / Customer',
                      );
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.inventory_2_outlined,
                    title: 'Add Product',
                    subtitle:
                        'Create a new product',
                    color:
                        AppColors.primaryDark,
                    onTap: () {
                      Navigator.pop(
                        context,
                      );

                      _openAddProduct();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  void _openAddProduct() {
    setState(() {
      _currentIndex = 1;
    });
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(
    String feature,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature screen will be added in the next steps.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // --------------------------------------------------------
      // CENTER ADD BUTTON
      // --------------------------------------------------------

      floatingActionButton:
          FloatingActionButton(
        onPressed: _showAddOptions,
        tooltip: 'Add',
        child: const Icon(
          Icons.add_rounded,
        ),
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerDocked,

      // --------------------------------------------------------
      // BOTTOM NAVIGATION
      // --------------------------------------------------------

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            _currentIndex,
        onDestinationSelected:
            _onNavigationItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
            ),
            selectedIcon: Icon(
              Icons.inventory_2_rounded,
            ),
            label: 'Products',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.bar_chart_outlined,
            ),
            selectedIcon: Icon(
              Icons.bar_chart_rounded,
            ),
            label: 'Reports',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUICK ADD TILE
// ============================================================

class _AddOptionTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(
          color: color.withValues(
            alpha: 0.10,
          ),
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight:
              FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
      ),
      onTap: onTap,
    );
  }
}

// ============================================================
// REPORTS PLACEHOLDER
// ============================================================

class _ReportsPlaceholderScreen
    extends StatelessWidget {
  const _ReportsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
        ),
      ),
      body:
          const _PlaceholderContent(
        icon:
            Icons.bar_chart_rounded,
        title:
            'Reports',
        message:
            'Reports and analytics will be added in the upcoming steps.',
      ),
    );
  }
}

// ============================================================
// PLACEHOLDER CONTENT
// ============================================================

class _PlaceholderContent
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PlaceholderContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                color:
                    AppColors.primary.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child: Icon(
                icon,
                size: 42,
                color:
                    AppColors.primary,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              title,
              textAlign:
                  TextAlign.center,
              style: theme
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
                  TextAlign.center,
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
    );
  }
}