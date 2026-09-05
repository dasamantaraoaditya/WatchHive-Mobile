import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import 'daily_log_inspector_sheet.dart';

class WatchFrequencyChart extends StatefulWidget {
  final List<dynamic> timeSeries;

  const WatchFrequencyChart({
    super.key,
    required this.timeSeries,
  });

  @override
  State<WatchFrequencyChart> createState() => _WatchFrequencyChartState();
}

class _WatchFrequencyChartState extends State<WatchFrequencyChart> {
  String _chartType = 'line'; // 'line' or 'bar'
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Default select latest day with count > 0 if available
    if (widget.timeSeries.isNotEmpty) {
      for (int i = widget.timeSeries.length - 1; i >= 0; i--) {
        final item = widget.timeSeries[i] as Map<String, dynamic>;
        final count = (item['count'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          _selectedIndex = i;
          break;
        }
      }
    }
  }

  void _inspectDay(int index) {
    if (index < 0 || index >= widget.timeSeries.length) return;
    final item = widget.timeSeries[index] as Map<String, dynamic>;
    final count = (item['count'] as num?)?.toInt() ?? 0;
    final dateStr = item['date'] as String? ?? '';
    final items = (item['items'] as List<dynamic>?) ?? [];

    if (count > 0) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DailyLogInspectorSheet(
          dateStr: dateStr,
          count: count,
          items: items,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timeSeries.isEmpty) {
      return const SizedBox.shrink();
    }

    final dataList = widget.timeSeries.map((d) {
      final m = d as Map<String, dynamic>;
      final count = (m['count'] as num?)?.toInt() ?? 0;
      final dateStr = m['date'] as String? ?? '';
      final items = (m['items'] as List<dynamic>?) ?? [];
      return (count: count, date: dateStr, items: items);
    }).toList();

    final maxCount = dataList.map((e) => e.count).fold<int>(1, (max, v) => v > max ? v : max);

    final selectedItem = (_selectedIndex != null && _selectedIndex! < dataList.length)
        ? dataList[_selectedIndex!]
        : null;

    String? selectedFormattedDate;
    if (selectedItem != null && selectedItem.date.isNotEmpty) {
      try {
        final dt = DateTime.parse(selectedItem.date);
        selectedFormattedDate = DateFormat('MMM d, yyyy').format(dt);
      } catch (_) {
        selectedFormattedDate = selectedItem.date;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & View Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Watch Frequency Stream',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Daily activity trends over the last 30 days',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Line vs Bar Mode Switcher
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _chartType = 'line'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _chartType == 'line' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.show_chart_rounded,
                          size: 16,
                          color: _chartType == 'line' ? Colors.black : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    GestureDetector(
                      onTap: () => setState(() => _chartType = 'bar'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: _chartType == 'bar' ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          size: 16,
                          color: _chartType == 'bar' ? Colors.black : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Interactive Chart Canvas
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const height = 150.0;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final localX = details.localPosition.dx;
                  const padding = 16.0;
                  final chartW = width - padding * 2;
                  if (dataList.length <= 1) return;

                  final step = chartW / (dataList.length - 1);
                  final clampedX = (localX - padding).clamp(0.0, chartW);
                  final index = (clampedX / step).round().clamp(0, dataList.length - 1);

                  setState(() => _selectedIndex = index);
                  if (dataList[index].count > 0) {
                    _inspectDay(index);
                  }
                },
                onPanUpdate: (details) {
                  final localX = details.localPosition.dx;
                  const padding = 16.0;
                  final chartW = width - padding * 2;
                  if (dataList.length <= 1) return;

                  final step = chartW / (dataList.length - 1);
                  final clampedX = (localX - padding).clamp(0.0, chartW);
                  final index = (clampedX / step).round().clamp(0, dataList.length - 1);
                  if (index != _selectedIndex) {
                    setState(() => _selectedIndex = index);
                  }
                },
                child: CustomPaint(
                  size: Size(width, height),
                  painter: _FrequencyChartPainter(
                    data: dataList,
                    maxCount: maxCount,
                    chartType: _chartType,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              );
            },
          ),

          // Interactive Selected Date Summary Card / Tooltip
          if (selectedItem != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                if (selectedItem.count > 0 && _selectedIndex != null) {
                  _inspectDay(_selectedIndex!);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selectedItem.count > 0
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${selectedItem.count}',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            selectedItem.count == 1 ? 'watch' : 'watches',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedFormattedDate ?? '',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (selectedItem.items.isNotEmpty)
                            Text(
                              selectedItem.items
                                  .take(2)
                                  .map((it) => it['title']?.toString() ?? '')
                                  .where((t) => t.isNotEmpty)
                                  .join(', '),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            const Text(
                              'No logs recorded on this day',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (selectedItem.count > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inspect',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.black),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Tap any date point on the chart to inspect full daily logs',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyChartPainter extends CustomPainter {
  final List<({int count, String date, List<dynamic> items})> data;
  final int maxCount;
  final String chartType;
  final int? selectedIndex;

  _FrequencyChartPainter({
    required this.data,
    required this.maxCount,
    required this.chartType,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const paddingX = 16.0;
    const paddingY = 16.0;
    final chartW = size.width - paddingX * 2;
    final chartH = size.height - paddingY * 2;

    double getX(int index) {
      if (data.length <= 1) return paddingX;
      return (index / (data.length - 1)) * chartW + paddingX;
    }

    double getY(int count) {
      final ratio = (count / maxCount).clamp(0.0, 1.0);
      return size.height - paddingY - (ratio * chartH);
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(paddingX, size.height - paddingY),
      Offset(size.width - paddingX, size.height - paddingY),
      gridPaint,
    );

    // Midline
    final midPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(paddingX, paddingY + chartH / 2),
      Offset(size.width - paddingX, paddingY + chartH / 2),
      midPaint,
    );

    if (chartType == 'line') {
      final linePath = Path();
      final areaPath = Path();

      for (int i = 0; i < data.length; i++) {
        final x = getX(i);
        final y = getY(data[i].count);
        if (i == 0) {
          linePath.moveTo(x, y);
          areaPath.moveTo(x, y);
        } else {
          // Smooth curve using cubic bezier
          final prevX = getX(i - 1);
          final prevY = getY(data[i - 1].count);
          final midX = (prevX + x) / 2;
          linePath.cubicTo(midX, prevY, midX, y, x, y);
          areaPath.cubicTo(midX, prevY, midX, y, x, y);
        }
      }

      areaPath.lineTo(getX(data.length - 1), size.height - paddingY);
      areaPath.lineTo(getX(0), size.height - paddingY);
      areaPath.close();

      // Draw Area Gradient
      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(areaPath, areaPaint);

      // Draw Line
      final strokePaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, strokePaint);

      // Draw Dots
      for (int i = 0; i < data.length; i++) {
        final x = getX(i);
        final y = getY(data[i].count);
        final isSelected = selectedIndex == i;
        final hasCount = data[i].count > 0;

        final dotPaint = Paint()
          ..color = isSelected
              ? Colors.white
              : (hasCount ? AppColors.primary : AppColors.textMuted.withValues(alpha: 0.4));

        final radius = isSelected ? 6.0 : (hasCount ? 3.5 : 1.8);
        canvas.drawCircle(Offset(x, y), radius, dotPaint);

        if (isSelected) {
          final borderPaint = Paint()
            ..color = AppColors.primary
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(x, y), radius + 2, borderPaint);
        }
      }
    } else {
      // Bar Mode
      final barWidth = (chartW / data.length) * 0.65;

      for (int i = 0; i < data.length; i++) {
        final x = getX(i);
        final count = data[i].count;
        final h = (count / maxCount) * chartH;
        final isSelected = selectedIndex == i;

        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth / 2,
            size.height - paddingY - (count > 0 ? h : 3.0),
            barWidth,
            count > 0 ? h : 3.0,
          ),
          const Radius.circular(4),
        );

        final barPaint = Paint()
          ..color = isSelected
              ? AppColors.primary
              : (count > 0
                  ? AppColors.primary.withValues(alpha: 0.75)
                  : AppColors.surfaceHighest);

        canvas.drawRRect(barRect, barPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxCount != maxCount ||
        oldDelegate.chartType != chartType ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
