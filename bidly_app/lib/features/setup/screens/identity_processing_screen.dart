import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/setup_provider.dart';

class IdentityProcessingScreen extends ConsumerStatefulWidget {
  const IdentityProcessingScreen({super.key});

  @override
  ConsumerState<IdentityProcessingScreen> createState() => _IdentityProcessingScreenState();
}

class _IdentityProcessingScreenState extends ConsumerState<IdentityProcessingScreen> {
  int _step = 0; // 0: initial, 1: fetched aadhaar, 2: cross-checked, 3: trust score & done
  Timer? _t1;
  Timer? _t2;
  Timer? _t3;
  Timer? _t4;

  @override
  void initState() {
    super.initState();
    _startVerificationSequence();
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    _t4?.cancel();
    super.dispose();
  }

  void _startVerificationSequence() {
    _t1 = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _step = 1);
    });

    _t2 = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _step = 2);
    });

    _t3 = Timer(const Duration(milliseconds: 2700), () async {
      if (!mounted) return;
      setState(() => _step = 3);

      // Trigger backend API call to persist verified status
      await ref.read(setupProvider.notifier).verifyDigiLocker();

      if (!mounted) return;
      _t4 = Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          context.go(AppRoutes.setupLocation);
        }
      });
    });
  }

  void _navigateBack() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    _t4?.cancel();
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.setupIdentity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _navigateBack,
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
              ),
              const Spacer(flex: 1),

              // Animated Circular Ring
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(4),
                child: const CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  backgroundColor: AppTheme.border,
                ),
              ),
              const SizedBox(height: 32),

              // Heading
              const Text(
                'Verifying your identity...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Connecting to DigiLocker servers. This usually takes a few seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 48),

              // Verification Steps
              _buildStepCard(
                title: 'Fetching Aadhaar details',
                isCompleted: _step >= 1,
                isActive: _step == 0,
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                title: 'Cross-checking records',
                isCompleted: _step >= 2,
                isActive: _step == 1,
              ),
              const SizedBox(height: 12),

              _buildStepCard(
                title: 'Generating trust score',
                isCompleted: _step >= 3,
                isActive: _step == 2,
                isFinalStep: true,
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String title,
    required bool isCompleted,
    required bool isActive,
    bool isFinalStep = false,
  }) {
    final isHighlighted = (isFinalStep && (isActive || isCompleted)) || isCompleted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.primarySoft : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              color: isHighlighted ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
          if (isCompleted)
            const Icon(
              Icons.check_rounded,
              color: AppTheme.primary,
              size: 18,
            )
          else if (isActive)
            const Text(
              '...',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
