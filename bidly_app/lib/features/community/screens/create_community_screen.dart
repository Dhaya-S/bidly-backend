import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../setup/providers/setup_provider.dart';
import '../providers/community_provider.dart';

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();

  String _selectedCategory = 'Electronics';
  double _radiusKm = 5.0;
  double? _latitude = 12.9784;
  double? _longitude = 80.2212;
  bool _isDetectingLocation = false;

  final List<String> _categories = [
    'Electronics',
    'Furniture',
    'Books',
    'Clothing',
    'Sports',
    'Appliances',
    'Vehicles',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with user's detected location if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final setupState = ref.read(setupProvider);
      if (setupState.address != null && setupState.address!.isNotEmpty) {
        setState(() {
          _locationController.text = setupState.address!;
          _latitude = setupState.latitude;
          _longitude = setupState.longitude;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );

        _latitude = position.latitude;
        _longitude = position.longitude;

        try {
          final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final locality = p.subLocality?.isNotEmpty == true ? p.subLocality : (p.locality ?? '');
            final city = p.locality?.isNotEmpty == true ? p.locality : (p.administrativeArea ?? '');
            final fullAddress = [locality, city, p.administrativeArea]
                .where((s) => s != null && s.toString().isNotEmpty)
                .join(', ');

            setState(() {
              _locationController.text = fullAddress.isNotEmpty ? fullAddress : '${position.latitude}, ${position.longitude}';
            });
          }
        } catch (_) {
          final user = ref.read(authProvider).user;
          if (user?.address != null && user!.address!.isNotEmpty) {
            setState(() {
              _locationController.text = user.address!;
            });
          }
        }
      } else {
        final user = ref.read(authProvider).user;
        if (user?.address != null && user!.address!.isNotEmpty) {
          setState(() {
            _locationController.text = user.address!;
          });
        }
      }
    } catch (_) {
      final user = ref.read(authProvider).user;
      if (user?.address != null && user!.address!.isNotEmpty) {
        setState(() {
          _locationController.text = user.address!;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
        if (_locationController.text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location updated: ${_locationController.text}'),
              backgroundColor: const Color(0xFF004E54),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not detect location. Please type your location.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _showLocationPickerSheet() {
    final popularLocations = [
      {'name': 'Velachery, Chennai', 'lat': 12.9784, 'lng': 80.2212},
      {'name': 'IIT Madras, Adyar, Chennai', 'lat': 12.9915, 'lng': 80.2337},
      {'name': 'Perungudi, OMR, Chennai', 'lat': 12.9654, 'lng': 80.2461},
      {'name': 'T. Nagar, Chennai', 'lat': 13.0418, 'lng': 80.2341},
      {'name': 'Anna Nagar, Chennai', 'lat': 13.0850, 'lng': 80.2101},
      {'name': 'Thoraipakkam, OMR, Chennai', 'lat': 12.9348, 'lng': 80.2312},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Drag Handle & Title Bar (pinned)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Community Location',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Options List
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Live GPS button
                      ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          _detectCurrentLocation();
                        },
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F4F1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location_rounded, color: Color(0xFF004E54), size: 20),
                        ),
                        title: const Text(
                          'Use Current GPS Location',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004E54),
                          ),
                        ),
                        subtitle: const Text(
                          'Accurately detects your coordinates',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                      ),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),

                      const Text(
                        'Popular Chennai Localities',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ...popularLocations.map((loc) {
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.location_on_outlined, color: Color(0xFF004E54), size: 20),
                          title: Text(
                            loc['name'] as String,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _locationController.text = loc['name'] as String;
                              _latitude = loc['lat'] as double;
                              _longitude = loc['lng'] as double;
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final created = await ref.read(communityProvider.notifier).createCommunity(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          category: _selectedCategory,
          address: _locationController.text.trim(),
          radiusKm: _radiusKm.toInt(),
          rules: _rulesController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
        );

    if (mounted) {
      if (created != null) {
        context.pushReplacement(
          '${AppRoutes.communitySuccess}?name=${Uri.encodeComponent(created.name)}',
        );
      } else {
        final err = ref.read(communityProvider).errorMessage ?? 'Failed to create community';
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
    final communityState = ref.watch(communityProvider);
    final localityName = _locationController.text.isNotEmpty
        ? _locationController.text.split(',').first.trim()
        : 'your location';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        title: const Text(
          'Create Community',
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
            color: const Color(0xFFE2E8F0),
            height: 1,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Community Name
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Community Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Community name is required';
                          if (v.trim().length < 3) return 'At least 3 characters required';
                          return null;
                        },
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1E232A),
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFF004E54),
                        decoration: _buildInputDecoration(
                          hintText: 'e.g. Velachery Residents, IIT Madras Campus...',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'At least 3 characters • must be unique',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Description
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1E232A),
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFF004E54),
                        decoration: _buildInputDecoration(
                          hintText: 'Tell people what this community is about...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Category Pill Chips
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Category'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = cat == _selectedCategory;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF004E54) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF004E54) : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Location Section with Tap to Pick on Map
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFieldLabel('Location'),
                          if (_isDetectingLocation)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004E54)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationController,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1E232A),
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFF004E54),
                        decoration: _buildInputDecoration(
                          prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF004E54), size: 20),
                          hintText: 'e.g. Velachery, Chennai, TN...',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Interactive Tap to Pick on Map Container
                      GestureDetector(
                        onTap: _isDetectingLocation ? null : _showLocationPickerSheet,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFB2DFDB)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.my_location_rounded, color: Color(0xFF004E54), size: 22),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to pick location on map / GPS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF004E54),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locationController.text.isNotEmpty ? 'Current: ${_locationController.text}' : 'No location set (tap to pick)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Community Radius Slider & Dynamic Coverage Indicator
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Community Radius'),
                      const SizedBox(height: 2),
                      const Text(
                        'Members within this radius will see your community in Nearby.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Large Distance Display
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              _radiusKm.toInt().toString(),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF004E54),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'km',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF004E54),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Radius Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFF004E54),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          thumbColor: const Color(0xFF004E54),
                          overlayColor: const Color(0xFF004E54).withValues(alpha: 0.1),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          onChanged: (val) => setState(() => _radiusKm = val),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 km', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                            Text('50 km', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Quick Radius Presets
                      Row(
                        children: [1, 5, 10, 25, 50].map((r) {
                          final isSel = _radiusKm.toInt() == r;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3.0),
                              child: GestureDetector(
                                onTap: () => setState(() => _radiusKm = r.toDouble()),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF004E54) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${r}km',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSel ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Dynamic Live Radar Coverage Explanation
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4F1).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFB2DFDB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.radar_rounded, color: Color(0xFF004E54), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Only buyers & sellers residing within ${_radiusKm.toInt()} km of $localityName will be eligible to discover and participate in this community.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  color: Color(0xFF004E54),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Rules & Guidelines
                _buildCardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('Rules & Guidelines'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _rulesController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF1E232A),
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: const Color(0xFF004E54),
                        decoration: _buildInputDecoration(
                          hintText: 'e.g. Be respectful, no spam, only list genuine items...',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Create Community Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: communityState.isCreating ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004E54),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF004E54),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: communityState.isCreating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Create Community',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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

  InputDecoration _buildInputDecoration({
    String? hintText,
    Widget? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13.5,
        color: Color(0xFF94A3B8),
      ),
      prefixIcon: prefixIcon,
      alignLabelWithHint: alignLabelWithHint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004E54), width: 1.5),
      ),
    );
  }

  Widget _buildCardSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
