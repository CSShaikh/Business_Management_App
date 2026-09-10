import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';
import '../customers/add_customer_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../payments/add_payment_screen.dart';
import '../products/add_product_screen.dart';
import '../products/product_screen.dart';
import '../profile/profile_screen.dart';
import '../purchases/add_purchase_screen.dart';
import '../reports/reports_screen.dart';
import '../sales/add_sale_screen.dart';
import '../sales/sales_screen.dart';
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

  final BusinessRepository _businessRepository =
      BusinessRepository();

  @override
  void initState() {
    super.initState();

    _screens = const [
      DashboardHomeScreen(),
      ProductsScreen(),
      SalesScreen(),
      ReportsScreen(),
      ProfileScreen(),
    ];
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onNavigationItemTapped(int index) {
    if (index < 0 || index >= _screens.length) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _openHome() {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 0;
    });
  }

  void _openProducts() {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 1;
    });
  }

  void _openSales() {
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = 2;
    });
  }

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<BusinessModel?> _getCurrentBusiness() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
        isError: true,
      );
      return null;
    }

    try {
      final BusinessModel? business =
          await _businessRepository.getBusinessForOwner(
        user.uid,
      );

      if (business == null) {
        _showMessage(
          'Business profile not found. Please complete business setup.',
          isError: true,
        );
        return null;
      }

      final String businessId =
          business.id.trim();

      if (businessId.isEmpty) {
        _showMessage(
          'Business ID is missing.',
          isError: true,
        );
        return null;
      }

      return business;
    } catch (e) {
      _showMessage(
        'Unable to load business details.',
        isError: true,
      );
      return null;
    }
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
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 18),

                  _AddOptionTile(
                    icon:
                        Icons.point_of_sale_rounded,
                    title: 'Add Sale',
                    subtitle:
                        'Create a new customer sale',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );
                      _openAddSale();
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.shopping_cart_rounded,
                    title: 'Add Purchase',
                    subtitle:
                        'Record a new purchase',
                    color: AppColors.info,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );
                      _openAddPurchase();
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.payments_rounded,
                    title: 'Add Payment',
                    subtitle:
                        'Record customer payment',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );
                      _openAddPayment();
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.receipt_long_rounded,
                    title: 'Add Expense',
                    subtitle:
                        'Record business expense',
                    color: AppColors.warning,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );
                      _openAddExpense();
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.person_add_alt_1_rounded,
                    title:
                        'Add Hotel / Customer',
                    subtitle:
                        'Create a customer profile',
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
                      );
                      _openAddCustomer();
                    },
                  ),

                  _AddOptionTile(
                    icon:
                        Icons.inventory_2_outlined,
                    title: 'Add Product',
                    subtitle:
                        'Create a new product',
                    color: AppColors.primaryDark,
                    onTap: () {
                      Navigator.pop(
                        bottomSheetContext,
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
  // ADD SALE
  // ============================================================

  Future<void> _openAddSale() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddSaleScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openSales();
  }

  // ============================================================
  // ADD PURCHASE
  // ============================================================

  Future<void> _openAddPurchase() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddPurchaseScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // ADD PAYMENT
  // ============================================================

  Future<void> _openAddPayment() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddPaymentScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // ADD EXPENSE
  // ============================================================

  Future<void> _openAddExpense() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddExpenseScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> _openAddCustomer() async {
    if (!mounted) {
      return;
    }

    final BusinessModel? business =
        await _getCurrentBusiness();

    if (!mounted || business == null) {
      return;
    }

    final String businessId =
        business.id.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          businessId: businessId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  Future<void> _openAddProduct() async {
    if (!mounted) {
      return;
    }

    final BusinessModel? business =
        await _getCurrentBusiness();

    if (!mounted || business == null) {
      return;
    }

    final String businessId =
        business.id.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          businessId: businessId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _openProducts();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              isError
                  ? Theme.of(context)
                      .colorScheme
                      .error
                  : null,
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

      // ==========================================================
      // CENTER ADD BUTTON
      // ==========================================================

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

      // ==========================================================
      // BOTTOM NAVIGATION
      // ==========================================================

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
              Icons.point_of_sale_outlined,
            ),
            selectedIcon: Icon(
              Icons.point_of_sale_rounded,
            ),
            label: 'Sales',
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

class _AddOptionTile extends StatelessWidget {
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
        decoration: BoxDecoration(
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