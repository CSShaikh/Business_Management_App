import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';
import '../customers/add_customer_screen.dart';
import '../customers/customer_screen.dart';
import '../expenses/add_expense_screen.dart';
import '../payments/add_payment_screen.dart';
import '../payments/add_supplier_payment_screen.dart';
import '../payments/payment_screen.dart';
import '../products/add_product_screen.dart';
import '../products/product_screen.dart';
import '../profile/profile_screen.dart';
import '../purchases/add_purchase_screen.dart';
import '../purchases/purchases_screen.dart';
import '../reports/reports_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../sales/add_sale_screen.dart';
import '../sales/sales_screen.dart';
import '../expenses/expenses_screen.dart';
import 'dashboard_home_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // ============================================================
  // MAIN NAVIGATION INDEX
  //
  // IMPORTANT: These indexes are the single source of truth for
  // both the navigation destinations and the IndexedStack.
  // Never change one order without changing the other.
  // ============================================================

  static const int _homeIndex = 0;
  static const int _productsIndex = 1;
  static const int _customersIndex = 2;
  static const int _salesIndex = 3;
  static const int _purchasesIndex = 4;
  static const int _suppliersIndex = 5;
  static const int _paymentsIndex = 6;
  static const int _expensesIndex = 7;

  int _currentIndex = _homeIndex;

  late final List<Widget> _screens;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;

  final BusinessRepository _businessRepository = BusinessRepository();

  @override
  void initState() {
    super.initState();

    // This order MUST exactly match the navigation destinations
    // in _buildNavigationRail().
    _screens = const [
      DashboardHomeScreen(), // 0
      ProductsScreen(), // 1
      CustomersScreen(), // 2
      SalesScreen(), // 3
      PurchasesScreen(), // 4
      SuppliersScreen(), // 5
      PaymentsScreen(), // 6
      ExpensesScreen(), // 7
      ReportsScreen(), // 8
      ProfileScreen(), // 9
    ];

    _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      _screens.length,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  // ============================================================
  // MAIN NAVIGATION
  // ============================================================

  void _onNavigationItemTapped(int index) {
    if (!mounted || index < 0 || index >= _screens.length) {
      return;
    }

    // Direct index assignment is intentional. It prevents a
    // navigation item from accidentally opening another section.
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _setNavigationIndex(int index) {
    if (!mounted || index < 0 || index >= _screens.length) {
      return;
    }

    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  void _openProducts() => _setNavigationIndex(_productsIndex);

  void _openCustomers() => _setNavigationIndex(_customersIndex);

  void _openSales() => _setNavigationIndex(_salesIndex);

  void _openPurchases() => _setNavigationIndex(_purchasesIndex);

  void _openSuppliers() => _setNavigationIndex(_suppliersIndex);

  void _openPayments() => _setNavigationIndex(_paymentsIndex);

  void _openExpenses() => _setNavigationIndex(_expensesIndex);

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<BusinessModel?> _getCurrentBusiness() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please login first.', isError: true);
      return null;
    }

    try {
      final BusinessModel? business = await _businessRepository
          .getBusinessForOwner(user.uid);

      if (business == null) {
        _showMessage(
          'Business profile not found. Please complete business setup.',
          isError: true,
        );
        return null;
      }

      final String businessId = business.id.trim();

      if (businessId.isEmpty) {
        _showMessage('Business ID is missing.', isError: true);
        return null;
      }

      return business;
    } catch (_) {
      _showMessage('Unable to load business details.', isError: true);
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Add',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose what you want to add.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    await _pushOnSection<bool>(_salesIndex, const AddSaleScreen());

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

    await _pushOnSection<bool>(_purchasesIndex, const AddPurchaseScreen());

    if (!mounted) {
      return;
    }

    _openPurchases();
  }

  // ============================================================
  // ADD CUSTOMER PAYMENT
  // ============================================================

  Future<void> _openAddPayment() async {
    if (!mounted) {
      return;
    }

    await _pushOnSection<bool>(_paymentsIndex, const AddPaymentScreen());

    if (!mounted) {
      return;
    }

    _openPayments();
  }

  // ============================================================
  // SUPPLIER PAYMENT
  // ============================================================

  Future<void> _openSupplierPayment() async {
    if (!mounted) {
      return;
    }

    await _pushOnSection<bool>(
      _suppliersIndex,
      const AddSupplierPaymentScreen(),
    );

    if (!mounted) {
      return;
    }

    _openSuppliers();
  }

  // ============================================================
  // ADD EXPENSE
  // ============================================================

  Future<void> _openAddExpense() async {
    if (!mounted) {
      return;
    }

    await _pushOnSection<bool>(_expensesIndex, const AddExpenseScreen());

    if (!mounted) {
      return;
    }

    _openExpenses();
  }

  // ============================================================
  // ADD CUSTOMER
  // ============================================================

  Future<void> _openAddCustomer() async {
    if (!mounted) {
      return;
    }

    final BusinessModel? business = await _getCurrentBusiness();

    if (!mounted || business == null) {
      return;
    }

    final String businessId = business.id.trim();

    if (businessId.isEmpty) {
      _showMessage('Business ID is missing.', isError: true);
      return;
    }

    await _pushOnSection<bool>(
      _customersIndex,
      AddCustomerScreen(businessId: businessId),
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

    final BusinessModel? business = await _getCurrentBusiness();

    if (!mounted || business == null) {
      return;
    }

    final String businessId = business.id.trim();

    if (businessId.isEmpty) {
      _showMessage('Business ID is missing.', isError: true);
      return;
    }

    await _pushOnSection<bool>(
      _productsIndex,
      AddProductScreen(businessId: businessId),
    );

    if (!mounted) {
      return;
    }

    _openProducts();
  }

  Future<T?> _pushOnSection<T>(int index, Widget page) async {
    if (!mounted || index < 0 || index >= _navigatorKeys.length) {
      return null;
    }

    _setNavigationIndex(index);

    final NavigatorState? navigator = _navigatorKeys[index].currentState;
    if (navigator == null) {
      return null;
    }

    return navigator.push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final int safeIndex =
        (_currentIndex >= 0 && _currentIndex < _screens.length)
        ? _currentIndex
        : _homeIndex;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _buildNavigationRail(selectedIndex: safeIndex),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(
                index: safeIndex,
                children: List<Widget>.generate(
                  _screens.length,
                  (int index) => Navigator(
                    key: _navigatorKeys[index],
                    onGenerateRoute: (RouteSettings settings) {
                      return MaterialPageRoute<void>(
                        settings: settings,
                        builder: (_) => _screens[index],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail({required int selectedIndex}) {
    final bool extended = MediaQuery.sizeOf(context).width >= 1200;
    final double width = extended ? 220 : 104;

    const List<({IconData icon, IconData selectedIcon, String label})> items = [
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      ),
      (
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: 'Products',
      ),
      (
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        label: 'Customers',
      ),
      (
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale_rounded,
        label: 'Sales',
      ),
      (
        icon: Icons.shopping_cart_outlined,
        selectedIcon: Icons.shopping_cart_rounded,
        label: 'Purchases',
      ),
      (
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        label: 'Suppliers',
      ),
      (
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments_rounded,
        label: 'Payments',
      ),
      (
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        label: 'Expenses',
      ),
      (
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
        label: 'Reports',
      ),
      (
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return SizedBox(
      width: width,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final bool selected = index == selectedIndex;
                  final Color active = Theme.of(context).colorScheme.primary;
                  final Color inactive = Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant;

                  return Tooltip(
                    message: item.label,
                    waitDuration: const Duration(milliseconds: 350),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onNavigationItemTapped(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        constraints: const BoxConstraints(minHeight: 58),
                        padding: EdgeInsets.symmetric(
                          horizontal: extended ? 16 : 4,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? active.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: extended
                            ? Row(
                                children: [
                                  Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    color: selected ? active : inactive,
                                    size: 25,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: selected
                                                ? active
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                          ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    color: selected ? active : inactive,
                                    size: 23,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: selected
                                              ? active
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                        ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
              child: Tooltip(
                message: 'Quick Add',
                child: FloatingActionButton.small(
                  heroTag: 'main_navigation_rail_add_fab',
                  onPressed: _showAddOptions,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
