import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_colors.dart';

class ImportPreviewSheet extends StatefulWidget {
  final Map<String, dynamic> previewData;
  final ValueChanged<Map<String, dynamic>> onConfirm;
  final bool isImporting;
  final bool defaultToCurrentYear;

  const ImportPreviewSheet({
    super.key,
    required this.previewData,
    required this.onConfirm,
    this.isImporting = false,
    this.defaultToCurrentYear = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> previewData,
    required ValueChanged<Map<String, dynamic>> onConfirm,
    bool isImporting = false,
    bool defaultToCurrentYear = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImportPreviewSheet(
        previewData: previewData,
        onConfirm: onConfirm,
        isImporting: isImporting,
        defaultToCurrentYear: defaultToCurrentYear,
      ),
    );
  }

  @override
  State<ImportPreviewSheet> createState() => _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends State<ImportPreviewSheet> {
  late List<Map<String, dynamic>> _entries;
  late List<dynamic> _lists;
  String _activeFilter = 'all'; // 'all', 'unmatched', 'matched'
  bool _showDuplicates = false;
  late bool _defaultToCurrentYear;

  @override
  void initState() {
    super.initState();
    final rawList = widget.previewData['entries'] as List? ?? [];
    _entries = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _lists = widget.previewData['lists'] as List? ?? [];
    _defaultToCurrentYear = widget.defaultToCurrentYear;
  }

  int get _matchedCount => _entries.where((e) => e['matchStatus'] == 'MATCHED').length;
  int get _unmatchedCount => _entries.where((e) => e['matchStatus'] == 'UNMATCHED').length;
  int get _duplicateCount => _entries.where((e) => e['isDuplicate'] == true).length;
  int get _noDateCount => _entries.where((e) => e['watchedAt'] == null).length;

  int get _importableCount {
    if (_showDuplicates) return _matchedCount;
    return _entries.where((e) => e['matchStatus'] == 'MATCHED' && e['isDuplicate'] != true).length;
  }

  List<Map<String, dynamic>> get _filteredEntries {
    var list = _entries;
    if (!_showDuplicates) {
      list = list.where((e) => e['isDuplicate'] != true).toList();
    }
    if (_activeFilter == 'matched') {
      return list.where((e) => e['matchStatus'] == 'MATCHED').toList();
    }
    if (_activeFilter == 'unmatched') {
      return list.where((e) => e['matchStatus'] == 'UNMATCHED').toList();
    }
    return list;
  }

  void _removeEntry(int originalIndex) {
    setState(() {
      _entries.removeAt(originalIndex);
    });
  }

  void _handleConfirm({bool onlyMatched = false}) {
    final toImportEntries = _showDuplicates
        ? _entries.where((e) => onlyMatched ? e['matchStatus'] == 'MATCHED' : true).toList()
        : _entries.where((e) => (onlyMatched ? e['matchStatus'] == 'MATCHED' : true) && e['isDuplicate'] != true).toList();

    final readyPayload = <String, dynamic>{
      'entries': toImportEntries,
      'lists': _lists,
      'defaultToCurrentYear': _defaultToCurrentYear,
    };

    Navigator.of(context).pop(true);
    widget.onConfirm(readyPayload);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fact_check_rounded, color: AppColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review & Match Entries',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_showDuplicates ? _entries.length : _entries.length - _duplicateCount} items to import · $_importableCount ready',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: widget.isImporting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Badges / Metrics Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.surfaceHighest.withValues(alpha: 0.4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildBadge(
                    icon: Icons.check_circle_rounded,
                    label: '$_matchedCount Matched',
                    color: AppColors.success,
                    bgColor: AppColors.success.withValues(alpha: 0.12),
                  ),
                  if (_unmatchedCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildBadge(
                      icon: Icons.warning_rounded,
                      label: '$_unmatchedCount Need Match',
                      color: AppColors.warning,
                      bgColor: AppColors.warning.withValues(alpha: 0.15),
                    ),
                  ],
                  if (_duplicateCount > 0) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showDuplicates = !_showDuplicates),
                      child: _buildBadge(
                        icon: _showDuplicates ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        label: _showDuplicates ? '$_duplicateCount Duplicates (Showing)' : '$_duplicateCount Duplicates (Skipped)',
                        color: _showDuplicates ? AppColors.warning : AppColors.textMuted,
                        bgColor: _showDuplicates ? AppColors.warning.withValues(alpha: 0.15) : AppColors.border,
                      ),
                    ),
                  ],
                  if (_noDateCount > 0) ...[
                    const SizedBox(width: 8),
                    _buildBadge(
                      icon: Icons.calendar_today_rounded,
                      label: _defaultToCurrentYear
                          ? '$_noDateCount Default to ${DateTime.now().year}'
                          : '$_noDateCount No Date',
                      color: _defaultToCurrentYear ? AppColors.primaryDark : AppColors.warning,
                      bgColor: _defaultToCurrentYear
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.warning.withValues(alpha: 0.12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Filter Segment Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _buildFilterTab('all', 'All (${_showDuplicates ? _entries.length : _entries.length - _duplicateCount})'),
                const SizedBox(width: 8),
                _buildFilterTab('matched', 'Matched ($_importableCount)'),
                if (_unmatchedCount > 0) ...[
                  const SizedBox(width: 8),
                  _buildFilterTab('unmatched', 'Unmatched ($_unmatchedCount)'),
                ],
              ],
            ),
          ),

