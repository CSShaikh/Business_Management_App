import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({
    super.key,
  });

  @override
  State<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState
    extends State<BusinessSetupScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final BusinessRepository _businessRepository =
      BusinessRepository();

  final TextEditingController _businessNameController =
      TextEditingController();

  final TextEditingController _mobileController =
      TextEditingController();

  final TextEditingController _ownerNameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _addressController =
      TextEditingController();

  final TextEditingController _gstController =
      TextEditingController();

  String _businessType = 'Spices & Food';

  bool _isLoading = false;

  final List<String> _businessTypes = const [
    'Spices & Food',
    'Grocery',
    'Wholesale',
    'Retail',
    'Restaurant',
    'Manufacturing',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _loadCurrentUserData();
  }

  void _loadCurrentUserData() {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final String? displayName =
        user.displayName;

    final String email =
        user.email ?? '';

    if (displayName != null &&
        displayName.trim().isNotEmpty) {
      _businessNameController.text =
          displayName.trim();
    }

    if (email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _mobileController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();

    super.dispose();
  }

  Future<void> _saveBusiness() async {
    // Prevent multiple calls from double tap / submit.
    if (_isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'User session not found. Please login again.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First check whether this user already
      // has a business.
      final BusinessModel? existingBusiness =
          await _businessRepository
              .getBusinessForOwner(user.uid);

      if (!mounted) {
        return;
      }

      if (existingBusiness != null) {
        _showMessage(
          'Business profile already exists.',
        );

        setState(() {
          _isLoading = false;
        });

        return;
      }

      final DateTime now =
          DateTime.now();

      final String businessId =
          _businessRepository.firestore
              .collection('businesses')
              .doc()
              .id;

      final BusinessModel business =
          BusinessModel(
        id: businessId,
        ownerId: user.uid,
        businessName:
            _businessNameController.text
                .trim(),
        mobile:
            _mobileController.text
                .trim(),
        email:
            _emailController.text
                .trim(),
        address:
            _addressController.text
                .trim(),
        gstNumber:
            _gstController.text
                .trim(),
        ownerName:
            _ownerNameController.text
                .trim(),
        businessType:
            _businessType,
        createdAt: now,
        updatedAt: now,
      );

      final BusinessModel savedBusiness =
          await _businessRepository
              .createBusiness(
        business,
      );

      if (!mounted) {
        return;
      }

      // If another request created the business
      // at almost the same time, repository returns
      // the existing business.
      if (savedBusiness.id != business.id) {
        _showMessage(
          'Business profile already exists.',
        );
      } else {
        _showMessage(
          'Business profile saved successfully.',
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        e.message ??
            'Could not save business profile.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _getBusinessErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getBusinessErrorMessage(
    Object error,
  ) {
    final String message =
        error.toString();

    if (message.contains(
      'permission-denied',
    )) {
      return 'You do not have permission to save this business.';
    }

    if (message.contains('network')) {
      return 'Internet connection check karo.';
    }

    if (message.contains(
      'unauthenticated',
    )) {
      return 'Session expired. Please login again.';
    }

    return 'Something went wrong. Please try again.';
  }

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

  @override
  Widget build(
    BuildContext context,
  ) {
    final ThemeData theme =
        Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Setup',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 650,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    const SizedBox(
                      height: 12,
                    ),

                    Icon(
                      Icons
                          .storefront_rounded,
                      size: 54,
                      color: theme
                          .colorScheme
                          .primary,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Text(
                      'Set up your business',
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
                      'Enter your business details to get started.',
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

                    const SizedBox(
                      height: 32,
                    ),

                    TextFormField(
                      controller:
                          _businessNameController,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Name *',
                        hintText:
                            'Enter business name',
                        prefixIcon: Icon(
                          Icons
                              .business_outlined,
                        ),
                      ),
                      validator:
                          (value) {
                        if ((value ?? '')
                            .trim()
                            .isEmpty) {
                          return 'Business name is required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _ownerNameController,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Owner Name',
                        hintText:
                            'Enter owner name',
                        prefixIcon: Icon(
                          Icons
                              .person_outline,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _mobileController,
                      keyboardType:
                          TextInputType.phone,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Mobile Number *',
                        hintText:
                            'Enter mobile number',
                        prefixIcon: Icon(
                          Icons
                              .phone_outlined,
                        ),
                      ),
                      validator:
                          (value) {
                        final String
                            mobile =
                            value?.trim() ??
                                '';

                        if (mobile.isEmpty) {
                          return 'Mobile number is required';
                        }

                        if (mobile.length <
                            10) {
                          return 'Enter a valid mobile number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    DropdownButtonFormField<
                        String>(
                      initialValue:
                          _businessType,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Type',
                        prefixIcon: Icon(
                          Icons
                              .category_outlined,
                        ),
                      ),
                      items:
                          _businessTypes
                              .map(
                        (
                          String type,
                        ) =>
                            DropdownMenuItem<
                                String>(
                          value: type,
                          child:
                              Text(type),
                        ),
                      ).toList(),
                      onChanged:
                          _isLoading
                              ? null
                              : (
                                  String?
                                      value,
                                ) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setState(
                                    () {
                                      _businessType =
                                          value;
                                    },
                                  );
                                },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _emailController,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      textInputAction:
                          TextInputAction.next,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Email',
                        hintText:
                            'Optional email',
                        prefixIcon: Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                      validator:
                          (value) {
                        final String
                            email =
                            value?.trim() ??
                                '';

                        if (email
                                .isNotEmpty &&
                            !email
                                .contains(
                              '@',
                            )) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _gstController,
                      textInputAction:
                          TextInputAction.next,
                      textCapitalization:
                          TextCapitalization
                              .characters,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'GST Number',
                        hintText:
                            'Optional GST number',
                        prefixIcon: Icon(
                          Icons
                              .receipt_long_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    TextFormField(
                      controller:
                          _addressController,
                      maxLines: 3,
                      textInputAction:
                          TextInputAction
                              .newline,
                      enabled:
                          !_isLoading,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Business Address',
                        hintText:
                            'Enter complete address',
                        prefixIcon: Icon(
                          Icons
                              .location_on_outlined,
                        ),
                        alignLabelWithHint:
                            true,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    SizedBox(
                      height: 54,
                      child:
                          FilledButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : _saveBusiness,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .check_rounded,
                              ),
                        label: Text(
                          _isLoading
                              ? 'Saving...'
                              : 'Save & Continue',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Text(
                      '* Required fields',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}