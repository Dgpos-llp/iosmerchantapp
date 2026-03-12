import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/main.dart';
import 'SidePanel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:open_file/open_file.dart';
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

class AllTaxwiseSalesReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllTaxwiseSalesReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllTaxwiseSalesReportPage> createState() => _AllTaxwiseSalesReportPageState();
}

class _AllTaxwiseSalesReportPageState extends State<AllTaxwiseSalesReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;

  // Animation states
  bool _isHoveringRefresh = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  final List<_Col> _fixedColumns = [
    const _Col('Restaurant', 'restaurant'),
    const _Col('Bill No', 'billNo'),
    const _Col('Date', 'billDate'),
    const _Col('Taxable', 'taxableAmount'),
  ];

  List<_Col> _taxColumns = [];
  List<_Col> get _allColumns => [..._fixedColumns, ..._taxColumns];
  late List<_Col> _visibleColumns;
  List<_TaxwiseBillRow> _allRows = [];
  Map<String, dynamic> _totals = {};

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_fixedColumns);
    if (hasOnlyOneDb) {
      selectedDbKey = widget.dbToBrandMap.keys.first;
    } else {
      selectedDbKey = "All";
    }
    _fetchData();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  // Helper to determine if a column should be right-aligned
  bool _isNumeric(String key) {
    if (key == 'taxableAmount') return true;
    // Check if the key exists in tax columns
    return _taxColumns.any((col) => col.key == key);
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    _taxColumns = [];
    _totals = {};

    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList = (selectedDbKey == null || selectedDbKey == "All")
        ? widget.dbToBrandMap.keys.toList()
        : [selectedDbKey!];

    Map<String, List<TaxwiseReport>> dbToTaxwise =
    await UserData.fetchTaxwiseForDbs(config, dbList, startDate, endDate);

    List<_TaxwiseBillRow> rows = [];
    Set<String> taxKeys = {};

    dbToTaxwise.forEach((dbKey, reports) {
      for (var report in reports) {
        Map<String, dynamic> taxData = report.getTaxData();
        taxKeys.addAll(taxData.keys);

        rows.add(_TaxwiseBillRow(
          restaurant: widget.dbToBrandMap[dbKey] ?? dbKey,
          billNo: report.billNo,
          billDate: report.billDate,
          taxableAmount: report.taxableAmount,
          taxAmounts: taxData,
        ));
      }
    });

    _taxColumns = taxKeys.map((key) => _Col(formatTaxName(key), key)).toList();
    _calculateTotals(rows);

    setState(() {
      _allRows = rows;
      _visibleColumns = [..._fixedColumns, ..._taxColumns];
      _loading = false;
    });
  }

  String formatTaxName(String taxKey) {
    return taxKey
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(\d+)$'), (match) => ' ${match.group(1)}%')
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');
  }

  void _calculateTotals(List<_TaxwiseBillRow> rows) {
    double totalTaxable = 0.0;
    Map<String, double> taxSums = {};

    for (var row in rows) {
      totalTaxable += double.tryParse(row.taxableAmount) ?? 0.0;
      row.taxAmounts.forEach((key, value) {
        double amt = double.tryParse(value?.toString() ?? '0') ?? 0.0;
        taxSums[key] = (taxSums[key] ?? 0.0) + amt;
      });
    }

    _totals = {
      'restaurant': 'Total',
      'taxableAmount': totalTaxable.toStringAsFixed(3),
    };

    taxSums.forEach((key, value) {
      _totals[key] = value.toStringAsFixed(3);
    });
  }

  void _toggleColumn(_Col col, bool value) {
    setState(() {
      if (value) {
        if (!_visibleColumns.contains(col)) {
          int originalIndex = _allColumns.indexOf(col);
          int insertIndex = 0;
          for (int i = 0; i < _visibleColumns.length; i++) {
            int currentOriginalIndex = _allColumns.indexOf(_visibleColumns[i]);
            if (currentOriginalIndex > originalIndex) break;
            insertIndex++;
          }
          _visibleColumns.insert(insertIndex, col);
        }
      } else {
        _visibleColumns.remove(col);
      }
    });
  }

  Future<void> _exportExcel() async {
    try {
      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Sheet1'];
      final boldStyle = excel.CellStyle(bold: true);

      int rowNum = 0;
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum))
        ..value = "Taxwise Sales Report"
        ..cellStyle = boldStyle;
      rowNum += 2;

      sheet.appendRow(["Date From", DateFormat('dd-MM-yyyy').format(_startDate), "Date To", DateFormat('dd-MM-yyyy').format(_endDate)]);
      rowNum += 2;

      final headerRow = _visibleColumns.map((c) => c.title).toList();
      for (int i = 0; i < headerRow.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum))
          ..value = headerRow[i]
          ..cellStyle = boldStyle;
      }
      rowNum++;

      for (final row in _allRows) {
        for (int i = 0; i < _visibleColumns.length; i++) {
          sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum))
            ..value = row.getField(_visibleColumns[i].key);
        }
        rowNum++;
      }

      for (int i = 0; i < _visibleColumns.length; i++) {
        final colKey = _visibleColumns[i].key;
        String val = (colKey == 'billNo' || colKey == 'billDate') ? '' : (_totals[colKey]?.toString() ?? '');
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum))
          ..value = val
          ..cellStyle = boldStyle;
      }

      final fileBytes = excelFile.encode();

      if (kIsWeb) {
        web_exporter.saveFileWeb(fileBytes!, 'TaxwiseSalesReport.xlsx');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Excel downloaded successfully'),
              backgroundColor: Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For Android and Windows
        final directory = await path_provider.getExternalStorageDirectory() ??
            await path_provider.getApplicationDocumentsDirectory();
        final String path = '${directory.path}/TaxwiseSalesReport_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel saved successfully'),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Try to open the file
        try {
          await OpenFile.open(path);
        } catch (e) {
          print('Could not open file: $e');
        }
      }
    } catch (e) {
      print('Error exporting Excel: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting Excel'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isHeaderMobile = size.width < 700;
    final bool isMobile = size.width < 600;

    final dbKeys = widget.dbToBrandMap.keys.toList();
    final brandDropdownItems = ["All", ...dbKeys];
    final brandDisplayMap = {
      "All": "All Outlets",
      ...{for (final db in dbKeys) db: widget.dbToBrandMap[db]!}
    };

    String safeSelectedDbKey = brandDropdownItems.contains(selectedDbKey) ? selectedDbKey! : "All";

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            "Taxwise Sales",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
          ),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandDropdownItems, brandDisplayMap, safeSelectedDbKey),
          actions: [
            _buildIconButton(
              icon: Icons.refresh,
              onPressed: _fetchData,
              isHovering: _isHoveringRefresh,
              onHover: (value) => setState(() => _isHoveringRefresh = value),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            _buildBreadcrumb(),
            _buildFilterSection(brandDropdownItems, brandDisplayMap, safeSelectedDbKey, isMobile),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4154F1))))
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildTable(isMobile),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSelector(List<String> items, Map<String, String> displayMap, String selected) {
    return Row(
      children: [
        const SizedBox(width: 70),
        if (!hasOnlyOneDb)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D)),
                isExpanded: true,
                items: items.map((db) => DropdownMenuItem(
                  value: db,
                  child: Text(displayMap[db]!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
                )).toList(),
                onChanged: (value) {
                  setState(() => selectedDbKey = value);
                  _fetchData();
                },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(singleBrandName ?? "", style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
          ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed, required bool isHovering, required Function(bool) onHover}) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: isHovering ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        child: IconButton(
          icon: Icon(icon, color: isHovering ? const Color(0xFF4154F1) : const Color(0xFF7F8C8D)),
          style: IconButton.styleFrom(
            backgroundColor: isHovering ? const Color(0xFF4154F1).withOpacity(0.1) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.home, color: Color(0xFF7F8C8D), size: 16),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text("Reports", style: TextStyle(color: Color(0xFF7F8C8D), decoration: TextDecoration.underline, fontSize: 13)),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF7F8C8D), size: 16),
          const Text("Taxwise", style: TextStyle(color: Color(0xFF4154F1), fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  // UPDATED: Responsive filter section
  Widget _buildFilterSection(List<String> items, Map<String, String> displayMap, String selected, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: isMobile
          ? _buildMobileFilter(items, displayMap, selected)
          : _buildDesktopFilter(items, displayMap, selected),
    );
  }

  // Desktop filter layout
  Widget _buildDesktopFilter(List<String> items, Map<String, String> displayMap, String selected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildDateFilter("Start", _startDate, (d) { setState(() => _startDate = d); _fetchData(); }, isMobile: false),
          const SizedBox(width: 16),
          _buildDateFilter("End", _endDate, (d) { setState(() => _endDate = d); _fetchData(); }, isMobile: false),
          const SizedBox(width: 16),
          if (!hasOnlyOneDb) ...[
            _buildDropdownFilter("Outlet", items, selected, displayMap, isMobile: false),
            const SizedBox(width: 16),
          ],
          _buildActionButtons(isMobile: false),
        ],
      ),
    );
  }

  // Mobile filter layout
  Widget _buildMobileFilter(List<String> items, Map<String, String> displayMap, String selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date filters in a row
        Row(
          children: [
            Expanded(
              child: _buildDateFilter("Start", _startDate, (d) { setState(() => _startDate = d); _fetchData(); }, isMobile: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDateFilter("End", _endDate, (d) { setState(() => _endDate = d); _fetchData(); }, isMobile: true),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Outlet dropdown if multiple outlets
        if (!hasOnlyOneDb) ...[
          _buildDropdownFilter("Outlet", items, selected, displayMap, isMobile: true),
          const SizedBox(height: 12),
        ],

        // Action buttons
        _buildActionButtons(isMobile: true),
      ],
    );
  }

  // UPDATED: Date filter with full year
  Widget _buildDateFilter(String label, DateTime date, Function(DateTime) onPicked, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100)
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: isMobile ? double.infinity : 150,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8)
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7F8C8D)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // UPDATED: Dropdown filter with responsive width
  Widget _buildDropdownFilter(String label, List<String> items, String selected, Map<String, String> displayMap, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 4),
        Container(
          width: isMobile ? double.infinity : 180,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(8)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(selected) ? selected : items.first,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D), size: 18),
              items: items.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text(displayMap[v]!, style: const TextStyle(fontSize: 12))
              )).toList(),
              onChanged: (val) {
                setState(() => selectedDbKey = val);
                _fetchData();
              },
            ),
          ),
        ),
      ],
    );
  }

  // UPDATED: Action buttons with smaller size on mobile
  Widget _buildActionButtons({required bool isMobile}) {
    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _showColumnSelector(),
              icon: const Icon(Icons.view_column, size: 16, color: Color(0xFF4154F1)),
              label: const Text("Columns", style: TextStyle(fontSize: 12, color: Color(0xFF4154F1))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.file_download, size: 14),
              label: const Text("Excel", style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4154F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: const Size(70, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                elevation: 0,
              ),
              child: const Text("Search", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    } else {
      return Row(
        children: [
          ColumnsDropdownButton(
            allColumns: _allColumns,
            visibleColumns: _visibleColumns,
            onToggleColumn: _toggleColumn,
            color: const Color(0xFF4154F1),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _exportExcel,
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text("Excel", style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(100, 40),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4154F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(100, 40),
              elevation: 0,
            ),
            child: const Text("Search", style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      );
    }
  }

  // Helper method to show column selector on mobile
  void _showColumnSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Columns",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _allColumns.length,
                  itemBuilder: (context, index) {
                    final col = _allColumns[index];
                    final isVisible = _visibleColumns.contains(col);
                    return CheckboxListTile(
                      value: isVisible,
                      title: Text(col.title, style: const TextStyle(fontSize: 14)),
                      activeColor: const Color(0xFF4154F1),
                      onChanged: (value) {
                        _toggleColumn(col, value ?? false);
                        Navigator.pop(context);
                        _showColumnSelector(); // Reopen to show updated state
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4154F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Done"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // UPDATED: Table with responsive column widths
  Widget _buildTable(bool isMobile) {
    double colWidth = isMobile ? 110.0 : 150.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: const Text("Taxwise Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        ),
        Expanded(
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _visibleColumns.length * colWidth,
                child: Column(
                  children: [
                    _buildHeaderRow(56, colWidth),
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScroll,
                        itemCount: _allRows.length,
                        itemBuilder: (context, i) {
                          final row = _allRows[i];
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                            child: Row(
                              children: _visibleColumns.map((col) => Container(
                                width: colWidth,
                                height: 48,
                                alignment: _isNumeric(col.key) ? Alignment.centerRight : Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                    color: i % 2 == 0 ? Colors.white : const Color(0xFFF9FAFC),
                                    border: Border(right: BorderSide(color: Colors.grey.shade200))
                                ),
                                child: Text(
                                  row.getField(col.key),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF2C3E50)),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              )).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildTotalRow(48, colWidth),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(double height, double colWidth) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
              top: BorderSide(color: Colors.grey.shade300)
          )
      ),
      child: Row(
        children: _visibleColumns.map((col) => Container(
          width: colWidth,
          height: height,
          alignment: _isNumeric(col.key) ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
          child: Text(
            col.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2C3E50)),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: _isNumeric(col.key) ? TextAlign.right : TextAlign.left,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTotalRow(double height, double colWidth) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF0F2FF),
          border: Border(top: BorderSide(color: const Color(0xFF4154F1).withOpacity(0.3), width: 2))
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          String displayValue = "";
          if (col.key == 'restaurant') {
            displayValue = "Total";
          } else if (col.key == 'billNo' || col.key == 'billDate') {
            displayValue = "";
          } else {
            displayValue = _totals[col.key]?.toString() ?? '0.000';
          }
          return Container(
            width: colWidth,
            height: height,
            alignment: _isNumeric(col.key) ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text(
              displayValue,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4154F1)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Col {
  final String title, key;
  const _Col(this.title, this.key);

  @override
  bool operator ==(Object other) => other is _Col && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class _TaxwiseBillRow {
  final String restaurant, billNo, billDate, taxableAmount;
  final Map<String, dynamic> taxAmounts;

  _TaxwiseBillRow({required this.restaurant, required this.billNo, required this.billDate, required this.taxableAmount, required this.taxAmounts});

  String getField(String key) {
    String format3(String? val) {
      if (val == null) return "0.000";
      double d = double.tryParse(val) ?? 0.0;
      return d.toStringAsFixed(3);
    }
    switch (key) {
      case 'restaurant': return restaurant;
      case 'billNo': return billNo;
      case 'billDate': return billDate;
      case 'taxableAmount': return format3(taxableAmount);
      default: return format3(taxAmounts[key]?.toString());
    }
  }
}

class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns, visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;
  final Color color;

  const ColumnsDropdownButton({super.key, required this.allColumns, required this.visibleColumns, required this.onToggleColumn, this.color = const Color(0xFF4154F1)});

  @override
  State<ColumnsDropdownButton> createState() => _ColumnsDropdownButtonState();
}

class _ColumnsDropdownButtonState extends State<ColumnsDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _dropdownOverlay;

  void _showDropdown() {
    if (_dropdownOverlay != null) return;
    _dropdownOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _removeDropdown)),
          Positioned(
            width: 280,
            child: CompositedTransformFollower(
              link: _layerLink,
              offset: const Offset(0, 45),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: StatefulBuilder(
                    builder: (context, setMenuState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                          child: Row(children: [
                            Icon(Icons.view_column, size: 18, color: widget.color),
                            const SizedBox(width: 8),
                            const Text("Select Columns", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)))
                          ]),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: widget.allColumns.map((col) {
                              final checked = widget.visibleColumns.contains(col);
                              return CheckboxListTile(
                                value: checked,
                                title: Text(col.title, style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50))),
                                activeColor: widget.color,
                                dense: true,
                                onChanged: (v) {
                                  widget.onToggleColumn(col, v!);
                                  setMenuState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: _removeDropdown,
                                style: ElevatedButton.styleFrom(backgroundColor: widget.color),
                                child: const Text("Done", style: TextStyle(color: Colors.white))
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_dropdownOverlay!);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OutlinedButton.icon(
        onPressed: _showDropdown,
        icon: const Icon(Icons.view_column, size: 16),
        label: const Text("Columns", style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.color,
          side: BorderSide(color: widget.color.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size(110, 40),
        ),
      ),
    );
  }
}