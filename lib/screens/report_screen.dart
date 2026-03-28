import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../models/habit.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;
  bool _isLoading = false;
  List<Habit> _habits = [];
  // date → habitId → isCompleted
  Map<String, Map<int, bool>> _previewData = {};

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    final db = DatabaseHelper.instance;
    final habits = await db.getAllHabits();
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    final records = await db.getRecordsForDateRange(startStr, endStr);

    final Map<String, Map<int, bool>> data = {};
    for (final record in records) {
      data.putIfAbsent(record.date, () => {});
      data[record.date]![record.habitId] = record.isCompleted;
    }
    setState(() {
      _habits = habits;
      _previewData = data;
      _isLoading = false;
    });
  }

  List<DateTime> get _dateRange {
    final list = <DateTime>[];
    var d = _startDate;
    while (!d.isAfter(_endDate)) {
      list.add(d);
      d = d.add(const Duration(days: 1));
    }
    return list;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6C63FF),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      });
      _loadPreview();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF6C63FF),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
      _loadPreview();
    }
  }

  void _applyQuickFilter(int daysBack) {
    setState(() {
      _endDate = DateTime.now();
      _startDate = DateTime.now().subtract(Duration(days: daysBack - 1));
    });
    _loadPreview();
  }

  void _applyThisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    });
    _loadPreview();
  }

  // ─── EXCEL EXPORT ────────────────────────────────────────────────────────

  Future<void> _exportToExcel() async {
    setState(() => _isExporting = true);

    try {
      final excel = Excel.createExcel();

      // Remove default Sheet1 if possible
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final sheet = excel['Routine Report'];

      // ── Header Row ──────────────────────────────────────────
      final headerBg = ExcelColor.fromHexString('#6C63FF');
      final headerFont = ExcelColor.fromHexString('#FFFFFF');

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: headerBg,
        fontColorHex: headerFont,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Column headers
      final columns = [
        'Date',
        ..._habits.map((h) => '${h.emoji} ${h.name}'),
        'Done ✅',
        'Score %',
      ];

      for (int col = 0; col < columns.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.value = TextCellValue(columns[col]);
        cell.cellStyle = headerStyle;
      }

      // ── Data Rows ────────────────────────────────────────────
      final dates = _dateRange;
      for (int rowIdx = 0; rowIdx < dates.length; rowIdx++) {
        final date = dates[rowIdx];
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        final dayRecords = _previewData[dateKey];
        final row = rowIdx + 1;

        // Alternating row color
        final rowBg = rowIdx % 2 == 0
            ? ExcelColor.fromHexString('#FFFFFF')
            : ExcelColor.fromHexString('#F8F7FF');

        final rowStyle = CellStyle(
          backgroundColorHex: rowBg,
          horizontalAlign: HorizontalAlign.Center,
        );

        // Date cell
        final dateCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        );
        dateCell.value =
            TextCellValue(DateFormat('EEE, dd MMM yyyy').format(date));
        dateCell.cellStyle = CellStyle(
          backgroundColorHex: rowBg,
          bold: true,
        );

        // Habit cells
        int completedCount = 0;
        for (int col = 0; col < _habits.length; col++) {
          final habit = _habits[col];
          final done = dayRecords?[habit.id!] ?? false;
          if (done) completedCount++;

          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
                columnIndex: col + 1, rowIndex: row),
          );
          cell.value = TextCellValue(done ? '✅' : '❌');
          cell.cellStyle = rowStyle;
        }

        // Total done cell
        final totalCell = sheet.cell(
          CellIndex.indexByColumnRow(
              columnIndex: _habits.length + 1, rowIndex: row),
        );
        totalCell.value = IntCellValue(completedCount);
        totalCell.cellStyle = CellStyle(
          backgroundColorHex: rowBg,
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: ExcelColor.fromHexString('#6C63FF'),
        );

        // Score % cell
        final score = _habits.isEmpty
            ? 0
            : (completedCount * 100 ~/ _habits.length);
        final scoreCell = sheet.cell(
          CellIndex.indexByColumnRow(
              columnIndex: _habits.length + 2, rowIndex: row),
        );
        scoreCell.value = TextCellValue('$score%');
        scoreCell.cellStyle = CellStyle(
          backgroundColorHex: rowBg,
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
          fontColorHex: ExcelColor.fromHexString(
            score >= 80
                ? '#4CAF50'
                : score >= 50
                    ? '#FF9800'
                    : '#F44336',
          ),
        );
      }

      // ── Save & Share ─────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      final dir = await getTemporaryDirectory();
      final fileName =
          'routine_${DateFormat('yyyyMMdd').format(_startDate)}_to_${DateFormat('yyyyMMdd').format(_endDate)}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'My Daily Routine Report',
        text:
            'Routine report: ${DateFormat('dd MMM').format(_startDate)} – ${DateFormat('dd MMM yyyy').format(_endDate)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── BUILD UI ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRangeCard(),
                  const SizedBox(height: 14),
                  _buildQuickFilters(),
                  const SizedBox(height: 20),
                  if (!_isLoading) ...[
                    _buildPreviewCard(),
                    const SizedBox(height: 20),
                  ],
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  _buildExportButton(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      'Export Report',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Download as Excel (.xlsx)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.file_download_outlined,
                  color: Colors.white70, size: 24),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeCard() {
    final days = _dateRange.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _datePicker(
                    'From',
                    _startDate,
                    _pickStartDate,
                    Icons.calendar_today_rounded,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      const Icon(Icons.arrow_forward,
                          color: Colors.grey, size: 18),
                      Text(
                        '$days day${days == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _datePicker(
                    'To',
                    _endDate,
                    _pickEndDate,
                    Icons.event_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePicker(
      String label, DateTime date, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6C63FF)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF6C63FF))),
                  Text(
                    DateFormat('dd MMM yy').format(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Select',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('Last 7 days', () => _applyQuickFilter(7)),
            _filterChip('Last 14 days', () => _applyQuickFilter(14)),
            _filterChip('Last 30 days', () => _applyQuickFilter(30)),
            _filterChip('This month', _applyThisMonth),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6C63FF)),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final dates = _dateRange;
    if (dates.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Preview',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E)),
                ),
                Text(
                  '${dates.length} rows',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...dates.take(7).map((date) {
              final key = DateFormat('yyyy-MM-dd').format(date);
              final dayData = _previewData[key];
              final done =
                  dayData?.values.where((v) => v).length ?? 0;
              final pct = _habits.isEmpty
                  ? 0
                  : (done * 100 ~/ _habits.length);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        DateFormat('EEE d MMM').format(date),
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _habits.isEmpty ? 0 : done / _habits.length,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 80
                                ? const Color(0xFF4CAF50)
                                : pct >= 50
                                    ? const Color(0xFFFF9800)
                                    : Colors.red.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: pct >= 80
                              ? const Color(0xFF4CAF50)
                              : pct >= 50
                                  ? const Color(0xFFFF9800)
                                  : Colors.red,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (dates.length > 7)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+ ${dates.length - 7} more days in report...',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isExporting ? null : _exportToExcel,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: const Color(0xFF4CAF50).withOpacity(0.4),
        ),
        child: _isExporting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Generating Excel...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_rounded, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Download Excel Report',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 What\'s in the Excel file?',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            '• Each row = one day\n'
            '• Each column = one habit\n'
            '• ✅ = completed, ❌ = not done\n'
            '• Score % column shows daily completion rate\n'
            '• Color-coded cells (green = high, red = low)',
            style: TextStyle(fontSize: 12, color: Color(0xFF444466), height: 1.6),
          ),
        ],
      ),
    );
  }
}
