import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/user_repository.dart';
import '../widgets/data_management_card.dart';
import '../../../core/utils/error_handler.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final User user;
  final VoidCallback onSaved;

  const EditProfileDialog({
    super.key,
    required this.user,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required User user,
    required VoidCallback onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditProfileDialog(
        user: user,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  int _selectedTabIndex = 0; // 0: Profile Info, 1: Privacy & Visibility, 2: Account & Data

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _passwordController;

  late String _privacyLevel;
  late bool _showWatchEntries;
  late bool _showCurrentlyWatching;
  late bool _showWatchlist;
  late bool _showRankings;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isSettingPassword = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController(text: widget.user.location ?? '');
    _passwordController = TextEditingController();

    _privacyLevel = widget.user.privacyLevel;
    _showWatchEntries = widget.user.showWatchEntries;
    _showCurrentlyWatching = widget.user.showCurrentlyWatching;
    _showWatchlist = widget.user.showWatchlist;
    _showRankings = widget.user.showRankings;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final updatedUser = await ref.read(userRepositoryProvider).uploadAvatar(image);
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        WHAlert.showSuccess(context, 'Profile picture updated! 📸');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to upload image. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await WHAlert.confirm(
      context,
      title: 'Remove Profile Picture',
      message: 'Are you sure you want to remove your profile picture?',
      confirmText: 'Remove',
      severity: WHAlertSeverity.danger,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirm) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref.read(userRepositoryProvider).deleteAvatar();
      final updatedUser = widget.user.copyWith(clearProfilePicture: true);
      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        WHAlert.showSuccess(context, 'Profile picture removed');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to remove image. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();
      final location = _locationController.text.trim();

      final updatedUser = await repo.updateProfile(
        widget.user.id,
        {
          'displayName': displayName.isNotEmpty ? displayName : '',
          'bio': bio,
          'location': location.isNotEmpty ? location : null,
          'privacyLevel': _privacyLevel,
          'isPrivate': _privacyLevel == 'PRIVATE',
          'showWatchEntries': _showWatchEntries,
          'showCurrentlyWatching': _showCurrentlyWatching,
          'showWatchlist': _showWatchlist,
          'showRankings': _showRankings,
        },
      );

      ref.read(authStateProvider.notifier).updateUser(updatedUser);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        WHAlert.showSuccess(context, 'Profile updated successfully! ✨');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to update profile. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSetPassword() async {
    final password = _passwordController.text.trim();
    if (password.length < 8) {
      WHAlert.showWarning(context, 'Password must be at least 8 characters');
      return;
    }

    setState(() => _isSettingPassword = true);
    try {
      await ref.read(userRepositoryProvider).setPassword(password);
      if (mounted) {
        _passwordController.clear();
        WHAlert.showSuccess(context, 'Backup password successfully set! 🔒');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to set password. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value?.user ?? widget.user;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Edit Profile & Settings',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Categorized Segmented Tabs (Profile Info | Privacy & Tabs | Security & Data)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'Profile', Icons.person_outline_rounded),
                  _buildTabButton(1, 'Privacy', Icons.lock_outline_rounded),
                  _buildTabButton(2, 'Security', Icons.shield_outlined),
                ],
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _selectedTabIndex == 0
                  ? _buildProfileInfoTab(currentUser)
                  : _selectedTabIndex == 1
                      ? _buildPrivacyTab()
                      : _buildSecurityDataTab(currentUser),
            ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 18, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'Save Changes',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.black : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 1: Profile Info
  Widget _buildProfileInfoTab(User currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar section
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: WHAvatar(
                  imageUrl: currentUser.profilePictureUrl,
                  name: currentUser.name,
                  radius: 46,
                ),
              ),
              if (_isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: const Center(
                      child: WHSkeleton(
                        child: WHSkeletonBox(width: 44, height: 44, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.black),
                  ),
                ),
              ),
              if (currentUser.profilePictureUrl != null && currentUser.profilePictureUrl!.isNotEmpty)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _removeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Tap the camera icon to upload a photo',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 24),

        // Display Name
        const Text(
          'DISPLAY NAME',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameController,
          maxLength: 50,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Your name or cinephile alias',
            filled: true,
            fillColor: AppColors.surface,
            counterText: '',
            prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: AppColors.primary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bio
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BIO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _bioController,
              builder: (context, value, child) {
                return Text(
                  '${value.text.length}/500',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Share your cinematic taste, favorite directors, or streaming habits...',
            filled: true,
            fillColor: AppColors.surface,
            counterText: '',
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Location
        const Text(
          'LOCATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _locationController,
          maxLength: 80,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'City, Country (e.g. San Francisco, USA)',
            filled: true,
            fillColor: AppColors.surface,
            counterText: '',
            prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // TAB 2: Privacy & Tabs
  Widget _buildPrivacyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROFILE PRIVACY TIER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose who can see your profile details, watch history, and ranked stacks.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        _buildPrivacyTierCards(),
        const SizedBox(height: 24),

        if (_privacyLevel != 'PRIVATE') ...[
          const Text(
            'TAB VISIBILITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Control individual tabs visible to others on your public profile.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.history_rounded,
                  title: 'Show Watch History',
                  subtitle: 'Display your logged movies and series',
                  value: _showWatchEntries,
                  onChanged: (v) => setState(() => _showWatchEntries = v),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSwitchTile(
                  icon: Icons.visibility_rounded,
                  title: 'Currently Watching',
                  subtitle: 'Show what you are currently streaming',
                  value: _showCurrentlyWatching,
                  onChanged: (v) => setState(() => _showCurrentlyWatching = v),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSwitchTile(
                  icon: Icons.list_alt_rounded,
                  title: 'Show Watchlist',
                  subtitle: 'Let friends view your saved picks',
                  value: _showWatchlist,
                  onChanged: (v) => setState(() => _showWatchlist = v),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSwitchTile(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'Show Ranked Stacks',
                  subtitle: 'Allow others to see your curated rankings',
                  value: _showRankings,
                  onChanged: (v) => setState(() => _showRankings = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // TAB 3: Security & Data
  Widget _buildSecurityDataTab(User currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Backup password section (if Google linked)
        if (currentUser.hasGoogleLinked && !currentUser.hasPassword) ...[
          const Text(
            'ACCOUNT SECURITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.password_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Set Backup Password',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Allow logging in with email and password in addition to Google Sign-In.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'New password (min 8 chars)',
                    filled: true,
                    fillColor: AppColors.background,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isSettingPassword ? null : _handleSetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.lock_rounded, size: 16),
                  label: _isSettingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Set Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Data Management Section (Export & Import Hive Data)
        DataManagementCard(onDataChanged: widget.onSaved),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPrivacyTierCards() {
    final tiers = [
      {
        'id': 'PUBLIC',
        'label': 'Public',
        'desc': 'Visible to everyone in the Hive.',
        'icon': Icons.public_rounded,
        'color': AppColors.success,
      },
      {
        'id': 'FOLLOWERS_ONLY',
        'label': 'Followers Only',
        'desc': 'Only approved followers see details.',
        'icon': Icons.group_rounded,
        'color': AppColors.primary,
      },
      {
        'id': 'PRIVATE',
        'label': 'Strictly Private',
        'desc': 'Only you can view your profile.',
        'icon': Icons.lock_rounded,
        'color': AppColors.textMuted,
      },
    ];

    return Row(
      children: tiers.map((tier) {
        final isSelected = _privacyLevel == tier['id'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _privacyLevel = tier['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    tier['icon'] as IconData,
                    size: 24,
                    color: isSelected ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tier['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tier['desc'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
      secondary: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}


