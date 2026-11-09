import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  String? _selectedIssueType = 'Payment / Wallet Issue';
  final _descriptionController = TextEditingController();
  XFile? _selectedScreenshot;

  final List<String> _issueTypes = [
    'Payment / Wallet Issue',
    'Auction / Bidding Dispute',
    'Order Delivery / Meetup Issue',
    'Product Not as Described',
    'Account & Login Problem',
    'Other Issue',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null && mounted) {
        setState(() {
          _selectedScreenshot = picked;
        });
      }
    } catch (_) {}
  }

  void _handleSubmit() {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description of the issue')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Problem report submitted! Our support team will respond shortly.'),
        backgroundColor: AppTheme.success,
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (context.canPop()) {
              context.pop();
            }
          },
        ),
        title: const Text(
          'Report a Problem',
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Issue Type',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedIssueType,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
                    items: _issueTypes.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(
                          t,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppTheme.textPrimary),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedIssueType = val),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Description',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                maxLength: 500,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppTheme.textPrimary),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Describe the problem in detail. Include order IDs, dates, or any relevant information...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Upload Screenshot',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickScreenshot,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _selectedScreenshot != null ? const Color(0xFF10B981) : AppTheme.border),
                  ),
                  child: _selectedScreenshot != null
                      ? Column(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 32, color: Color(0xFF10B981)),
                            const SizedBox(height: 6),
                            Text(
                              _selectedScreenshot!.name,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text('Tap to change image', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF10B981))),
                          ],
                        )
                      : Column(
                          children: const [
                            Icon(Icons.upload_outlined, size: 28, color: Color(0xFF004E54)),
                            SizedBox(height: 8),
                            Text(
                              'Tap to upload screenshot',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'PNG, JPG up to 5MB',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Submit Report',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w600),
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
}
