import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_theme.dart';
import '../../community/providers/community_provider.dart';
import '../providers/sell_provider.dart';

class SellingScopeScreen extends ConsumerWidget {
  const SellingScopeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellState = ref.watch(sellProvider);
    final selectedScope = sellState.sellingScope;

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
          'Selling Scope',
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
              'Step 2/4',
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
            value: 0.50,
            backgroundColor: Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004E54)),
            minHeight: 3,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Where should your listing appear?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Global (Home screen marketplace)
              _buildScopeOption(
                context: context,
                ref: ref,
                icon: Icons.public_rounded,
                title: 'Global Marketplace (Home Screen)',
                subtitle: 'Visible to everyone on the Bidly Home screen for all users to discover',
                value: 'GLOBAL',
                isSelected: selectedScope == 'GLOBAL',
              ),
              const SizedBox(height: 14),

              // Option 2: Community Only
              _buildScopeOption(
                context: context,
                ref: ref,
                icon: Icons.groups_rounded,
                title: 'Community Only',
                subtitle: 'Visible only to members inside this specific community feed',
                value: 'COMMUNITIES',
                isSelected: selectedScope == 'COMMUNITIES',
              ),

              if (selectedScope == 'COMMUNITIES') ...[
                const SizedBox(height: 14),
                Consumer(
                  builder: (context, refWatch, _) {
                    final commState = refWatch.watch(communityProvider);
                    final myCommunities = commState.myCommunities;
                    final currentId = sellState.communityId;
                    final currentName = sellState.communityName ?? (myCommunities.isNotEmpty ? myCommunities.first.name : 'Select Community');

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4F1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.groups_rounded, color: Color(0xFF004E54), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Select Target Community',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF004E54),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: myCommunities.any((c) => c.id == currentId)
                                    ? currentId
                                    : (myCommunities.isNotEmpty ? myCommunities.first.id : null),
                                hint: Text(
                                  currentName,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600),
                                ),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF004E54)),
                                items: myCommunities.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF004E54)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newId) {
                                  if (newId != null) {
                                    final found = myCommunities.firstWhere((c) => c.id == newId);
                                    ref.read(sellProvider.notifier).setCommunity(
                                      communityId: found.id,
                                      communityName: found.name,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Only members of this community will be able to view and interact with this post.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),

              // Option 3: Custom Radius
              _buildScopeOption(
                context: context,
                ref: ref,
                icon: Icons.radar_rounded,
                title: 'Custom Radius',
                subtitle: 'Target buyers within a specific distance',
                value: 'CUSTOM_RADIUS',
                isSelected: selectedScope == 'CUSTOM_RADIUS',
              ),

              if (selectedScope == 'CUSTOM_RADIUS') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF004E54).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Target Radius',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF004E54),
                            ),
                          ),
                          Text(
                            '${sellState.targetRadiusKm} km',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF004E54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [5, 10, 25, 50].map((radius) {
                          final isSel = sellState.targetRadiusKm == radius;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: GestureDetector(
                                onTap: () => ref.read(sellProvider.notifier).setSellingScope('CUSTOM_RADIUS', radiusKm: radius),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF004E54) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF004E54) : AppTheme.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${radius}km',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSel ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.sellType),
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
                        'Continue',
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
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeOption({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => ref.read(sellProvider.notifier).setSellingScope(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F4F1).withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF004E54) : AppTheme.border,
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE6F4F1) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? const Color(0xFF004E54) : AppTheme.textPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? const Color(0xFF004E54) : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF004E54) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF004E54) : AppTheme.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
