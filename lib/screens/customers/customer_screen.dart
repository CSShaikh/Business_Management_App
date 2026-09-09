import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../models/customer_model.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/customer_repository.dart';
import '../customers/add_customer_screen.dart';
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final BusinessRepository _businessRepository = BusinessRepository();
  final CustomerRepository _customerRepository = CustomerRepository();

  BusinessModel? _business;
  bool _loadingBusiness = true;
  String? _businessError;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    if (!mounted) return;

    setState(() {
      _loadingBusiness = true;
      _businessError = null;
    });

    try {
      final business =
          await _businessRepository.getBusinessForCurrentUser();

      if (!mounted) return;

      if (business == null) {
        setState(() {
          _business = null;
          _loadingBusiness = false;
          _businessError =
              'Business profile not found. Please complete business setup.';
        });
        return;
      }

      setState(() {
        _business = business;
        _loadingBusiness = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingBusiness = false;
        _businessError = e.toString();
      });
    }
  }

  Future<void> _openAddCustomer() async {
    final business = _business;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          businessId: business.id,
        ),
      ),
    );
  }

  Future<void> _openEditCustomer(CustomerModel customer) async {
    final business = _business;

    if (business == null) {
      _showMessage(
        'Business information is not available.',
        isError: true,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(
          businessId: business.id,
          customer: customer,
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final business = _business;

    if (business == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Customer?'),
          content: Text(
            'Are you sure you want to delete "${customer.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _customerRepository.deleteCustomer(
        businessId: business.id,
        customerId: customer.id,
      );

      if (!mounted) return;

      _showMessage(
        'Customer deleted successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to delete customer: $e',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? AppColors.danger : AppColors.success,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBusiness) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_businessError != null) {
      return _buildErrorState();
    }

    final business = _business;

    if (business == null) {
      return _buildNoBusinessState();
    }

    return StreamBuilder<List<CustomerModel>>(
      stream: _customerRepository.watchCustomers(
        businessId: business.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildStreamErrorState(
            snapshot.error.toString(),
          );
        }

        final customers = snapshot.data ?? <CustomerModel>[];

        return _buildContent(customers);
      },
    );
  }

  Widget _buildContent(List<CustomerModel> customers) {
    final filteredCustomers = customers.where((customer) {
      final query = _searchQuery.trim().toLowerCase();

      if (query.isEmpty) {
        return true;
      }

      return customer.name.toLowerCase().contains(query) ||
          customer.ownerName.toLowerCase().contains(query) ||
          customer.mobile.toLowerCase().contains(query) ||
          customer.email.toLowerCase().contains(query);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadBusiness,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(customers.length),
          ),
          SliverToBoxAdapter(
            child: _buildSummaryCards(customers),
          ),
          SliverToBoxAdapter(
            child: _buildSearchBar(),
          ),
          if (filteredCustomers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                isSearchResult:
                    _searchQuery.trim().isNotEmpty,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                100,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final customer =
                        filteredCustomers[index];

                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: _CustomerCard(
                        customer: customer,
                        onEdit: () {
                          _openEditCustomer(customer);
                        },
                        onDelete: () {
                          _deleteCustomer(customer);
                        },
                      ),
                    );
                  },
                  childCount: filteredCustomers.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalCustomers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers & Hotels',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCustomers customer${totalCustomers == 1 ? '' : 's'} registered',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: AppColors
                            .lightTextSecondary,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _openAddCustomer,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    List<CustomerModel> customers,
  ) {
    return SizedBox(
      height: 112,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        scrollDirection: Axis.horizontal,
        children: [
          _SummaryCard(
            title: 'Total',
            value: '${customers.length}',
            icon: Icons.people_alt_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            title: 'With Mobile',
            value:
                '${customers.where((e) => e.mobile.trim().isNotEmpty).length}',
            icon: Icons.phone_rounded,
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            title: 'With GST',
            value:
                '${customers.where((e) => e.gstNumber.trim().isNotEmpty).length}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        8,
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              'Search hotel, owner, mobile or email...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(
                    Icons.clear_rounded,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isSearchResult,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: 0.10,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearchResult
                  ? 'No customers found'
                  : 'No customers yet',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearchResult
                  ? 'Try a different search term.'
                  : 'Add your first hotel or customer to start managing sales and payments.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppColors
                        .lightTextSecondary,
                  ),
            ),
            if (!isSearchResult) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openAddCustomer,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Customer',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load business',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _businessError ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadBusiness,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load customers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBusinessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.business_center_outlined,
              size: 56,
              color: AppColors.warning,
            ),
            const SizedBox(height: 16),
            const Text(
              'Business profile required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete your business setup first.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color:
                        AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasMobile =
        customer.mobile.trim().isNotEmpty;
    final hasAddress =
        customer.address.trim().isNotEmpty;
    final hasGst =
        customer.gstNumber.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildAvatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customer.name,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          } else if (value ==
                              'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) {
                          return const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons.edit_outlined,
                                ),
                                title: Text('Edit'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading: Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      AppColors.danger,
                                ),
                                title: Text('Delete'),
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                  if (customer
                      .ownerName
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Owner: ${customer.ownerName}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:
                            AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasMobile)
                        _InfoChip(
                          icon:
                              Icons.phone_outlined,
                          text: customer.mobile,
                        ),
                      if (hasGst)
                        _InfoChip(
                          icon:
                              Icons.receipt_long_outlined,
                          text: 'GST',
                        ),
                    ],
                  ),
                  if (hasAddress) ...[
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: AppColors
                              .lightTextSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            customer.address,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors
                                  .lightTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final firstLetter = customer.name
            .trim()
            .isEmpty
        ? '?'
        : customer.name
            .trim()
            .substring(0, 1)
            .toUpperCase();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.secondary,
          ],
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}