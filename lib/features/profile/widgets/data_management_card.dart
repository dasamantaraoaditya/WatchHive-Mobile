import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/data_parser_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../../../shared/widgets/wh_bee_loader.dart';
import '../repositories/user_repository.dart';
import 'import_preview_sheet.dart';

class DataManagementCard extends ConsumerStatefulWidget {
  final VoidCallback? onDataChanged;

  const DataManagementCard({
    super.key,
    this.onDataChanged,
  });

  @override
  ConsumerState<DataManagementCard> createState() => DataManagementCardState();
}

class DataManagementCardState extends ConsumerState<DataManagementCard> {
  bool _isExpanded = false;
  String _activeTab = 'import'; // 'import' or 'export'
  bool _includeEntries = true;
  bool _includeLists = true;
  String _exportFormat = 'json'; // 'json' or 'csv'
  bool _isExporting = false;
  bool _isImporting = false;
  bool _defaultToCurrentYear = false;
  bool _copiedAiPrompt = false;
  Map<String, dynamic>? _importResult;

  void expand() {
    if (!_isExpanded && mounted) {
      setState(() => _isExpanded = true);
    }
  }

  Future<void> _handleExport() async {
    if (!_includeEntries && !_includeLists) {
      WHAlert.showWarning(context, 'Select at least one data type (Entries or Lists) to export.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final rawData = await repo.exportData(
        includeEntries: _includeEntries,
        includeLists: _includeLists,
        format: _exportFormat,
      );

      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final parts = <String>[];
      if (_includeEntries) parts.add('entries');
      if (_includeLists) parts.add('lists');
      final label = parts.length == 2 ? 'export' : parts.first;
      final filename = 'watchhive_${label}_$dateStr.$_exportFormat';
      final mimeType = _exportFormat == 'csv' ? 'text/csv' : 'application/json';

      final bytes = Uint8List.fromList(utf8.encode(rawData));
      final xFile = XFile.fromData(
        bytes,
        name: filename,
        mimeType: mimeType,
      );

      await Share.shareXFiles(
        [xFile],
        subject: 'WatchersHive Data Export ($filename)',
        text: 'My WatchersHive data exported on $dateStr',
      );

      if (mounted) {
        final what = [if (_includeEntries) 'Entries', if (_includeLists) 'Lists'].join(' & ');
        WHAlert.showSuccess(context, '$what exported as ${_exportFormat.toUpperCase()}! 📦');
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to export data. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isImporting = false);
        return;
      }

      final file = result.files.single;
      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          fileBytes = await ioFile.readAsBytes();
        }
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception('The selected file is empty or could not be read.');
      }

      // Parse with universal CSV & JSON parser
      final parsed = DataParserService.parseFile(fileBytes, file.name);
      final entries = (parsed['entries'] as List?) ?? [];
      final lists = (parsed['lists'] as List?) ?? [];

      if (entries.isEmpty && lists.isEmpty) {
        throw Exception('No valid watch entries or lists found in "${file.name}". Please check the file formatting.');
      }

      final repo = ref.read(userRepositoryProvider);

      // If we have entries, run TMDb preview check and open preview bottom sheet
      if (entries.isNotEmpty) {
        final previewData = await repo.previewImport({
          'entries': entries,
          'lists': lists,
          'defaultToCurrentYear': _defaultToCurrentYear,
        });

        if (!mounted) return;

        setState(() => _isImporting = false);

        await ImportPreviewSheet.show(
          context,
          previewData: previewData,
          defaultToCurrentYear: _defaultToCurrentYear,
          onConfirm: (readyPayload) async {
            setState(() => _isImporting = true);
            try {
              final importRes = await repo.importData(readyPayload);
              if (mounted) {
                setState(() => _importResult = importRes);
                WHAlert.showSuccess(context, 'Data imported successfully! ✨');
                widget.onDataChanged?.call();
              }
            } catch (err) {
              if (mounted) {
                WHAlert.showError(
                  context,
                  AppErrorHandler.toUserFriendlyMessage(
                    err,
                    defaultMessage: 'Failed to complete import.',
                  ),
                );
              }
            } finally {
              if (mounted) setState(() => _isImporting = false);
            }
          },
        );
      } else {
        // Only lists to import
        final importRes = await repo.importData({
          'lists': lists,
        });

        if (mounted) {
          setState(() => _importResult = importRes);
          WHAlert.showSuccess(context, 'Lists imported successfully! ✨');
          widget.onDataChanged?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        WHAlert.showError(
          context,
          AppErrorHandler.toUserFriendlyMessage(
            e,
            defaultMessage: 'Failed to import data. Please check the file and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _isExpanded
          ? const EdgeInsets.all(20)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Tappable to expand / collapse)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _activeTab == 'export' ? Icons.file_download_rounded : Icons.file_upload_rounded,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Management',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeTab == 'export'
                            ? 'Export your watch entries and lists'
                            : 'Import your watch history & migrate catalogs',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textMuted,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 18),

            // Segmented Tab Toggle (Import first, then Export)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildModeButton('import', 'Import')),
                  Expanded(child: _buildModeButton('export', 'Export')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_activeTab == 'export') ...[
              // ─── EXPORT VIEW ───────────────────────────────────────
              const Text(
                'DATA TYPES TO INCLUDE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildDataTypeTile(
                      icon: Icons.history_rounded,
                      title: 'Watch Entries',
                      subtitle: 'Ratings & reviews',
                      checked: _includeEntries,
                      onChanged: (val) => setState(() => _includeEntries = val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDataTypeTile(
                      icon: Icons.list_alt_rounded,
                      title: 'Watch Lists',
                      subtitle: 'Saved collections',
                      checked: _includeLists,
                      onChanged: (val) => setState(() => _includeLists = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feed Protection Info Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppColors.primaryDark),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Feed Protection: Imported watch history and entries are added to your personal library & stats only and will not flood the community feed.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Format Toggle & Actions Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Export Format',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _exportFormat.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: ['json', 'csv'].map((fmt) {
                              final isSelected = _exportFormat == fmt;
                              return GestureDetector(
                                onTap: () => setState(() => _exportFormat = fmt),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    fmt.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: isSelected ? Colors.black : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isExporting || _isImporting ? null : _handleExport,
                        icon: _isExporting
                            ? const WHBeeSpinner(size: 16)
                            : const Icon(Icons.download_rounded, size: 18),
                        label: Text(
                          _isExporting ? 'Exporting...' : 'Export Data',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ─── IMPORT VIEW (Compact & AI First) ──────────────────
              // 1. Format with AI card (Shifted Above)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.black),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Format Your History with AI',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Have unformatted notes or a text list? Copy our prompt into ChatGPT, Claude, or Gemini to instantly convert into importable JSON.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: _copiedAiPrompt ? AppColors.success.withValues(alpha: 0.15) : AppColors.surface,
                          side: BorderSide(color: _copiedAiPrompt ? AppColors.success : AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: DataParserService.aiImportPrompt));
                          setState(() => _copiedAiPrompt = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copiedAiPrompt = false);
                          });
                        },
                        icon: Icon(
                          _copiedAiPrompt ? Icons.check_circle_rounded : Icons.content_copy_rounded,
                          size: 15,
                          color: _copiedAiPrompt ? AppColors.success : Colors.black,
                        ),
                        label: Text(
                          _copiedAiPrompt ? 'Prompt Copied! ✨' : 'Copy AI Formatting Prompt',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _copiedAiPrompt ? AppColors.success : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Default to current year toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Default to current year if no date',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _defaultToCurrentYear
                                ? 'Items without a date will default to ${DateTime.now().year}'
                                : 'Off by default — no watch date will be recorded',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _defaultToCurrentYear,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) => setState(() => _defaultToCurrentYear = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Compact Dropzone File Picker
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_upload_rounded, size: 22, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select File to Import',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Letterboxd, IMDb, Trakt, Notion CSV or WatchersHive JSON',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildChip('🟩 Letterboxd'),
                        _buildChip('🟨 IMDb'),
                        _buildChip('🟥 Trakt'),
                        _buildChip('📄 CSV / JSON'),
                        _buildChip('✨ Auto TMDb Match', color: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isExporting || _isImporting ? null : _handleImport,
                        icon: _isImporting
                            ? const WHBeeSpinner(size: 16)
                            : const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text(
                          _isImporting ? 'Parsing & Matching...' : 'Choose File to Import',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Collapsible Migration Tips
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primaryDark),
                    title: const Text(
                      'Migration tips (Letterboxd, IMDb, Trakt)',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    children: [
                      _buildMigrationCard(
                        badge: '🟩 Letterboxd',
                        guide: 'Settings > Data > Export Data. Drop diary.csv. 5-star ratings scale 2x to 10-point scale!',
                      ),
                      const SizedBox(height: 6),
                      _buildMigrationCard(
                        badge: '🟨 IMDb',
                        guide: 'Your Ratings > ⋯ > Export. Drop ratings.csv. Const IDs ensure instant 100% accurate TMDb matching!',
                      ),
                      const SizedBox(height: 6),
                      _buildMigrationCard(
                        badge: '🟥 Trakt / Notion',
                        guide: 'Export your watched history CSV/JSON. Dates, ratings, and IDs are mapped automatically.',
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Import Result Summary Banner
            if (_importResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _importResult!['message']?.toString() ?? 'Import Complete!',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _importResult = null),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (_importResult!['entriesImported'] != null)
                          Text(
                            '${_importResult!['entriesImported']} entries added',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        if ((_importResult!['entriesSkipped'] as num? ?? 0) > 0)
                          Text(
                            '${_importResult!['entriesSkipped']} skipped',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        if (_importResult!['listsImported'] != null)
                          Text(
                            '${_importResult!['listsImported']} lists added',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, String label) {
    final isSelected = _activeTab == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _activeTab = mode;
        _importResult = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isSelected ? Colors.black : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildMigrationCard({required String badge, required String guide}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            guide,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null ? color.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color ?? AppColors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildDataTypeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: checked ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: checked ? AppColors.primary : AppColors.border,
            width: checked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: checked ? AppColors.primary : AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: checked ? Colors.black : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: checked ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (checked) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 16, color: AppColors.primaryDark),
            ],
          ],
        ),
      ),
    );
  }
}
