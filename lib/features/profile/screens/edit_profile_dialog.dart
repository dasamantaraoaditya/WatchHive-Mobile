import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final User user;
  final VoidCallback onSaved;

  const EditProfileDialog({
    super.key,
    required this.user,
    required this.onSaved,
  });

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late final TextEditingController _bioController;
  late String _privacyLevel;
  late bool _showWatchEntries;
  late bool _showCurrentlyWatching;
  late bool _showWatchlist;
  late bool _showRankings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _privacyLevel = widget.user.privacyLevel;
    _showWatchEntries = widget.user.showWatchEntries;
    _showCurrentlyWatching = widget.user.showCurrentlyWatching;
    _showWatchlist = widget.user.showWatchlist;
    _showRankings = widget.user.showRankings;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put(
        ApiEndpoints.updateProfile(widget.user.id),
        data: {
          'bio': _bioController.text.trim(),
          'privacyLevel': _privacyLevel,
          'showWatchEntries': _showWatchEntries,
          'showCurrentlyWatching': _showCurrentlyWatching,
          'showWatchlist': _showWatchlist,
          'showRankings': _showRankings,
        },
      );

      final updatedUser = User(
        id: widget.user.id,
        username: widget.user.username,
        displayName: widget.user.displayName,
        profilePictureUrl: widget.user.profilePictureUrl,
        bio: _bioController.text.trim(),
        location: widget.user.location,
        isPrivate: _privacyLevel == 'PRIVATE' || _privacyLevel == 'FOLLOWERS_ONLY',
        privacyLevel: _privacyLevel,
        showWatchEntries: _showWatchEntries,
        showCurrentlyWatching: _showCurrentlyWatching,
        showWatchlist: _showWatchlist,
        showRankings: _showRankings,
        xp: widget.user.xp,
        level: widget.user.level,
        badges: widget.user.badges,
        createdAt: widget.user.createdAt,
      );
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile settings updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Settings',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'BIO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Share a bit about your cinema taste...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'PRIVACY TIER',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _privacyLevel,
              dropdownColor: AppColors.cardBg,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('🌐 Public (Everyone can see)')),
                DropdownMenuItem(value: 'FOLLOWERS_ONLY', child: Text('👥 Followers Only')),
                DropdownMenuItem(value: 'PRIVATE', child: Text('🔒 Strictly Private')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _privacyLevel = val);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'TAB VISIBILITY SWITCHES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.textMuted, letterSpacing: 1.0),
            ),
            SwitchListTile(
              activeColor: AppColors.primary,
              title: const Text('Show Watch Log Entries', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              value: _showWatchEntries,
              onChanged: (v) => setState(() => _showWatchEntries = v),
            ),
            SwitchListTile(
              activeColor: AppColors.primary,
              title: const Text('Show Currently Watching', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              value: _showCurrentlyWatching,
              onChanged: (v) => setState(() => _showCurrentlyWatching = v),
            ),
            SwitchListTile(
              activeColor: AppColors.primary,
              title: const Text('Show Watchlist', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              value: _showWatchlist,
              onChanged: (v) => setState(() => _showWatchlist = v),
            ),
            SwitchListTile(
              activeColor: AppColors.primary,
              title: const Text('Show Ranking Stacks', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              value: _showRankings,
              onChanged: (v) => setState(() => _showRankings = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Save Changes', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
