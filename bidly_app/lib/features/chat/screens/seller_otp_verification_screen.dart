import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import 'seller_otp_verified_screen.dart';

class SellerOtpVerificationScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String? buyerName;
  final String? meetupTime;
  final String? meetupLocation;
  final String? productTitle;
  final double? productPrice;
  final String? productImageUrl;

  const SellerOtpVerificationScreen({
    super.key,
    required this.orderId,
    this.buyerName,
    this.meetupTime,
    this.meetupLocation,
    this.productTitle,
    this.productPrice,
    this.productImageUrl,
  });

  @override
  ConsumerState<SellerOtpVerificationScreen> createState() => _SellerOtpVerificationScreenState();
}

class _SellerOtpVerificationScreenState extends ConsumerState<SellerOtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;

  String _buyerName = '';
  String _meetupTime = '';
  String _meetupLocation = '';
  String _productTitle = '';
  double _productPrice = 0.0;
  String? _productImageUrl;

  @override
  void initState() {
    super.initState();
    _buyerName = widget.buyerName ?? '';
    _meetupTime = widget.meetupTime ?? '';
    _meetupLocation = widget.meetupLocation ?? '';
    _productTitle = widget.productTitle ?? '';
    _productPrice = widget.productPrice ?? 0.0;
    _productImageUrl = widget.productImageUrl;
    if (_buyerName.isEmpty || _productTitle.isEmpty || _meetupLocation.isEmpty) {
      _fetchOrderDetails();
    }
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.get('/orders/${widget.orderId}');
      if (res.data != null && res.data['success'] == true && res.data['data'] != null) {
        final data = Map<String, dynamic>.from(res.data['data'] as Map);
        if (mounted) {
          setState(() {
            _buyerName = data['buyerName']?.toString() ?? _buyerName;
            _productTitle = data['productTitle']?.toString() ?? _productTitle;
            _productPrice = (data['totalAmount'] is num) ? (data['totalAmount'] as num).toDouble() : _productPrice;
            _productImageUrl = data['productImageUrl']?.toString() ?? _productImageUrl;
            _meetupLocation = data['meetupLocation']?.toString() ?? _meetupLocation;
            _meetupTime = data['meetupTimeFormatted']?.toString() ?? _meetupTime;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        '/orders/${widget.orderId}/verify-otp',
        data: {'otp': otp},
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => SellerOtpVerifiedScreen(
              orderId: widget.orderId,
              buyerName: _buyerName,
              productTitle: _productTitle,
              productPrice: _productPrice,
              productImageUrl: _productImageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Widget _buildDigitInput(int index) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF004E54),
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF7FAFA),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF004E54), width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_enteredOtp.length == 6) {
            _verifyOtp();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyer = _buyerName.isNotEmpty ? _buyerName : 'Buyer';
    final meeting = _meetupLocation.isNotEmpty
        ? (_meetupTime.isNotEmpty ? '$_meetupLocation · $_meetupTime' : _meetupLocation)
        : (_meetupTime.isNotEmpty ? _meetupTime : 'Meetup');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border.withValues(alpha: 0.7), height: 1),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Subtitle
              const Text(
                'OTP Verification',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ask the buyer to share the OTP sent to their registered number.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Buyer Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFE0F2F1),
                      child: Text(
                        buyer.isNotEmpty ? buyer[0].toUpperCase() : 'B',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF004E54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BUYER: $buyer',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Meeting at $meeting',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Enter OTP Label
              const Text(
                'Enter OTP shared by buyer',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // 6 Digits Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildDigitInput(i)),
              ),
              const SizedBox(height: 14),

              // Error Message if any
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const Spacer(),

              // Verify OTP Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
