import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/app_theme.dart';
import 'product_sold_success_screen.dart';

class SellerOtpVerifiedScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String buyerName;
  final String productTitle;
  final double productPrice;
  final String? productImageUrl;

  const SellerOtpVerifiedScreen({
    super.key,
    required this.orderId,
    required this.buyerName,
    required this.productTitle,
    required this.productPrice,
    this.productImageUrl,
  });

  @override
  ConsumerState<SellerOtpVerifiedScreen> createState() => _SellerOtpVerifiedScreenState();
}

class _SellerOtpVerifiedScreenState extends ConsumerState<SellerOtpVerifiedScreen> {
  bool _isMarkingSold = false;
  String? _errorMessage;

  late String _buyerName;
  late String _productTitle;
  late double _productPrice;
  late String? _productImageUrl;

  @override
  void initState() {
    super.initState();
    _buyerName = widget.buyerName;
    _productTitle = widget.productTitle;
    _productPrice = widget.productPrice;
    _productImageUrl = widget.productImageUrl;
    if (_buyerName.isEmpty || _productTitle.isEmpty || _productPrice == 0.0) {
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
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _markAsSold() async {
    setState(() {
      _isMarkingSold = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.post('/orders/${widget.orderId}/mark-sold');

      if (mounted) {
        Map<String, dynamic> summary = {};
        if (res.data != null && res.data['data'] != null) {
          summary = Map<String, dynamic>.from(res.data['data'] as Map);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => ProductSoldSuccessScreen(
              orderId: widget.orderId,
              productTitle: _productTitle,
              buyerName: _buyerName,
              productPrice: _productPrice,
              transactionId: summary['transactionId']?.toString() ?? summary['orderNumber']?.toString() ?? '',
              dateFormatted: summary['saleDateFormatted']?.toString() ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMarkingSold = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Green Verified Circle
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: Color(0xFF2E7D32),
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'OTP Verified',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Buyer identity confirmed. Confirm the transaction by marking this product as sold.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Product Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FBFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(10),
                        image: _productImageUrl != null && _productImageUrl!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_productImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _productImageUrl == null || _productImageUrl!.isEmpty
                          ? const Center(
                              child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF004E54)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productTitle.isNotEmpty ? _productTitle : 'Product',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Buyer: ${_buyerName.isNotEmpty ? _buyerName : 'Buyer'} · ₹${_productPrice.toStringAsFixed(0)}',
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

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
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

              const Spacer(flex: 2),

              // Mark as Sold Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isMarkingSold ? null : _markAsSold,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isMarkingSold
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Mark as Sold',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),

              // Warning / note
              const Text(
                'This action is final and cannot be undone',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
