import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _messages = true;
  bool _bidUpdates = true;
  bool _orderUpdates = true;
  bool _wishlist = false;
  bool _promotions = true;
  bool _news = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messages = prefs.getBool('notif_messages') ?? true;
      _bidUpdates = prefs.getBool('notif_bids') ?? true;
      _orderUpdates = prefs.getBool('notif_orders') ?? true;
      _wishlist = prefs.getBool('notif_wishlist') ?? false;
      _promotions = prefs.getBool('notif_promotions') ?? true;
      _news = prefs.getBool('notif_news') ?? false;
      _isLoaded = true;
    });
  }

  Future<void> _updatePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
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
          onPressed: () { if (Navigator.of(context).canPop()) { Navigator.of(context).pop(); } else if (context.canPop()) { context.pop(); } else { Navigator.of(context).maybePop(); } },
        ),
        title: const Text(
          'Notification Preferences',
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
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            const Text(
              'NOTIFICATIONS',
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildToggleRow(
                    'Messages',
                    _messages ? 'ON' : 'OFF',
                    Icons.chat_bubble_outline_rounded,
                    _messages,
                    (v) {
                      setState(() => _messages = v);
                      _updatePref('notif_messages', v);
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  _buildToggleRow(
                    'Bid Updates',
                    _bidUpdates ? 'ON' : 'OFF',
                    Icons.gavel_rounded,
                    _bidUpdates,
                    (v) {
                      setState(() => _bidUpdates = v);
                      _updatePref('notif_bids', v);
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  _buildToggleRow(
                    'Order Updates',
                    _orderUpdates ? 'ON' : 'OFF',
                    Icons.inventory_2_outlined,
                    _orderUpdates,
                    (v) {
                      setState(() => _orderUpdates = v);
                      _updatePref('notif_orders', v);
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  _buildToggleRow(
                    'Wishlist',
                    _wishlist ? 'ON' : 'OFF',
                    Icons.favorite_border_rounded,
                    _wishlist,
                    (v) {
                      setState(() => _wishlist = v);
                      _updatePref('notif_wishlist', v);
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  _buildToggleRow(
                    'Promotions',
                    _promotions ? 'ON' : 'OFF',
                    Icons.star_outline_rounded,
                    _promotions,
                    (v) {
                      setState(() => _promotions = v);
                      _updatePref('notif_promotions', v);
                    },
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  _buildToggleRow(
                    'News & Updates',
                    _news ? 'ON' : 'OFF',
                    Icons.notifications_none_rounded,
                    _news,
                    (v) {
                      setState(() => _news = v);
                      _updatePref('notif_news', v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String status,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF004E54), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: value ? const Color(0xFF004E54) : AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF004E54),
          ),
        ],
      ),
    );
  }
}
