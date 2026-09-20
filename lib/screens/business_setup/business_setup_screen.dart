import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  XFile? _logoFile;
  Uint8List? _logoPreviewBytes;
  bool _isUploadingLogo = false;

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

  Future<void> _pickBusinessLogo() async {
    if (_isLoading || _isUploadingLogo) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      if (bytes.length > 5 * 1024 * 1024) {
        _showMessage('Logo image should be under 5 MB.', isError: true);
        return;
      }

      setState(() {
        _logoFile = file;
        _logoPreviewBytes = bytes;
      });
    } catch (e) {
      _showMessage('Unable to select logo image.', isError: true);
    }
  }

  Future<String> _uploadBusinessLogo(String ownerId) async {
    if (_logoFile == null || _logoPreviewBytes == null) return '';

    setState(() => _isUploadingLogo = true);
    try {
      final String extension = _logoFile!.name.toLowerCase().contains('.')
          ? _logoFile!.name.split('.').last.toLowerCase()
          : 'jpg';
      final String contentType = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('business_logos')
          .child(ownerId)
          .child('logo_${DateTime.now().millisecondsSinceEpoch}.$extension');

      final UploadTask task = ref.putData(
        _logoPreviewBytes!,
        SettableMetadata(contentType: contentType),
      );
      await task;
      return await ref.getDownloadURL();
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
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
      // Upload optional business logo before creating the business document.
      // -----------------------------------------------------------------------
      String logoUrl = '';
      if (_logoPreviewBytes != null) {
        logoUrl = await _uploadBusinessLogo(user.uid);
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
        logoUrl: logoUrl,
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
                    // BUSINESS LOGO
                    // -----------------------------------------------------------------
                    Center(
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _pickBusinessLogo,
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _logoPreviewBytes == null
                                  ? Icon(
                                      Icons.add_a_photo_rounded,
                                      size: 36,
                                      color: theme.colorScheme.primary,
                                    )
                                  : Image.memory(
                                      _logoPreviewBytes!,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickBusinessLogo,
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: Text(_logoPreviewBytes == null ? 'Add Business Logo' : 'Change Logo'),
                          ),
                          Text(
                            'Optional • PNG, JPG or WEBP • up to 5 MB',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

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
                        onPressed: (_isLoading || _isUploadingLogo) ? null : _saveBusiness,
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
