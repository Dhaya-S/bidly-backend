import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../explore/models/listing_model.dart';
import '../providers/sell_provider.dart';

class SellItemScreen extends ConsumerStatefulWidget {
  final ListingModel? listingToEdit;
  final bool isEditing;

  const SellItemScreen({
    super.key,
    this.listingToEdit,
    this.isEditing = false,
  });

  @override
  ConsumerState<SellItemScreen> createState() => _SellItemScreenState();
}

class _SellItemScreenState extends ConsumerState<SellItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _purchaseDateController;
  late final TextEditingController _damageDetailsController;

  final Map<String, List<String>> _categoryHierarchy = {
    'Electronics': ['Phones', 'Tablets', 'Cameras', 'Audio', 'Wearables', 'Accessories'],
    'Computers': ['Laptops', 'Desktops', 'Monitors', 'Components', 'Printers'],
    'Fashion': ['Men', 'Women', 'Footwear', 'Watches', 'Bags'],
    'Vehicles': ['Cars', 'Bikes & Scooters', 'Bicycles', 'Spare Parts'],
    'Furniture': ['Living Room', 'Bedroom', 'Office & Study', 'Dining'],
    'Sports': ['Fitness & Gym', 'Cricket', 'Football', 'Outdoor & Camping'],
    'Books': ['Academic', 'Fiction', 'Self-Help', 'Children'],
  };

  final List<String> _conditions = [
    'Like New',
    'Excellent',
    'Good',
    'Fair',
    'Poor',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.listingToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sellProvider.notifier).loadForEditing(widget.listingToEdit!);
      });
    }
    final state = ref.read(sellProvider);
    _titleController = TextEditingController(text: widget.listingToEdit?.title ?? state.title);
    _descController = TextEditingController(text: widget.listingToEdit?.description ?? state.description);
    final initialPrice = widget.listingToEdit?.price ?? state.price;
    _priceController = TextEditingController(
      text: initialPrice > 0 ? initialPrice.toStringAsFixed(0) : '',
    );
    _purchaseDateController = TextEditingController(text: widget.listingToEdit?.purchaseDate ?? state.purchaseDate ?? '');
    _damageDetailsController = TextEditingController(text: widget.listingToEdit?.damageDetails ?? state.damageDetails ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _purchaseDateController.dispose();
    _damageDetailsController.dispose();
    super.dispose();
  }

  Future<void> _selectPurchaseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 90)),
      firstDate: DateTime(2010),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004E54),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E232A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _purchaseDateController.text = formatted;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid asking price'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    ref.read(sellProvider.notifier).setBasicDetails(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          price: price,
          purchaseDate: _purchaseDateController.text.trim().isNotEmpty
              ? _purchaseDateController.text.trim()
              : null,
        );

    if (widget.isEditing && widget.listingToEdit != null) {
      final ok = await ref.read(sellProvider.notifier).updateListing(widget.listingToEdit!.id);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing updated successfully!'),
            backgroundColor: Color(0xFF004E54),
          ),
        );
        context.pop(true);
      } else {
        final sellState = ref.read(sellProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sellState.errorMessage ?? 'Failed to update listing'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    context.push(AppRoutes.sellScope);
  }

  @override
  Widget build(BuildContext context) {
    final sellState = ref.watch(sellProvider);
    final currentCat = _categoryHierarchy.containsKey(sellState.category) ? sellState.category : 'Electronics';
    final availableSubs = _categoryHierarchy[currentCat] ?? ['Phones'];
    final currentSub = availableSubs.contains(sellState.subcategory) ? sellState.subcategory : availableSubs.first;
    final currentCondition = _conditions.contains(sellState.condition) ? sellState.condition : 'Excellent';
    final hasValidReel = sellState.reelPath != null && File(sellState.reelPath!).existsSync();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E232A)),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: Text(
          widget.isEditing ? 'Edit Item' : 'Sell Item',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E232A),
          ),
        ),
        actions: [
          if (!widget.isEditing)
            Container(
              margin: const EdgeInsets.only(right: 16),
              alignment: Alignment.center,
              child: const Text(
                '1/4',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
        bottom: widget.isEditing
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: 0.25,
                  backgroundColor: Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
                  minHeight: 3,
                ),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header text
                const Text(
                  'What are you selling?',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Category Dropdown
                _buildFieldLabel('Category *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: currentCat,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E232A),
                  ),
                  decoration: _buildInputDecoration(hintText: 'Select category'),
                  items: _categoryHierarchy.keys.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E232A),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(sellProvider.notifier).setCategory(val);
                      final subs = _categoryHierarchy[val];
                      if (subs != null && subs.isNotEmpty) {
                        ref.read(sellProvider.notifier).setSubcategory(subs.first);
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 2. Subcategory Dropdown
                _buildFieldLabel('Subcategory *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: currentSub,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E232A),
                  ),
                  decoration: _buildInputDecoration(hintText: 'Select subcategory'),
                  items: availableSubs.map((sub) {
                    return DropdownMenuItem<String>(
                      value: sub,
                      child: Text(
                        sub,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E232A),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(sellProvider.notifier).setSubcategory(val);
                    }
                  },
                ),
                const SizedBox(height: 18),

                // 3. Photos Section (Exact Mockup Match)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E232A),
                      ),
                    ),
                    Text(
                      'Shows in post & details (${sellState.photos.length}/4)',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(4, (index) {
                    final hasPhoto = index < sellState.photos.length;
                    final isNextAddSlot = index == sellState.photos.length;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 4,
                          right: index == 3 ? 0 : 4,
                        ),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: hasPhoto
                              ? Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        image: DecorationImage(
                                          image: FileImage(File(sellState.photos[index])),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => ref.read(sellProvider.notifier).removePhoto(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : GestureDetector(
                                  onTap: () => ref.read(sellProvider.notifier).pickPhoto(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isNextAddSlot ? const Color(0xFFE2F3F0) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isNextAddSlot ? const Color(0xFF004E54) : const Color(0xFFCBD5E1),
                                        width: isNextAddSlot ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: isNextAddSlot
                                        ? const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.camera_alt_outlined,
                                                color: Color(0xFF004E54),
                                                size: 24,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Add',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF004E54),
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Center(
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 22,
                                            ),
                                          ),
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // 4. Reel Section (Exact Mockup Match)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E232A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Optional',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add a short video to showcase your item in the Reels Feed (max 60s)',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),

                // Large Upload a reel Box
                GestureDetector(
                  onTap: () {
                    if (hasValidReel) {
                      ref.read(sellProvider.notifier).removeReel();
                    } else {
                      ref.read(sellProvider.notifier).pickReel();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: hasValidReel
                          ? const Color(0xFFE6F4F1).withValues(alpha: 0.5)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasValidReel
                            ? const Color(0xFF004E54)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              hasValidReel ? Icons.check_circle_rounded : Icons.ondemand_video_rounded,
                              color: const Color(0xFF004E54),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasValidReel ? 'Reel Video Attached (Tap to remove)' : 'Upload a reel',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E232A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasValidReel ? 'Video is ready for instant upload' : 'MP4, MOV up to 60 seconds',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Model / Title
                _buildFieldLabel('Model / Title *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF1E232A),
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: const Color(0xFF004E54),
                  decoration: _buildInputDecoration(
                    hintText: 'e.g. iPhone 14 Pro 256GB',
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Purchase Date
                _buildFieldLabel('Purchase Date'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _purchaseDateController,
                  readOnly: true,
                  onTap: _selectPurchaseDate,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF1E232A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Select purchase date',
                    suffixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF64748B), size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Description
                _buildFieldLabel('Description *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Color(0xFF1E232A),
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: const Color(0xFF004E54),
                  decoration: _buildInputDecoration(
                    hintText: 'Describe condition, features, reason for selling...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Asking Price (₹)
                _buildFieldLabel('Asking Price (₹) *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Price is required' : null,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: Color(0xFF1E232A),
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: const Color(0xFF004E54),
                  decoration: _buildInputDecoration(
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 16),

                // 8. Condition Dropdown
                _buildFieldLabel('Condition *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: currentCondition,
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E232A),
                  ),
                  decoration: _buildInputDecoration(hintText: 'Select condition'),
                  items: _conditions.map((cond) {
                    return DropdownMenuItem<String>(
                      value: cond,
                      child: Text(
                        cond,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E232A),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(sellProvider.notifier).setCondition(val);
                    }
                  },
                ),
                const SizedBox(height: 18),

                // 9. Any Damage Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Any Damage?',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E232A),
                          ),
                        ),
                        Text(
                          'Scratches, dents, or issues',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: sellState.hasDamage,
                      activeTrackColor: const Color(0xFF004E54),
                      onChanged: (val) => ref.read(sellProvider.notifier).setHasDamage(val),
                    ),
                  ],
                ),
                if (sellState.hasDamage) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _damageDetailsController,
                    maxLines: 2,
                    onChanged: (val) => ref.read(sellProvider.notifier).setDamageDetails(val),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      color: Color(0xFF1E232A),
                    ),
                    cursorColor: const Color(0xFF004E54),
                    decoration: _buildInputDecoration(
                      hintText: 'Specify scratches, dent on edge, minor screen mark...',
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004E54),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26), // pill button matching mockup
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      widget.isEditing
                          ? (sellState.isLoading ? 'Saving...' : 'Save Changes')
                          : 'Continue',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    String? hintText,
    Widget? suffixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      suffixIcon: suffixIcon,
      alignLabelWithHint: alignLabelWithHint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004E54), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E232A),
      ),
    );
  }
}
