import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_handler.dart';
import '../../../shared/widgets/wh_alert.dart';
import '../repositories/user_repository.dart';

class DataManagementCard extends ConsumerStatefulWidget {
  final VoidCallback? onDataChanged;

  const DataManagementCard({
    super.key,
    this.onDataChanged,
  });

  @override
  ConsumerState<DataManagementCard> createState() => _DataManagementCardState();
}

class _DataManagementCardState extends ConsumerState<DataManagementCard> {
  bool _includeEntries = true;
  bool _includeLists = true;
  String _exportFormat = 'json'; // 'json' or 'csv'
  bool _isExporting = false;
  bool _isImporting = false;
  Map<String, dynamic>? _importResult;

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

  List<Map<String, dynamic>> _parseCsvToEntries(String csvText) {
    final lines = csvText.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 2) return [];

    int headerIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final l = lines[i].toLowerCase();
      if (l.contains('title') && (l.contains('tmdb') || l.contains('rating') || l.contains('type') || l.contains('watched') || l.contains('date'))) {
        headerIndex = i;
        break;
      }
    }
    if (headerIndex == -1) return [];

    List<String> parseCsvRow(String row) {
      final result = <String>[];
      var insideQuote = false;
      var entry = StringBuffer();
      for (int i = 0; i < row.length; i++) {
        final char = row[i];
        if (char == '"') {
          if (insideQuote && i + 1 < row.length && row[i + 1] == '"') {
            entry.write('"');
            i++;
          } else {
            insideQuote = !insideQuote;
          }
        } else if (char == ',' && !insideQuote) {
          result.add(entry.toString());
          entry = StringBuffer();
        } else {
          entry.write(char);
        }
      }
      result.add(entry.toString());
      return result;
    }

    final headers = parseCsvRow(lines[headerIndex]).map((h) => h.trim().toLowerCase()).toList();
    final entries = <Map<String, dynamic>>[];

    for (int i = headerIndex + 1; i < lines.length; i++) {
      if (lines[i].startsWith('#')) break;
      final values = parseCsvRow(lines[i]);
      if (values.length < 2) continue;

      final row = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        row[headers[j]] = j < values.length ? values[j].trim() : '';
      }

      final title = row['title'] ?? row['name'] ?? '';
      if (title.isEmpty) continue;

      final tmdbId = int.tryParse(row['tmdbid'] ?? row['tmdb_id'] ?? '0') ?? 0;
      final rawType = (row['type'] ?? 'MOVIE').toUpperCase();
      final type = rawType.contains('TV') ? 'TV_SHOW' : 'MOVIE';
      final rating = double.tryParse(row['rating'] ?? '');
      final watchedAt = row['watchedat'] ?? row['watched at'] ?? row['watched date'] ?? row['date'];
      final review = row['review'];
      final rawTags = row['tags'];
      final tags = rawTags != null && rawTags.isNotEmpty
          ? rawTags.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];
      final isRewatch = row['isrewatch'] == 'true' || row['is_rewatch'] == 'true';
      final isWatching = row['iswatching'] == 'true' || row['is_watching'] == 'true';
      final watchLocation = row['watchlocation'] ?? row['watch_location'];

      entries.add({
        'tmdbId': tmdbId,
        'title': title,
        'type': type,
        if (rating != null) 'rating': rating,
        if (watchedAt != null && watchedAt.isNotEmpty) 'watchedAt': watchedAt,
        if (review != null && review.isNotEmpty) 'review': review,
        'tags': tags,
        'isRewatch': isRewatch,
        'isWatching': isWatching,
        if (watchLocation != null && watchLocation.isNotEmpty) 'watchLocation': watchLocation,
        'isImported': true,
      });
    }

    return entries;
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
        // User cancelled picker
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

      final fileText = utf8.decode(fileBytes);
      final isCsv = file.name.toLowerCase().endsWith('.csv');

      Map<String, dynamic> payload;
      if (isCsv) {
        final parsedEntries = _parseCsvToEntries(fileText);
        if (parsedEntries.isEmpty) {
          throw Exception('No valid watch entries found in the selected CSV file.');
        }
        payload = {'entries': parsedEntries};
      } else {
        dynamic decoded;
        try {
          decoded = jsonDecode(fileText);
        } catch (_) {
          throw Exception('Invalid file. Please upload a valid WatchersHive JSON or CSV export file.');
        }

        if (decoded is! Map<String, dynamic>) {
          throw Exception('Invalid format. File must contain a valid WatchersHive JSON export object.');
        }

        final hasEntries = decoded.containsKey('entries') && decoded['entries'] is List;
        final hasLists = decoded.containsKey('lists') && decoded['lists'] is List;

        if (!hasEntries && !hasLists) {
          throw Exception('File must contain an "entries" and/or "lists" array.');
        }

        payload = decoded;
      }

      final repo = ref.read(userRepositoryProvider);
      final importRes = await repo.importData(payload);

      if (mounted) {
        setState(() => _importResult = importRes);
        WHAlert.showSuccess(context, 'Data imported successfully! ✨');
        widget.onDataChanged?.call();
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_alt_rounded, size: 18, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Management',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Export or import your watch entries and lists',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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

          // Checkboxes / Chips
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
                // Format Selector Row
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

                // Action Buttons Row: Export & Import
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isExporting || _isImporting ? null : _handleExport,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isExporting || _isImporting ? null : _handleImport,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.upload_rounded, size: 18),
                        label: Text(
                          _isImporting ? 'Importing...' : 'Import Data',
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
              ],
            ),
          ),

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
