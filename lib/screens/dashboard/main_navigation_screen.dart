import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';
import '../customers/add_customer_screen.dart';
import '../customers/customer_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../payments/add_payment_screen.dart';
import '../payments/supplier_payment_screen.dart';
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
  // ============================================================
  // NAVIGATION INDEX
  //
  // 0 = Home
  // 1 = Products
  // 2 = Customers
  // 3 = Sales
  // 4 = Reports
  // 5 = Profile
  // ============================================================

  static const int _homeIndex = 0;
  static const int _productsIndex = 1;
  static const int _customersIndex = 2;
  static const int _salesIndex = 3;
  static const int _reportsIndex = 4;
  static const int _profileIndex = 5;

  int _currentIndex = _homeIndex;

  late final List<Widget> _screens;

  final BusinessRepository _businessRepository =
      BusinessRepository();

  @override
  void initState() {
    super.initState();

    // IMPORTANT:
    // The order here MUST exactly match the NavigationBar
    // destination order below.
    _screens = const [
      DashboardHomeScreen(), // 0 - Home
      ProductsScreen(), // 1 - Products
      CustomersScreen(), // 2 - Customers
      SalesScreen(), // 3 - Sales
      ReportsScreen(), // 4 - Reports
      ProfileScreen(), // 5 - Profile
    ];
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  void _onNavigationItemTapped(int index) {
    if (!mounted) {
      return;
    }

    switch (index) {
      case _homeIndex:
        _openHome();
        break;

      case _productsIndex:
        _openProducts();
        break;

      case _customersIndex:
        _openCustomers();
        break;

      case _salesIndex:
        _openSales();
        break;

      case _reportsIndex:
        _openReports();
        break;

      case _profileIndex:
        _openProfile();
        break;

      default:
        return;
    }
  }

  void _setNavigationIndex(int index) {
    if (!mounted) {
      return;
    }

    if (index < 0 || index >= _screens.length) {
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _openHome() {
    _setNavigationIndex(_homeIndex);
  }

  void _openProducts() {
    _setNavigationIndex(_productsIndex);
  }

  void _openCustomers() {
    _setNavigationIndex(_customersIndex);
  }

  void _openSales() {
    _setNavigationIndex(_salesIndex);
  }

  void _openReports() {
    _setNavigationIndex(_reportsIndex);
  }

  void _openProfile() {
    _setNavigationIndex(_profileIndex);
  }

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<BusinessModel?> _getCurrentBusiness() async {
    final User? user = FirebaseAuth.instance.currentUser;

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

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        _showMessage(
          'Business ID is missing.',
          isError: true,
        );
        return null;
      }

      return business;
    } catch (_) {
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
    if (!mounted) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
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

                  // ==================================================
                  // ADD SALE
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.point_of_sale_rounded,
                    title: 'Add Sale',
                    subtitle: 'Create a new customer sale',
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openAddSale();
                    },
                  ),

                  // ==================================================
                  // ADD PURCHASE
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.shopping_cart_rounded,
                    title: 'Add Purchase',
                    subtitle: 'Record a new purchase',
                    color: AppColors.info,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openAddPurchase();
                    },
                  ),

                  // ==================================================
                  // CUSTOMER PAYMENT
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.payments_rounded,
                    title: 'Add Payment',
                    subtitle: 'Record customer payment',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openAddPayment();
                    },
                  ),

                  // ==================================================
                  // SUPPLIER PAYMENT
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.account_balance_rounded,
                    title: 'Supplier Payment',
                    subtitle: 'Record a payment to a supplier',
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openSupplierPayment();
                    },
                  ),

                  // ==================================================
                  // ADD EXPENSE
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Add Expense',
                    subtitle: 'Record business expense',
                    color: AppColors.warning,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openAddExpense();
                    },
                  ),

                  // ==================================================
                  // ADD CUSTOMER
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Add Hotel / Customer',
                    subtitle: 'Create a customer profile',
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _openAddCustomer();
                    },
                  ),

                  // ==================================================
                  // ADD PRODUCT
                  // ==================================================

                  _AddOptionTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Add Product',
                    subtitle: 'Create a new product',
                    color: AppColors.primaryDark,
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
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

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AddSaleScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    // Always return to the Sales section after leaving
    // the Add Sale screen.
    _openSales();
  }

  // ============================================================
  // ADD PURCHASE
  // ============================================================

  Future<void> _openAddPurchase() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AddPurchaseScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // ADD CUSTOMER PAYMENT
  // ============================================================

  Future<void> _openAddPayment() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AddPaymentScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    _openHome();
  }

  // ============================================================
  // SUPPLIER PAYMENT
  // ============================================================

  Future<void> _openSupplierPayment() async {
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SupplierPaymentScreen(),
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

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
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

    final String businessId = business.id.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddCustomerScreen(
          businessId: businessId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _openCustomers();
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

    final String businessId = business.id.trim();

    if (businessId.isEmpty) {
      _showMessage(
        'Business ID is missing.',
        isError: true,
      );
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
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

    final ScaffoldMessengerState messenger =
        ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Defensive safety check.
    //
    // This guarantees IndexedStack never receives an invalid
    // index even if the navigation state is changed unexpectedly.
    final int safeIndex =
        (_currentIndex >= 0 &&
                _currentIndex < _screens.length)
            ? _currentIndex
            : _homeIndex;

    // ------------------------------------------------------------
    // HERO-SAFE NAVIGATION SCREENS
    //
    // IndexedStack keeps all screens mounted. Some of those
    // screens contain FloatingActionButtons, which themselves
    // participate in Flutter's Hero system.
    //
    // Only the currently visible screen is allowed to participate
    // in Hero animations. All inactive screens remain mounted
    // for state preservation but their Hero widgets are disabled.
    // ------------------------------------------------------------

    final List<Widget> heroSafeScreens =
        List<Widget>.generate(
      _screens.length,
      (int index) {
        return HeroMode(
          enabled: index == safeIndex,
          child: _screens[index],
        );
      },
    );

    return Scaffold(
      // ==========================================================
      // CURRENT MAIN SCREEN
      // ==========================================================

      body: IndexedStack(
        index: safeIndex,
        children: heroSafeScreens,
      ),

      // ==========================================================
      // CENTER ADD BUTTON
      // ==========================================================

      floatingActionButton: FloatingActionButton(
        // Explicitly unique Hero tag.
        //
        // This FAB belongs to MainNavigationScreen and must never
        // use Flutter's default FAB Hero tag.
        heroTag: 'main_navigation_add_fab',
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

      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _onNavigationItemTapped,
        destinations: const [
          // ======================================================
          // 0 - HOME
          // ======================================================

          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),

          // ======================================================
          // 1 - PRODUCTS
          // ======================================================

          NavigationDestination(
            icon: Icon(
              Icons.inventory_2_outlined,
            ),
            selectedIcon: Icon(
              Icons.inventory_2_rounded,
            ),
            label: 'Products',
          ),

          // ======================================================
          // 2 - CUSTOMERS
          // ======================================================

          NavigationDestination(
            icon: Icon(
              Icons.people_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.people_rounded,
            ),
            label: 'Customers',
          ),

          // ======================================================
          // 3 - SALES
          // ======================================================

          NavigationDestination(
            icon: Icon(
              Icons.point_of_sale_outlined,
            ),
            selectedIcon: Icon(
              Icons.point_of_sale_rounded,
            ),
            label: 'Sales',
          ),

          // ======================================================
          // 4 - REPORTS
          // ======================================================

          NavigationDestination(
            icon: Icon(
              Icons.bar_chart_outlined,
            ),
            selectedIcon: Icon(
              Icons.bar_chart_rounded,
            ),
            label: 'Reports',
          ),

          // ======================================================
          // 5 - PROFILE
          // ======================================================

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
      contentPadding: const EdgeInsets.symmetric(
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
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