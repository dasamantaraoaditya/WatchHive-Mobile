import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/user_preferences.dart';
import '../services/onboarding_service.dart';

class WatchPreferencesOnboardingDialog extends ConsumerStatefulWidget {
  final bool isEditing;

  const WatchPreferencesOnboardingDialog({
    super.key,
    this.isEditing = false,
  });

  /// Presents the WatchPreferencesOnboardingDialog on the root navigator.
  static Future<bool?> show(
    BuildContext context, {
    bool isEditing = false,
  }) async {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: isEditing,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => WatchPreferencesOnboardingDialog(isEditing: isEditing),
    );
  }

  @override
  ConsumerState<WatchPreferencesOnboardingDialog> createState() =>
      _WatchPreferencesOnboardingDialogState();
}

class _WatchPreferencesOnboardingDialogState
    extends ConsumerState<WatchPreferencesOnboardingDialog> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0, 1, 2
  bool _isSubmitting = false;

  final Set<String> _selectedLanguages = {};
  final Set<String> _selectedGenres = {};
  final Set<String> _selectedPlatforms = {};

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  void _loadExistingPreferences() {
    final user = ref.read(authStateProvider).value?.user;
    if (user != null && user.preferences != null) {
      final existing = UserPreferences.fromJson(user.preferences!);
      _selectedLanguages.addAll(existing.languages);
      _selectedGenres.addAll(existing.genres);
      _selectedPlatforms.addAll(existing.streamingPlatforms);
    }

    // Default to at least English if starting completely fresh
    if (_selectedLanguages.isEmpty && !widget.isEditing) {
      _selectedLanguages.add('en');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitPreferences() async {
    setState(() => _isSubmitting = true);

    final genreIds = _selectedGenres
        .map((g) => WatchHivePreferencesCatalog.genreToId[g])
        .where((id) => id != null)
        .cast<int>()
        .toList();

    final prefs = UserPreferences(
      languages: _selectedLanguages.toList(),
      genres: _selectedGenres.toList(),
      genreIds: genreIds,
      streamingPlatforms: _selectedPlatforms.toList(),
    );

    final onboardingService = ref.read(onboardingServiceProvider);
    onboardingService.markPrompted();

    final success = await onboardingService.savePreferences(
      preferences: prefs,
      ref: ref,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop(success);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.isEditing
                      ? 'Preferences updated! Your feed is re-customized.'
                      : 'Feed personalized! Enjoy trending & curated picks.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isEditing,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTopBar(),
              const SizedBox(height: 14),
              _buildStepIndicator(),
              const SizedBox(height: 16),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (step) => setState(() => _currentStep = step),
                  children: [
                    _buildLanguageStep(),
                    _buildGenreStep(),
                    _buildPlatformStep(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('🎬', style: TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing ? 'Watch Preferences' : 'Personalize Your Feed',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                'Question ${_currentStep + 1} of 3',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        if (widget.isEditing)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(3, (index) {
        final isCompletedOrActive = index <= _currentStep;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
            decoration: BoxDecoration(
              color: isCompletedOrActive ? AppColors.primary : AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  // ─── Question 1: Languages ────────────────────────────────────────────────
  Widget _buildLanguageStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What languages do you watch in?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your preferred languages (e.g. Telugu, Hindi, English). We will surface trending local releases and personalized suggestions.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: WatchHivePreferencesCatalog.languages.map((opt) {
              final isSelected = _selectedLanguages.contains(opt.id);
              return _buildSelectableChip(
                label: '${opt.emoji}  ${opt.label}',
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedLanguages.remove(opt.id);
                    } else {
                      _selectedLanguages.add(opt.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Question 2: Genres ───────────────────────────────────────────────────
  Widget _buildGenreStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What genres inspire you?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select 2 or more genres that match your taste so we can curate matching titles in your feed.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: WatchHivePreferencesCatalog.genres.map((opt) {
              final isSelected = _selectedGenres.contains(opt.id);
              return _buildSelectableChip(
                label: '${opt.emoji}  ${opt.label}',
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedGenres.remove(opt.id);
                    } else {
                      _selectedGenres.add(opt.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Question 3: Platforms ────────────────────────────────────────────────
  Widget _buildPlatformStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where do you watch most?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select your favorite streaming apps & platforms so we can highlight where your recommendations are available.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: WatchHivePreferencesCatalog.streamingPlatforms.map((opt) {
              final isSelected = _selectedPlatforms.contains(opt.id);
              return _buildSelectableChip(
                label: '${opt.emoji}  ${opt.label}',
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPlatforms.remove(opt.id);
                    } else {
                      _selectedPlatforms.add(opt.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    final isLastStep = _currentStep == 2;

    return Row(
      children: [
        if (_currentStep > 0) ...[
          OutlinedButton(
            onPressed: _prevPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
        ] else if (!widget.isEditing) ...[
          TextButton(
            onPressed: _submitPreferences,
            child: const Text(
              'Skip for now',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const Spacer(),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : (isLastStep ? _submitPreferences : _nextPage),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastStep
                            ? (widget.isEditing ? 'Save Preferences' : 'Personalize My Feed 🚀')
                            : 'Next ➜',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
