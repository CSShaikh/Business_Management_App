import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/storage/local_logo_storage.dart';
import '../../core/storage/local_signature_storage.dart';
import '../../models/business_model.dart';
import '../../repositories/business_repository.dart';
import '../dashboard/dashboard_screen.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final BusinessRepository _businessRepository = BusinessRepository();

  final TextEditingController _businessNameController = TextEditingController();

  final TextEditingController _mobileController = TextEditingController();

  final TextEditingController _ownerNameController = TextEditingController();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _gstController = TextEditingController();

  String _businessType = 'Spices & Food';

  bool _isLoading = false;

  Uint8List? _logoBytes;
  String _logoFileName = '';
  Uint8List? _signatureBytes;

  final List<String> _businessTypes = const [
    'Spices & Food',
    'Grocery',
    'Wholesale',
    'Retail',
    'Restaurant',
    'Manufacturing',
    'Supplier',
    'Service',
    'A/C Technician',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _loadCurrentUserData() {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final String? displayName = user.displayName;

    final String email = user.email ?? '';

    if (displayName != null && displayName.trim().isNotEmpty) {
      _businessNameController.text = displayName.trim();
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

  // ===========================================================================
  // LOCAL BUSINESS LOGO
  // ===========================================================================

  Future<void> _pickLogo() async {
    if (_isLoading) {
      return;
    }

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (!mounted || file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _showMessage('Could not read the selected logo.', isError: true);
        return;
      }

      setState(() {
        _logoBytes = bytes;
        _logoFileName = file.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not select the logo. Please try again.',
        isError: true,
      );
    }
  }

  void _removeLogo() {
    if (_isLoading) {
      return;
    }

    setState(() {
      _logoBytes = null;
      _logoFileName = '';
    });
  }

  Future<void> _pickSignature() async {
    if (_isLoading) {
      return;
    }

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.image,
      );

      if (!mounted || file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('Could not read the selected signature.', isError: true);
        return;
      }

      setState(() => _signatureBytes = bytes);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not select the signature. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _removeSignature() {
    if (_isLoading) {
      return;
    }
    setState(() => _signatureBytes = null);
  }

  // ===========================================================================
  // SAVE BUSINESS
  // ===========================================================================

  Future<void> _saveBusiness() async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'User session not found. Please login again.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // -----------------------------------------------------------------------
      // Check whether a business already exists for this account.
      // -----------------------------------------------------------------------

      final BusinessModel? existingBusiness = await _businessRepository
          .getBusinessForOwner(user.uid);

      if (!mounted) {
        return;
      }

      if (existingBusiness != null) {
        _showMessage('Business profile already exists.');

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) {
          return;
        }

        // The user already has a business, so continue to Dashboard.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );

        return;
      }

      // -----------------------------------------------------------------------
      // Create business model.
      //
      // The repository generates the actual Firestore document ID.
      // -----------------------------------------------------------------------

      final DateTime now = DateTime.now();

      final BusinessModel business = BusinessModel(
        id: '',
        ownerId: user.uid,
        businessName: _businessNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        gstNumber: _gstController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        businessType: _businessType,
        createdAt: now,
        updatedAt: now,
      );

      // -----------------------------------------------------------------------
      // Save business.
      // -----------------------------------------------------------------------

      final String savedBusinessId = await _businessRepository.createBusiness(
        business,
      );

      if (!mounted) {
        return;
      }

      if (savedBusinessId.trim().isEmpty) {
        _showMessage('Business was not created correctly.', isError: true);
        return;
      }

      // The logo is intentionally device-local. It is saved inside the app's
      // private storage on Android/iOS/Windows/macOS/Linux, so a setup on one
      // device does not overwrite or depend on another device's logo.
      if (_logoBytes != null && _logoBytes!.isNotEmpty) {
        try {
          await LocalLogoStorage.save(
            businessId: savedBusinessId,
            bytes: _logoBytes!,
          );

          // Keep a cloud fallback in the business document as well. This is
          // intentionally limited so the Firestore document stays small.
          // The device-local copy above remains the primary image source.
          if (_logoBytes!.lengthInBytes <= 600000) {
            final String logoData =
                'data:image/png;base64,${base64Encode(_logoBytes!)}';
            await _businessRepository.updateBusinessLogo(
              businessId: savedBusinessId,
              logoData: logoData,
            );
          }
          // Also keep an owner-based copy. The owner id is stable even if
          // the business document id changes or an older duplicate business
          // record is returned by the repository.
          if (user.uid.trim().isNotEmpty &&
              user.uid.trim() != savedBusinessId) {
            await LocalLogoStorage.save(
              businessId: user.uid.trim(),
              bytes: _logoBytes!,
            );
          }
        } catch (_) {
          if (mounted) {
            _showMessage(
              'Business saved, but the logo could not be stored on this device.',
              isError: true,
            );
          }
        }
      }

      if (_signatureBytes != null && _signatureBytes!.isNotEmpty) {
        try {
          await LocalSignatureStorage.save(
            businessId: savedBusinessId,
            bytes: _signatureBytes!,
          );
        } catch (_) {
          if (mounted) {
            _showMessage(
              'Business saved, but the signature could not be stored on this device.',
              isError: true,
            );
          }
        }
      }

      // -----------------------------------------------------------------------
      // Success message.
      // -----------------------------------------------------------------------

      _showMessage('Business profile saved successfully.');

      // Give the success message a short time to appear.
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) {
        return;
      }

      // -----------------------------------------------------------------------
      // IMPORTANT:
      //
      // Login/Register -> Business Setup -> Dashboard
      //
      // Remove the complete authentication/setup stack so pressing back
      // from Dashboard does not return the user to Business Setup/Login.
      // -----------------------------------------------------------------------

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(_getFirebaseErrorMessage(e), isError: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_getBusinessErrorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // FIREBASE ERROR MESSAGE
  // ===========================================================================

  String _getFirebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to save this business.';

      case 'unauthenticated':
        return 'Session expired. Please login again.';

      case 'network-request-failed':
        return 'Internet connection check karo.';

      case 'unavailable':
        return 'Server temporarily unavailable. Please try again.';

      case 'already-exists':
        return 'Business profile already exists.';

      default:
        return error.message ?? 'Could not save business profile.';
    }
  }

  // ===========================================================================
  // GENERAL ERROR MESSAGE
  // ===========================================================================

  String _getBusinessErrorMessage(Object error) {
    final String message = error.toString().toLowerCase();

    if (message.contains('permission-denied')) {
      return 'You do not have permission to save this business.';
    }

    if (message.contains('network')) {
      return 'Internet connection check karo.';
    }

    if (message.contains('unauthenticated')) {
      return 'Session expired. Please login again.';
    }

    if (message.contains('already exists')) {
      return 'Business profile already exists.';
    }

    return 'Something went wrong. Please try again.';
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Business Setup')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // -----------------------------------------------------------------
                    // ICON
                    // -----------------------------------------------------------------
                    Icon(
                      Icons.storefront_rounded,
                      size: 54,
                      color: theme.colorScheme.primary,
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // TITLE
                    // -----------------------------------------------------------------
                    Text(
                      'Set up your business',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter your business details to get started.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // -----------------------------------------------------------------
                    // BUSINESS LOGO
                    // -----------------------------------------------------------------
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: _logoBytes == null
                                ? Icon(
                                    Icons.business_rounded,
                                    size: 40,
                                    color: theme.colorScheme.primary,
                                  )
                                : Image.memory(
                                    _logoBytes!,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Business Logo',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _logoBytes == null
                                      ? 'Add your logo for invoices and bills.'
                                      : (_logoFileName.isEmpty
                                            ? 'Logo selected'
                                            : _logoFileName),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _isLoading ? null : _pickLogo,
                                      icon: const Icon(
                                        Icons.upload_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _logoBytes == null
                                            ? 'Add Logo'
                                            : 'Change Logo',
                                      ),
                                    ),
                                    if (_logoBytes != null)
                                      TextButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : _removeLogo,
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Remove'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 82,
                            height: 62,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: _signatureBytes == null
                                ? Icon(
                                    Icons.draw_outlined,
                                    size: 34,
                                    color: theme.colorScheme.primary,
                                  )
                                : Image.memory(
                                    _signatureBytes!,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Authorised Signature',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Add your signature for professional bills/invoices.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _pickSignature,
                                      icon: const Icon(
                                        Icons.draw_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _signatureBytes == null
                                            ? 'Add Signature'
                                            : 'Change Signature',
                                      ),
                                    ),
                                    if (_signatureBytes != null)
                                      TextButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : _removeSignature,
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Remove'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // BUSINESS NAME
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _businessNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Business Name *',
                        hintText: 'Enter business name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Business name is required';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // OWNER NAME
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _ownerNameController,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Owner Name',
                        hintText: 'Enter owner name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // MOBILE
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number *',
                        hintText: 'Enter mobile number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final String mobile = value?.trim() ?? '';

                        if (mobile.isEmpty) {
                          return 'Mobile number is required';
                        }

                        if (mobile.length < 10) {
                          return 'Enter a valid mobile number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // BUSINESS TYPE
                    // -----------------------------------------------------------------
                    DropdownButtonFormField<String>(
                      initialValue: _businessType,
                      decoration: const InputDecoration(
                        labelText: 'Business Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: _businessTypes
                          .map(
                            (String type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoading
                          ? null
                          : (String? value) {
                              if (value == null) {
                                return;
                              }

                              setState(() {
                                _businessType = value;
                              });
                            },
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // EMAIL
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Business Email',
                        hintText: 'Optional email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final String email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return null;
                        }

                        final bool validEmail = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email);

                        if (!validEmail) {
                          return 'Enter a valid email';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // GST
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _gstController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        hintText: 'Optional GST number',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // -----------------------------------------------------------------
                    // ADDRESS
                    // -----------------------------------------------------------------
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Business Address',
                        hintText: 'Enter complete address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // -----------------------------------------------------------------
                    // SAVE BUTTON
                    // -----------------------------------------------------------------
                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _saveBusiness,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          _isLoading ? 'Saving...' : 'Save & Continue',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // -----------------------------------------------------------------
                    // REQUIRED NOTE
                    // -----------------------------------------------------------------
                    Text(
                      '* Required fields',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
