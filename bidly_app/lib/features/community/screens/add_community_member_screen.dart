import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../models/community_model.dart';
import '../providers/community_provider.dart';

class AddCommunityMemberScreen extends ConsumerStatefulWidget {
  final CommunityModel community;

  const AddCommunityMemberScreen({super.key, required this.community});

  @override
  ConsumerState<AddCommunityMemberScreen> createState() =>
      _AddCommunityMemberScreenState();
}

class _AddCommunityMemberScreenState
    extends ConsumerState<AddCommunityMemberScreen> {
  bool _isLoadingContacts = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  /// Bidly users matched from device contacts { id, name, phone, avatarUrl }
  List<Map<String, dynamic>> _bidlyUsers = [];

  /// Members already in the community (normalized phone numbers)
  final Set<String> _alreadyAddedPhones = {};

  @override
  void initState() {
    super.initState();
    // Pre-populate already-added phones from current members
    for (final m in ref.read(communityProvider).members) {
      if (m.phone.isNotEmpty) {
        _alreadyAddedPhones.add(_normalizePhone(m.phone));
      }
    }
    _loadContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length > 10 ? cleaned.substring(cleaned.length - 10) : cleaned;
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoadingContacts = true);

    // Request read permission via flutter_contacts v2.1.0 API
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;

    if (!granted) {
      if (mounted) {
        setState(() => _isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts permission denied. Grant access in Settings to find friends on Bidly.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }

    // Fetch contacts with name + phone properties
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();

    if (mounted) {
      setState(() => _isLoadingContacts = false);
    }

    await _syncWithBackend(withPhones);
  }

  Future<void> _syncWithBackend(List<Contact> contacts) async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    // Build a map of normalized phone → contact display name
    final phoneToName = <String, String>{};
    final allPhones = <String>[];
    for (final c in contacts) {
      for (final p in c.phones) {
        final norm = _normalizePhone(p.number);
        if (norm.isNotEmpty) {
          allPhones.add(norm);
          phoneToName.putIfAbsent(norm, () => (c.displayName?.isNotEmpty == true ? c.displayName! : norm));
        }
      }
    }

    // Deduplicate
    final uniquePhones = allPhones.toSet().toList();

    // Call backend in batches of 100
    final results = <Map<String, dynamic>>[];
    for (int i = 0; i < uniquePhones.length; i += 100) {
      final end = (i + 100 < uniquePhones.length) ? i + 100 : uniquePhones.length;
      final batch = uniquePhones.sublist(i, end);
      final batchResults = await ref.read(communityProvider.notifier).syncContacts(batch);
      results.addAll(batchResults);
    }

    // Enrich with device contact display name
    final enriched = results.map((user) {
      final phone = _normalizePhone(user['phone']?.toString() ?? '');
      final contactName = phoneToName[phone];
      return {
        ...user,
        'contactDisplayName': contactName ?? (user['name'] as String? ?? ''),
      };
    }).toList();

    if (mounted) {
      setState(() {
        _bidlyUsers = enriched;
        _isSyncing = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _bidlyUsers;
    final q = _searchQuery.toLowerCase();
    return _bidlyUsers.where((u) {
      final name = (u['contactDisplayName'] ?? u['name'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _addMember(Map<String, dynamic> user) async {
    final phone = user['phone']?.toString() ?? '';
    if (phone.isEmpty) return;

    final normalizedPhone = _normalizePhone(phone);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref.read(communityProvider.notifier).addMember(
          communityId: widget.community.id,
          phone: normalizedPhone,
        );

    if (!mounted) return;

    if (ok) {
      setState(() => _alreadyAddedPhones.add(normalizedPhone));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${user['contactDisplayName'] ?? user['name']} added to ${widget.community.name}!',
          ),
          backgroundColor: const Color(0xFF004E54),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not add member. They may already be a member.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E232A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Members',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E232A),
              ),
            ),
            Text(
              widget.community.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                hintStyle: const TextStyle(fontFamily: 'Poppins', color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Syncing banner
          if (_isSyncing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004E54)),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Finding your contacts on Bidly…',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        color: Color(0xFF004E54),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Content
          Expanded(
            child: _isLoadingContacts
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF004E54)))
                : _bidlyUsers.isEmpty && !_isSyncing
                    ? _buildEmptyState()
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              'No Bidly users match "$_searchQuery"',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          )
                        : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contacts_outlined, color: Color(0xFF004E54), size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'No contacts on Bidly',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E232A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'None of your phone contacts have a Bidly account yet. Invite them to join!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Refresh',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF004E54),
              side: const BorderSide(color: Color(0xFF004E54)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _loadContacts,
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredUsers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final phone = _normalizePhone(user['phone']?.toString() ?? '');
        final isAdded = _alreadyAddedPhones.contains(phone);
        final displayName = (user['contactDisplayName'] as String? ?? user['name'] as String? ?? 'Unknown');
        final initials = displayName.length >= 2
            ? displayName.substring(0, 2).toUpperCase()
            : displayName.toUpperCase();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          leading: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4F1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF004E54),
                ),
              ),
            ),
          ),
          title: Text(
            displayName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E232A),
            ),
          ),
          subtitle: Text(
            user['phone']?.toString() ?? '',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          trailing: isAdded
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Added',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004E54),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: () => _addMember(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004E54),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 0,
                    minimumSize: const Size(72, 34),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Add'),
                ),
        );
      },
    );
  }
}
