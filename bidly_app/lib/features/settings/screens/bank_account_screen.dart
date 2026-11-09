import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  String _accountNumber = '';
  String _ifscCode = '';
  String _upiId = '';
  String _bankName = 'Primary Bank';
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accountNumber = prefs.getString('payout_account_number') ?? '•••• •••• •••• 8789';
      _ifscCode = prefs.getString('payout_ifsc_code') ?? 'HDFC0001234';
      _upiId = prefs.getString('payout_upi_id') ?? '';
      _bankName = prefs.getString('payout_bank_name') ?? 'HDFC Bank';
      _isLoaded = true;
    });
  }

  Future<void> _saveBankDetails({
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String upiId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payout_bank_name', bankName);
    await prefs.setString('payout_account_number', accountNumber);
    await prefs.setString('payout_ifsc_code', ifscCode);
    await prefs.setString('payout_upi_id', upiId);

    setState(() {
      _bankName = bankName;
      _accountNumber = accountNumber;
      _ifscCode = ifscCode;
      _upiId = upiId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payout details saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _showUpdateBankModal(BuildContext context, String currentHolder) {
    final bankNameCtrl = TextEditingController(text: _bankName == 'Primary Bank' ? '' : _bankName);
    final accountCtrl = TextEditingController(text: _accountNumber.contains('•') ? '' : _accountNumber);
    final ifscCtrl = TextEditingController(text: _ifscCode.contains('•') ? '' : _ifscCode);
    final upiCtrl = TextEditingController(text: _upiId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Payout Details',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Funds from won auctions and sales will be deposited here.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              _buildModalTextField('Bank Name', bankNameCtrl, 'e.g. HDFC Bank, SBI, ICICI'),
              const SizedBox(height: 12),
              _buildModalTextField('Account Number', accountCtrl, 'Enter bank account number', isNumber: true),
              const SizedBox(height: 12),
              _buildModalTextField('IFSC Code', ifscCtrl, 'e.g. HDFC0001234'),
              const SizedBox(height: 12),
              _buildModalTextField('UPI ID (Optional)', upiCtrl, 'e.g. yourname@okhdfcbank'),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final acc = accountCtrl.text.trim();
                    final ifsc = ifscCtrl.text.trim().toUpperCase();
                    final bank = bankNameCtrl.text.trim().isEmpty ? 'Primary Bank' : bankNameCtrl.text.trim();
                    final upi = upiCtrl.text.trim();

                    if (acc.isEmpty || ifsc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter valid Account Number and IFSC Code')),
                      );
                      return;
                    }

                    // Format masked display if long
                    final displayAcc = acc.length > 4 ? '•••• •••• •••• ${acc.substring(acc.length - 4)}' : acc;

                    Navigator.pop(ctx);
                    _saveBankDetails(
                      bankName: bank,
                      accountNumber: displayAcc,
                      ifscCode: ifsc,
                      upiId: upi,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Verify Details', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField(String label, TextEditingController controller, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF004E54), width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final accountHolder = (user?.name != null && user!.name!.isNotEmpty)
        ? user.name!
        : (user?.phone != null && user!.phone.isNotEmpty ? '+91 ${user.phone}' : 'Account Holder');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } else { Navigator.of(context).maybePop(); } },
        ),
        title: const Text(
          'Bank Account',
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAYOUT ACCOUNT',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F6F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.account_balance_rounded, color: Color(0xFF004E54), size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bankName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Savings Account • Verified for Payouts',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppTheme.border),
                    const SizedBox(height: 14),
                    _buildFieldRow('Account Holder', accountHolder),
                    const SizedBox(height: 10),
                    _buildFieldRow('Account Number', _accountNumber, isMonospace: true),
                    const SizedBox(height: 10),
                    _buildFieldRow('IFSC Code', _ifscCode, isMonospace: true),
                    if (_upiId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildFieldRow('UPI ID', _upiId),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _showUpdateBankModal(context, accountHolder),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF004E54)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Update Bank Details',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF004E54)),
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

  Widget _buildFieldRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: isMonospace ? 'monospace' : 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
