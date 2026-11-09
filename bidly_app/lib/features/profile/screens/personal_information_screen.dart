import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends ConsumerState<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String _sellerType = 'INDIVIDUAL';
  String? _selectedAvatarPath;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(
        text: user?.phone != null && user!.phone.isNotEmpty ? '+91 ${user.phone}' : '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _sellerType = user?.sellerType ?? 'INDIVIDUAL';
    _selectedAvatarPath = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final path = await ref.read(profileProvider.notifier).pickProfileImage();
    if (path != null) {
      setState(() {
        _selectedAvatarPath = path;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(profileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          sellerType: _sellerType,
          address: _addressController.text.trim(),
          avatarUrl: _selectedAvatarPath,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      } else {
        final err = ref.read(profileProvider).errorMessage ?? 'Failed to update profile';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppTheme.border.withValues(alpha: 0.7),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Camera Badge
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary, width: 2),
                                image: _selectedAvatarPath != null
                                    ? (_selectedAvatarPath!.startsWith('http')
                                        ? DecorationImage(image: NetworkImage(_selectedAvatarPath!), fit: BoxFit.cover)
                                        : DecorationImage(image: FileImage(File(_selectedAvatarPath!)), fit: BoxFit.cover))
                                    : null,
                              ),
                              child: _selectedAvatarPath == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to change profile photo',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Full Name Field
                _buildFieldLabel('Full Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                  ),
                ),
                const SizedBox(height: 18),

                // Phone Number Field
                _buildFieldLabel('Phone Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter phone number' : null,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: '+91 XXXXX XXXXX',
                  ),
                ),
                const SizedBox(height: 18),

                // Seller Type Segmented Selector
                _buildFieldLabel('Seller Type'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      // Individual
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sellerType = 'INDIVIDUAL'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _sellerType == 'INDIVIDUAL' ? AppTheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Text(
                                'Individual',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _sellerType == 'INDIVIDUAL' ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Business
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _sellerType = 'BUSINESS'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _sellerType == 'BUSINESS' ? AppTheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Center(
                              child: Text(
                                'Business',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _sellerType == 'BUSINESS' ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Address Field
                _buildFieldLabel('Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(
                    hintText: 'Enter your address or locality...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 32),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: profileState.isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.primary,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: profileState.isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
