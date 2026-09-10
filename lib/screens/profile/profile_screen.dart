import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/business_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/business_repository.dart';
import '../auth/login_screen.dart';
import 'setting_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final AuthRepository _authRepository =
      AuthRepository();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  bool _isLoadingBusiness = true;
  bool _isLoggingOut = false;
  bool _isSavingBusiness = false;

  BusinessModel? _business;
  String? _businessError;

  User? get _user =>
      _authRepository.currentUser;

  String get _userName {
    final String name =
        _user?.displayName?.trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    final String businessOwner =
        _business?.ownerName.trim() ?? '';

    if (businessOwner.isNotEmpty) {
      return businessOwner;
    }

    return 'Business Owner';
  }

  String get _email {
    return _user?.email?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  // ===========================================================================
  // LOAD BUSINESS
  // ===========================================================================

  Future<void> _loadBusiness() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingBusiness = true;
      _businessError = null;
    });

    final User? user =
        _authRepository.currentUser;

    if (user == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBusiness = false;
        _businessError =
            'Your session has expired. Please login again.';
      });

      return;
    }

    try {
      await user.reload();

      final User? refreshedUser =
          FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingBusiness = false;
          _businessError =
              'Your session has expired. Please login again.';
        });

        return;
      }

      final BusinessModel? business =
          await _businessRepository
              .getBusinessForOwner(
        refreshedUser.uid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _business = business;
        _isLoadingBusiness = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBusiness = false;
        _businessError =
            e.message ??
                'Unable to load business information.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBusiness = false;
        _businessError =
            'Unable to load business information. Please try again.';
      });
    }
  }

  // ===========================================================================
  // SETTINGS
  // ===========================================================================

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const SettingsScreen(),
      ),
    );
  }

  // ===========================================================================
  // BUSINESS PROFILE
  // ===========================================================================

  Future<void> _openBusinessProfile() async {
    final BusinessModel? business =
        _business;

    if (business == null) {
      _showMessage(
        'Business profile is not available yet.',
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _BusinessProfileSheet(
          business: business,
          onSave: _saveBusinessProfile,
        );
      },
    );
  }

  Future<void> _saveBusinessProfile(
    BusinessModel updatedBusiness,
  ) async {
    if (_isSavingBusiness) {
      return;
    }

    final User? user =
        _authRepository.currentUser;

    if (user == null) {
      _showMessage(
        'Please login again.',
      );
      return;
    }

    if (updatedBusiness.ownerId != user.uid) {
      _showMessage(
        'You are not authorized to update this business.',
      );
      return;
    }

    if (updatedBusiness.businessName
        .trim()
        .isEmpty) {
      _showMessage(
        'Business name is required.',
      );
      return;
    }

    if (updatedBusiness.mobile
        .trim()
        .isEmpty) {
      _showMessage(
        'Business mobile number is required.',
      );
      return;
    }

    setState(() {
      _isSavingBusiness = true;
    });

    try {
      await _businessRepository
          .updateBusiness(
        updatedBusiness,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _business = updatedBusiness;
        _isSavingBusiness = false;
      });

      Navigator.of(context).pop();

      _showMessage(
        'Business profile updated successfully.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingBusiness = false;
      });

      _showMessage(
        e.message ??
            'Could not update business profile.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingBusiness = false;
      });

      _showMessage(
        'Could not update business profile. Please try again.',
      );
    }
  }

  // ===========================================================================
  // LOGOUT
  // ===========================================================================

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
              ),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.danger,
              ),
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text(
                'Logout',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authRepository.logout();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              const LoginScreen(),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      _showMessage(
        e.message ??
            'Logout failed. Please try again.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      _showMessage(
        'Logout failed. Please try again.',
      );
    }
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(
    String message,
  ) {
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
        ),
      );
  }

  // ===========================================================================
  // BUSINESS VALUE HELPERS
  // ===========================================================================

  String _businessName() {
    final String value =
        _business?.businessName.trim() ?? '';

    return value.isEmpty
        ? 'Business Profile'
        : value;
  }

  String _businessType() {
    final String value =
        _business?.businessType.trim() ?? '';

    return value.isEmpty
        ? 'Business'
        : value;
  }

  String _mobile() {
    final String value =
        _business?.mobile.trim() ?? '';

    return value.isEmpty
        ? 'Not available'
        : value;
  }

  String _address() {
    final String value =
        _business?.address.trim() ?? '';

    return value.isEmpty
        ? 'Not added'
        : value;
  }

  String _gstNumber() {
    final String value =
        _business?.gstNumber.trim() ?? '';

    return value.isEmpty
        ? 'Not added'
        : value;
  }

  String _ownerName() {
    final String value =
        _business?.ownerName.trim() ?? '';

    return value.isEmpty
        ? 'Not added'
        : value;
  }

  String _businessEmail() {
    final String value =
        _business?.email.trim() ?? '';

    if (value.isNotEmpty) {
      return value;
    }

    return _email.isEmpty
        ? 'Not added'
        : _email;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    final bool isWide =
        MediaQuery.sizeOf(context).width >=
            800;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                _isLoadingBusiness
                    ? null
                    : _loadBusiness,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBusiness,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 16,
              20,
              isWide ? 28 : 16,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 900,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    _buildProfileHeader(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 20),
                    _buildBusinessSummary(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 20),
                    _buildAccountInformation(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 20),
                    _buildBusinessManagement(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 20),
                    _buildSecuritySection(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 20),
                    _buildLogoutCard(
                      theme,
                      colors,
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Business Management App',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your business securely and efficiently.',
                      textAlign:
                          TextAlign.center,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PROFILE HEADER
  // ===========================================================================

  Widget _buildProfileHeader(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(
              alpha: 0.16,
            ),
            AppColors.secondary.withValues(
              alpha: 0.12,
            ),
            colors.surface,
          ],
        ),
        border: Border.all(
          color: AppColors.primary
              .withValues(alpha: 0.16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.business_center_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _businessName(),
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      color:
                          AppColors.primary,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _businessType(),
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: AppColors.success
                    .withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success
                      .withValues(alpha: 0.22),
                ),
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color:
                        AppColors.success,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Active',
                    style: TextStyle(
                      color:
                          AppColors.success,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 12,
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

  // ===========================================================================
  // BUSINESS SUMMARY
  // ===========================================================================

  Widget _buildBusinessSummary(
    ThemeData theme,
    ColorScheme colors,
  ) {
    if (_isLoadingBusiness) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Loading business information...',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_businessError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.danger
                      .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color:
                      AppColors.danger,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business information unavailable',
                      style: theme
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _businessError!,
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Retry',
                onPressed: _loadBusiness,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_business == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.warning
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color:
                      AppColors.warning,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Business profile not found',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Please complete your business setup before managing business details.',
                textAlign:
                    TextAlign.center,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                      colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Business Overview',
      icon: Icons.storefront_outlined,
      children: [
        _InfoTile(
          icon: Icons.business_outlined,
          title: 'Business Name',
          value: _businessName(),
        ),
        _InfoTile(
          icon: Icons.category_outlined,
          title: 'Business Type',
          value: _businessType(),
        ),
        _InfoTile(
          icon: Icons.phone_outlined,
          title: 'Mobile',
          value: _mobile(),
        ),
        _InfoTile(
          icon: Icons.location_on_outlined,
          title: 'Address',
          value: _address(),
        ),
        _InfoTile(
          icon: Icons.receipt_long_outlined,
          title: 'GST Number',
          value: _gstNumber(),
        ),
      ],
    );
  }

  // ===========================================================================
  // ACCOUNT INFORMATION
  // ===========================================================================

  Widget _buildAccountInformation(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SectionCard(
      title: 'Account Information',
      icon: Icons.account_circle_outlined,
      children: [
        _InfoTile(
          icon: Icons.email_outlined,
          title: 'Login Email',
          value: _email.isEmpty
              ? 'Not available'
              : _email,
        ),
        _InfoTile(
          icon: Icons.person_outline_rounded,
          title: 'Owner Name',
          value: _ownerName(),
        ),
        _InfoTile(
          icon: Icons.business_outlined,
          title: 'Business Email',
          value: _businessEmail(),
        ),
        _InfoTile(
          icon: Icons.verified_user_outlined,
          title: 'Account Status',
          value: 'Active',
          valueColor:
              AppColors.success,
        ),
      ],
    );
  }

  // ===========================================================================
  // BUSINESS MANAGEMENT
  // ===========================================================================

  Widget _buildBusinessManagement(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SectionCard(
      title: 'Business Management',
      icon: Icons.manage_accounts_outlined,
      children: [
        _ActionTile(
          icon: Icons.business_outlined,
          title: 'Business Profile',
          subtitle:
              'View and edit your business information',
          onTap: _openBusinessProfile,
        ),
        _ActionTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle:
              'App appearance and business preferences',
          onTap: _openSettings,
        ),
      ],
    );
  }

  // ===========================================================================
  // SECURITY
  // ===========================================================================

  Widget _buildSecuritySection(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return _SectionCard(
      title: 'Security',
      icon: Icons.security_outlined,
      children: [
        _InfoTile(
          icon: Icons.lock_outline_rounded,
          title: 'Authentication',
          value:
              'Firebase Authentication enabled',
        ),
        _InfoTile(
          icon: Icons.cloud_done_outlined,
          title: 'Data Storage',
          value:
              'Cloud Firestore',
        ),
      ],
    );
  }

  // ===========================================================================
  // LOGOUT CARD
  // ===========================================================================

  Widget _buildLogoutCard(
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.danger
                .withValues(alpha: 0.05),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.danger
                  .withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color:
                        AppColors.danger,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign out',
                        style: theme
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'End your current account session.',
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed:
                      _isLoggingOut
                          ? null
                          : _logout,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.danger,
                    side: BorderSide(
                      color: AppColors.danger
                          .withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  child: _isLoggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Logout',
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

// =============================================================================
// BUSINESS PROFILE SHEET
// =============================================================================

class _BusinessProfileSheet
    extends StatefulWidget {
  final BusinessModel business;
  final Future<void> Function(
    BusinessModel business,
  ) onSave;

  const _BusinessProfileSheet({
    required this.business,
    required this.onSave,
  });

  @override
  State<_BusinessProfileSheet> createState() =>
      _BusinessProfileSheetState();
}

class _BusinessProfileSheetState
    extends State<_BusinessProfileSheet> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _businessNameController;

  late final TextEditingController
      _mobileController;

  late final TextEditingController
      _emailController;

  late final TextEditingController
      _addressController;

  late final TextEditingController
      _gstController;

  late final TextEditingController
      _ownerNameController;

  late String _businessType;

  final List<String> _businessTypes = [
    'Retail',
    'Wholesale',
    'Distributor',
    'Manufacturer',
    'Service',
    'Restaurant',
    'Hotel',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _businessNameController =
        TextEditingController(
      text: widget.business.businessName,
    );

    _mobileController =
        TextEditingController(
      text: widget.business.mobile,
    );

    _emailController =
        TextEditingController(
      text: widget.business.email,
    );

    _addressController =
        TextEditingController(
      text: widget.business.address,
    );

    _gstController =
        TextEditingController(
      text: widget.business.gstNumber,
    );

    _ownerNameController =
        TextEditingController(
      text: widget.business.ownerName,
    );

    final String existingType =
        widget.business.businessType.trim();

    _businessType =
        _businessTypes.contains(existingType)
            ? existingType
            : 'Other';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final BusinessModel updated =
        BusinessModel(
      id: widget.business.id,
      ownerId: widget.business.ownerId,
      businessName:
          _businessNameController.text.trim(),
      mobile:
          _mobileController.text.trim(),
      email:
          _emailController.text.trim(),
      address:
          _addressController.text.trim(),
      gstNumber:
          _gstController.text.trim(),
      ownerName:
          _ownerNameController.text.trim(),
      businessType: _businessType,
      logoUrl: widget.business.logoUrl,
      createdAt: widget.business.createdAt,
      updatedAt: DateTime.now(),
    );

    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    final EdgeInsets keyboardPadding =
        EdgeInsets.only(
      bottom:
          MediaQuery.viewInsetsOf(context)
              .bottom,
    );

    return SafeArea(
      child: Padding(
        padding: keyboardPadding,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              28,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration:
                          BoxDecoration(
                        color: colors
                            .onSurfaceVariant
                            .withValues(
                          alpha: 0.25,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .primary
                              .withValues(
                            alpha: 0.10,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color:
                              AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Business Profile',
                              style: theme
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Update your business information',
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: colors
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller:
                        _businessNameController,
                    label: 'Business Name',
                    hint:
                        'Enter business name',
                    icon:
                        Icons.business_outlined,
                    validator: (value) {
                      if ((value ?? '')
                          .trim()
                          .isEmpty) {
                        return 'Business name is required';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller:
                        _mobileController,
                    label: 'Mobile',
                    hint:
                        'Enter mobile number',
                    icon:
                        Icons.phone_outlined,
                    keyboardType:
                        TextInputType.phone,
                    validator: (value) {
                      if ((value ?? '')
                          .trim()
                          .isEmpty) {
                        return 'Mobile number is required';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller:
                        _ownerNameController,
                    label: 'Owner Name',
                    hint:
                        'Enter owner name',
                    icon:
                        Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<
                      String>(
                    initialValue: _businessType,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Business Type',
                      prefixIcon: Icon(
                        Icons.category_outlined,
                      ),
                    ),
                    items: _businessTypes
                        .map(
                          (
                            String type,
                          ) {
                            return DropdownMenuItem<
                                String>(
                              value: type,
                              child:
                                  Text(type),
                            );
                          },
                        )
                        .toList(),
                    onChanged:
                        (String? value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _businessType =
                            value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller:
                        _emailController,
                    label:
                        'Business Email',
                    hint:
                        'Enter business email',
                    icon:
                        Icons.email_outlined,
                    keyboardType:
                        TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller:
                        _addressController,
                    label: 'Address',
                    hint:
                        'Enter business address',
                    icon:
                        Icons.location_on_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    controller:
                        _gstController,
                    label: 'GST Number',
                    hint:
                        'Enter GST number',
                    icon:
                        Icons.receipt_long_outlined,
                    textCapitalization:
                        TextCapitalization.characters,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(
                        Icons.save_rounded,
                      ),
                      label: const Text(
                        'Save Changes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

// =============================================================================
// SECTION CARD
// =============================================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration:
                      BoxDecoration(
                    color: AppColors.primary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 12,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// INFO TILE
// =============================================================================

class _InfoTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    final ColorScheme colors =
        theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color:
                colors.onSurfaceVariant,
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    color:
                        valueColor,
                    fontWeight:
                        FontWeight.w600,
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

// =============================================================================
// ACTION TILE
// =============================================================================

class _ActionTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration:
            BoxDecoration(
          color: AppColors.primary
              .withValues(
            alpha: 0.08,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge
            ?.copyWith(
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