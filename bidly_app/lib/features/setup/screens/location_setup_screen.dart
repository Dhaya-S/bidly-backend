import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/setup_provider.dart';

class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  late final TextEditingController _addressController;
  final List<int> _radiusOptions = [1, 5, 10, 25, 50];
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();

    // Fetch live device location on open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(setupProvider.notifier).fetchCurrentGpsLocation();
      final state = ref.read(setupProvider);
      if (state.address != null && state.address!.isNotEmpty) {
        setState(() {
          _addressController.text = state.address!;
        });
      }
      if (state.latitude != null && state.longitude != null) {
        _animateMapTo(state.latitude!, state.longitude!);
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _animateMapTo(double lat, double lng, {double? zoom}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(lat, lng),
          zoom: zoom ?? _calculateZoomForRadius(ref.read(setupProvider).selectedRadiusKm),
        ),
      ),
    );
  }

  double _calculateZoomForRadius(int radiusKm) {
    if (radiusKm <= 1) return 14.5;
    if (radiusKm <= 5) return 13.0;
    if (radiusKm <= 10) return 12.0;
    if (radiusKm <= 25) return 10.5;
    return 9.5;
  }

  Future<void> _handleUseMyLocation() async {
    FocusScope.of(context).unfocus();
    await ref.read(setupProvider.notifier).fetchCurrentGpsLocation();
    final state = ref.read(setupProvider);
    if (state.address != null && state.address!.isNotEmpty) {
      setState(() {
        _addressController.text = state.address!;
      });
    }
    if (state.latitude != null && state.longitude != null) {
      _animateMapTo(state.latitude!, state.longitude!);
    }
  }

  Future<void> _handleAddressSearch() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    final found = await ref.read(setupProvider.notifier).searchAndSetAddress(query);

    if (found) {
      final state = ref.read(setupProvider);
      if (state.address != null && state.address!.isNotEmpty) {
        setState(() {
          _addressController.text = state.address!;
        });
      }
      if (state.latitude != null && state.longitude != null) {
        _animateMapTo(state.latitude!, state.longitude!);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address not found. Please try another query.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();
    final success = await ref.read(setupProvider.notifier).saveLocation(
          manualAddress: _addressController.text.trim(),
        );

    if (mounted) {
      if (success) {
        context.push(AppRoutes.setupInterests);
      } else {
        context.push(AppRoutes.setupInterests); // Proceed with fallback
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to reactive updates so address text field is ALWAYS updated immediately
    ref.listen<SetupState>(setupProvider, (previous, next) {
      if (next.address != null &&
          next.address!.isNotEmpty &&
          _addressController.text != next.address) {
        setState(() {
          _addressController.text = next.address!;
        });
      }
      if (next.latitude != null &&
          next.longitude != null &&
          (previous?.latitude != next.latitude || previous?.longitude != next.longitude)) {
        _animateMapTo(next.latitude!, next.longitude!);
      }
    });

    final setupState = ref.watch(setupProvider);
    final selectedRadius = setupState.selectedRadiusKm;
    final hasCoordinates = setupState.latitude != null && setupState.longitude != null;
    final currentLatLng = hasCoordinates
        ? LatLng(setupState.latitude!, setupState.longitude!)
        : const LatLng(13.0827, 80.2707); // Default fallback coordinate for map viewport

    final isLoading = setupState.isLoading;

    final markers = hasCoordinates
        ? {
            Marker(
              markerId: const MarkerId('user_location'),
              position: currentLatLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
              infoWindow: InfoWindow(
                title: 'Selected Location',
                snippet: setupState.city ?? setupState.address ?? '',
              ),
            ),
          }
        : <Marker>{};

    final circles = hasCoordinates
        ? {
            Circle(
              circleId: const CircleId('search_radius'),
              center: currentLatLng,
              radius: selectedRadius * 1000.0,
              fillColor: AppTheme.primary.withValues(alpha: 0.15),
              strokeColor: AppTheme.primary.withValues(alpha: 0.7),
              strokeWidth: 2,
            ),
          }
        : <Circle>{};

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Step Header with Back Button & Progress Bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(AppRoutes.setupIdentity);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Step 2 of 3 · Your Location',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildProgressBar(progress: 0.66),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Where are you?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              const Text(
                'Find deals and sellers near you',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Interactive Google Map View
              Container(
                width: double.infinity,
                height: 170,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border, width: 1.2),
                ),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: currentLatLng,
                        zoom: hasCoordinates ? _calculateZoomForRadius(selectedRadius) : 12.0,
                      ),
                      markers: markers,
                      circles: circles,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (hasCoordinates) {
                          _animateMapTo(setupState.latitude!, setupState.longitude!);
                        }
                      },
                      onTap: (latLng) async {
                        await ref.read(setupProvider.notifier).setCoordinates(latLng.latitude, latLng.longitude);
                        final s = ref.read(setupProvider);
                        if (s.address != null && s.address!.isNotEmpty) {
                          setState(() {
                            _addressController.text = s.address!;
                          });
                        }
                        _animateMapTo(latLng.latitude, latLng.longitude);
                      },
                    ),
                    if (setupState.isLocationLoading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.25),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Location Detected Info Banner (Shows detected city & radius)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        setupState.detectedLocation ??
                            (setupState.address != null && setupState.address!.isNotEmpty
                                ? setupState.address!
                                : 'Detecting your location...'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Use My Location Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: setupState.isLocationLoading ? null : _handleUseMyLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: setupState.isLocationLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Use My Location',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 22),

              // Divider / Label
              const Text(
                'OR ENTER YOUR ADDRESS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textHint,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Manual Address Search Input Field with Real-Time Text
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                onFieldSubmitted: (_) => _handleAddressSearch(),
                decoration: InputDecoration(
                  hintText: 'Enter your area, city or pincode...',
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppTheme.textHint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_addressController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                          onPressed: () {
                            setState(() {
                              _addressController.clear();
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primary),
                        onPressed: _handleAddressSearch,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Search Radius Label
              const Text(
                'SEARCH RADIUS',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textHint,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Radius Chips Row [ 1km ] [ 5km ] [ 10km ] [ 25km ] [ 50km ]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _radiusOptions.map((radius) {
                  final isSelected = selectedRadius == radius;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(setupProvider.notifier).setRadius(radius);
                          if (hasCoordinates) {
                            _animateMapTo(setupState.latitude!, setupState.longitude!);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.border,
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${radius}km',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Continue CTA Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleContinue,
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
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text('→', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip
              Center(
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.setupInterests),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar({required double progress}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              height: 4,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              height: 4,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}