          // Default to Current Year Toggle Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primaryDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Default to current year (${DateTime.now().year})',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _noDateCount > 0
                            ? '$_noDateCount items have no watch date'
                            : 'Applies to items without a watch date',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: _defaultToCurrentYear,
                    activeThumbColor: Colors.black,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _defaultToCurrentYear = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Unmatched alert hint
          if (_unmatchedCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_unmatchedCount title(s) could not be matched automatically. You can remove them or import matched items directly.',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // Entries List
          Flexible(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No entries in this view',
                        style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final entry = filtered[index];
                      final origIndex = _entries.indexOf(entry);
                      final title = entry['matchedTitle'] ?? entry['title'] ?? 'Unknown';
                      final origTitle = entry['title']?.toString();
                      final year = entry['matchedYear'] ?? entry['year']?.toString();
                      final posterPath = entry['posterPath']?.toString();
                      final isMatched = entry['matchStatus'] == 'MATCHED';
                      final isDuplicate = entry['isDuplicate'] == true;
                      final rating = entry['rating']?.toString();
                      final watchedAt = entry['watchedAt']?.toString();

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMatched ? AppColors.surface : AppColors.warning.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMatched ? AppColors.border : AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Poster thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 44,
                                height: 64,
                                color: AppColors.surfaceHighest,
                                child: posterPath != null && posterPath.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: ApiEndpoints.tmdbPoster(posterPath),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(Icons.movie_rounded, size: 20, color: AppColors.textMuted),
                                      )
                                    : const Icon(Icons.movie_rounded, size: 20, color: AppColors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (origTitle != null && origTitle != title)
                                    Text(
                                      'File: $origTitle',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                    ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (year != null && year.isNotEmpty) _buildMetaChip(year),
                                      if (rating != null && rating.isNotEmpty)
                                        _buildMetaChip(
                                          '★ $rating/10',
                                          color: AppColors.primaryDark,
                                        ),
                                      if (watchedAt != null)
                                        _buildMetaChip(_formatDate(watchedAt))
                                      else if (widget.defaultToCurrentYear)
                                        _buildMetaChip('No Date (Defaults to ${DateTime.now().year})', color: AppColors.primaryDark)
                                      else
                                        _buildMetaChip('No Date Recorded', color: AppColors.textMuted),
                                      if (isDuplicate)
                                        _buildMetaChip('Duplicate', color: AppColors.textMuted),
                                      if (!isMatched)
                                        _buildMetaChip('Unmatched', color: AppColors.warning),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Action: Remove entry from preview
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                              tooltip: 'Remove from import',
                              onPressed: () => _removeEntry(origIndex),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: widget.isImporting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    onPressed: (_importableCount == 0 || widget.isImporting)
                        ? null
                        : () => _handleConfirm(onlyMatched: _unmatchedCount > 0),
                    child: widget.isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : Text(
                            _unmatchedCount > 0
                                ? 'Import $_importableCount Matched'
                                : 'Import $_importableCount Entries',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _activeFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.textSecondary,
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
