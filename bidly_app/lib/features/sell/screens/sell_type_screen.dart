import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../providers/sell_provider.dart';

class SellTypeScreen extends ConsumerStatefulWidget {
  const SellTypeScreen({super.key});

  @override
  ConsumerState<SellTypeScreen> createState() => _SellTypeScreenState();
}

class _SellTypeScreenState extends ConsumerState<SellTypeScreen> {
  late final TextEditingController _minBidController;
  late final TextEditingController _incrementController;
  late final TextEditingController _endDateController;
  late final TextEditingController _endTimeController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(sellProvider);
    _minBidController = TextEditingController(
      text: state.minimumBid != null && state.minimumBid! > 0
          ? state.minimumBid!.toStringAsFixed(0)
          : (state.price > 0 ? state.price.toStringAsFixed(0) : '49994'),
    );
    _incrementController = TextEditingController(
      text: state.bidIncrement != null && state.bidIncrement! > 0
          ? state.bidIncrement!.toStringAsFixed(0)
          : '1000',
    );

    final futureDate = DateTime.now().add(const Duration(days: 7));
    _endDateController = TextEditingController(
      text: state.auctionEndDate ?? DateFormat('yyyy-MM-dd').format(futureDate),
    );
    _endTimeController = TextEditingController(
      text: state.auctionEndTime ?? '02:00 PM',
    );
  }

  @override
  void dispose() {
    _minBidController.dispose();
    _incrementController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004E54),
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _endDateController.text = formatted;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 14, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF004E54),
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final formatted = picked.format(context);
      setState(() {
        _endTimeController.text = formatted;
      });
    }
  }

  DateTime? _parseCombinedDateTime(String dateStr, String timeStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      int hour = 18;
      int minute = 0;

      final cleanTime = timeStr.trim().toUpperCase();
      final isPm = cleanTime.contains('PM');
      final isAm = cleanTime.contains('AM');
      final rawDigits = cleanTime.replaceAll(RegExp(r'[^\d:]'), '').trim();
      final timeParts = rawDigits.split(':');

      if (timeParts.isNotEmpty) {
        hour = int.parse(timeParts[0]);
        if (timeParts.length > 1) {
          minute = int.parse(timeParts[1]);
        }
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
      }

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  void _handlePreview() {
    final isBid = ref.read(sellProvider).sellingMethod == 'AUCTION';

    if (isBid) {
      final minBid = double.tryParse(_minBidController.text.trim()) ?? 0.0;
      final increment = double.tryParse(_incrementController.text.trim()) ?? 100.0;

      if (minBid <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid minimum bid'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      final endDateStr = _endDateController.text.trim();
      final endTimeStr = _endTimeController.text.trim();

      final combined = _parseCombinedDateTime(endDateStr, endTimeStr);
      if (combined == null || combined.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auction end date and time must be set in the future'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      ref.read(sellProvider.notifier).setBidSettings(
            minimumBid: minBid,
            bidIncrement: increment,
            endDate: endDateStr,
            endTime: endTimeStr,
          );
    }

    context.push(AppRoutes.sellPreview);
  }

  @override
  Widget build(BuildContext context) {
    final sellState = ref.watch(sellProvider);
    final isAuction = sellState.sellingMethod == 'AUCTION';

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
          'Sell Type',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Step 3/4',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004E54),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: 0.75,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How do you want to sell?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Side-by-Side [ Direct Sale ] and [ Bid ] Cards
              Row(
                children: [
                  // Direct Sale Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(sellProvider.notifier).setSellingMethod('DIRECT_BUY'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                        decoration: BoxDecoration(
                          color: !isAuction ? const Color(0xFFE6F4F1).withValues(alpha: 0.6) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !isAuction ? const Color(0xFF004E54) : AppTheme.border,
                            width: !isAuction ? 1.8 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Direct Sale',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: !isAuction ? const Color(0xFF004E54) : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fixed price, instant buy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                color: !isAuction ? const Color(0xFF004E54) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Bid Auction Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => ref.read(sellProvider.notifier).setSellingMethod('AUCTION'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isAuction ? const Color(0xFFE6F4F1).withValues(alpha: 0.6) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAuction ? const Color(0xFF004E54) : AppTheme.border,
                            width: isAuction ? 1.8 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Bid',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isAuction ? const Color(0xFF004E54) : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auction to highest bidder',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                color: isAuction ? const Color(0xFF004E54) : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // If Auction / Bid chosen: Bid Settings Form
              if (isAuction) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bid Settings',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E232A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Set your starting price, increment and duration',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Minimum Bid
                      _buildFieldLabel('Minimum Bid (₹) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _minBidController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E232A),
                        ),
                        decoration: _buildInputDecoration(
                          hintText: 'e.g. 5000',
                          prefixText: '₹ ',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bid Increment
                      _buildFieldLabel('Bid Increment (₹) *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _incrementController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E232A),
                        ),
                        decoration: _buildInputDecoration(
                          hintText: 'e.g. 500',
                          prefixText: '₹ ',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // End Date & End Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('End Date *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _endDateController,
                                  readOnly: true,
                                  onTap: _selectEndDate,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E232A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hintText: 'YYYY-MM-DD',
                                    suffixIcon: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: Color(0xFF004E54),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('End Time *'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _endTimeController,
                                  readOnly: true,
                                  onTap: _selectEndTime,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E232A),
                                  ),
                                  decoration: _buildInputDecoration(
                                    hintText: 'HH:MM AM/PM',
                                    suffixIcon: const Icon(
                                      Icons.access_time_rounded,
                                      size: 18,
                                      color: Color(0xFF004E54),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Preview Listing Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handlePreview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Preview Listing',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
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

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E232A),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    String? prefixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13.5,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: Color(0xFF1E232A),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF004E54), width: 1.8),
      ),
    );
  }
}
