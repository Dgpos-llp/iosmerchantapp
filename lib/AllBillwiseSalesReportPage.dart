import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/main.dart';
import 'SidePanel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

class AllBillwiseSalesReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllBillwiseSalesReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllBillwiseSalesReportPage> createState() => _AllBillwiseSalesReportPageState();
}

class _AllBillwiseSalesReportPageState extends State<AllBillwiseSalesReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;

  // Animation states
  bool _isHoveringRefresh = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  final List<_Col> _baseColumns = const [
    _Col('Restaurants', 'restaurant'),
    _Col('Bill No', 'billNo'),
    _Col('Bill Date', 'billDate'),
    _Col('Customer Name', 'customerName'),
    _Col('Subtotal', 'subtotal'),
    _Col('Discount', 'billDiscount'),
    _Col('Net Total', 'netTotal'),
    _Col('Grand Amount', 'grandAmount'),
    _Col('Round Off', 'roundOff'),
    _Col('Tip Amount', 'tipAmount'),
    _Col('Remark', 'remark'),
    _Col('Packaging Charge', 'packagingCharge'),
    _Col('Delivery Charges', 'deliveryCharges'),
    _Col('Discount %', 'discountPercent'),
  ];

  List<_Col> _taxColumns = [];
  List<_Col> _settlementColumns = [];
  late List<_Col> _allColumns;
  late List<_Col> _visibleColumns;

  List<Map<String, dynamic>> _allRows = [];
  Map<String, dynamic> totals = {};

  List<String> taxColumnNames = [];
  Map<String, dynamic> taxTotals = {};

  List<String> settlementColumnNames = [];
  Map<String, dynamic> settlementTotals = {};

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _updateColumnLists();
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

  void _updateColumnLists() {
    _taxColumns = taxColumnNames.map((name) {
      String displayName = name.replaceAll('_', ' ');
      displayName = displayName.replaceAllMapped(
          RegExp(r'(\d+(\.\d+)?)$'), (match) => '${match.group(1)}%');
      return _Col(displayName, name);
    }).toList();

    _settlementColumns = settlementColumnNames.map((name) {
      return _Col(name, name);
    }).toList();

    _allColumns = [
      ..._baseColumns.sublist(0, 10),
      ..._settlementColumns,
      ..._taxColumns,
      ..._baseColumns.sublist(10)
    ];

    _visibleColumns = List.from(_allColumns);
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    totals = {
      'subtotal': 0.0,
      'billDiscount': 0.0,
      'netTotal': 0.0,
      'grandAmount': 0.0,
      'roundOff': 0.0,
      'tipAmount': 0.0,
      'packagingCharge': 0.0,
      'deliveryCharges': 0.0,
    };

    taxColumnNames = [];
    taxTotals = {};
    settlementColumnNames = [];
    settlementTotals = {};

    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList;
    if (selectedDbKey == null || selectedDbKey == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = [selectedDbKey!];
    }

    Map<String, List<BillwiseReport>> dbToBillwise =
    await UserData.fetchBillwiseForDbs(config, dbList, startDate, endDate);

    _collectUniqueColumns(dbToBillwise);

    if (selectedDbKey == null || selectedDbKey == "All") {
      for (final db in dbToBillwise.keys) {
        for (final bill in dbToBillwise[db]!) {
          _addRowsFromBill(bill, widget.dbToBrandMap[db] ?? db);
        }
      }
    } else {
      for (final db in dbToBillwise.keys) {
        for (final bill in dbToBillwise[db]!) {
          _addRowsFromBill(bill, widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!);
        }
      }
    }

    _updateColumnLists();
    setState(() => _loading = false);
  }

  void _collectUniqueColumns(Map<String, List<BillwiseReport>> dbToBillwise) {
    Set<String> uniqueTaxColumns = {};
    Set<String> uniqueSettlementColumns = {};

    for (final db in dbToBillwise.keys) {
      for (final bill in dbToBillwise[db]!) {
        List<dynamic> taxBreakup = bill.taxBreakup ?? [];
        for (var tax in taxBreakup) {
          String taxName = tax['name'] ?? '';
          String taxPercent = tax['percent'] ?? '';
          String columnKey = "${taxName}_${taxPercent}";

          if (!uniqueTaxColumns.contains(columnKey)) {
            uniqueTaxColumns.add(columnKey);
            taxColumnNames.add(columnKey);
            taxTotals[columnKey] = 0.0;
          }
        }

        List<dynamic> settlementBreakup = bill.settlementBreakup ?? [];
        for (var settlement in settlementBreakup) {
          String settlementName = settlement['name'] ?? '';
          String columnKey = settlementName;

          if (!uniqueSettlementColumns.contains(columnKey)) {
            uniqueSettlementColumns.add(columnKey);
            settlementColumnNames.add(columnKey);
            settlementTotals[columnKey] = 0.0;
          }
        }
      }
    }
  }

  void _addRowsFromBill(BillwiseReport bill, String restaurant) {
    List<dynamic> settlements = bill.settlements ?? [];
    settlements = settlements.isNotEmpty ? settlements : [{}];

    Map<String, String> taxAmountMap = {};
    List<dynamic> taxBreakup = bill.taxBreakup ?? [];
    for (var tax in taxBreakup) {
      String taxName = tax['name'] ?? '';
      String taxPercent = tax['percent'] ?? '';
      String columnKey = "${taxName}_${taxPercent}";
      taxAmountMap[columnKey] = _to3(tax['amount']);

      double amount = double.tryParse(tax['amount']?.toString() ?? '0.000') ?? 0.0;
      taxTotals[columnKey] = (taxTotals[columnKey] ?? 0.0) + amount;
    }

    Map<String, String> settlementAmountMap = {};
    List<dynamic> settlementBreakup = bill.settlementBreakup ?? [];
    for (var settlement in settlementBreakup) {
      String settlementName = settlement['name'] ?? '';
      settlementAmountMap[settlementName] = _to3(settlement['amount']);

      double amount = double.tryParse(settlement['amount']?.toString() ?? '0.000') ?? 0.0;
      settlementTotals[settlementName] = (settlementTotals[settlementName] ?? 0.0) + amount;
    }

    for (int i = 0; i < settlements.length; i++) {
      bool isFirst = i == 0;

      Map<String, dynamic> row = {
        'restaurant': restaurant,
        'billNo': isFirst ? (bill.billNo ?? '') : '',
        'billDate': isFirst ? (bill.billDate ?? '') : '',
        'customerName': isFirst ? (bill.customerName ?? '') : '',
        'subtotal': isFirst ? _to3(bill.subtotal) : '',
        'billDiscount': isFirst ? _to3(bill.billDiscount) : '',
        'netTotal': isFirst ? _to3(bill.netTotal) : '',
        'grandAmount': isFirst ? _to3(bill.grandAmount) : '',
        'roundOff': isFirst ? _to3(bill.roundOff) : '',
        'tipAmount': isFirst ? _to3(bill.tipAmount) : '',
        'remark': isFirst ? (bill.remark ?? '') : '',
        'packagingCharge': isFirst ? _to3(bill.packagingCharge) : '',
        'deliveryCharges': isFirst ? _to3(bill.deliveryCharges) : '',
        'discountPercent': isFirst ? _to3(bill.discountPercent) : '',
      };

      for (String taxColumn in taxColumnNames) {
        row[taxColumn] = isFirst ? (taxAmountMap[taxColumn] ?? '0.000') : '';
      }

      for (String settlementColumn in settlementColumnNames) {
        row[settlementColumn] = isFirst ? (settlementAmountMap[settlementColumn] ?? '0.000') : '';
      }

      _allRows.add(row);

      if (isFirst) {
        totals['subtotal'] = totals['subtotal']! + double.tryParse(bill.subtotal ?? '0.000')!;
        totals['billDiscount'] = totals['billDiscount']! + double.tryParse(bill.billDiscount ?? '0.000')!;
        totals['netTotal'] = totals['netTotal']! + double.tryParse(bill.netTotal ?? '0.000')!;
        totals['grandAmount'] = totals['grandAmount']! + double.tryParse(bill.grandAmount ?? '0.000')!;
        totals['roundOff'] = totals['roundOff']! + double.tryParse(bill.roundOff ?? '0.000')!;
        totals['tipAmount'] = totals['tipAmount']! + double.tryParse(bill.tipAmount ?? '0.000')!;
        totals['packagingCharge'] = totals['packagingCharge']! + double.tryParse(bill.packagingCharge ?? '0.000')!;
        totals['deliveryCharges'] = totals['deliveryCharges']! + double.tryParse(bill.deliveryCharges ?? '0.000')!;
      }
    }
  }

  String _to3(dynamic v) {
    double? d = double.tryParse(v?.toString() ?? '0.000');
    return d != null ? d.toStringAsFixed(3) : '0.000';
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
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];
    final boldStyle = excel.CellStyle(bold: true);

    int rowNum = 0;
    final reportCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
    reportCell.value = "Billwise Sales Report";
    reportCell.cellStyle = boldStyle;
    rowNum += 2;

    sheet.appendRow(["Date From", DateFormat('dd-MM-yyyy').format(_startDate), "Date To", DateFormat('dd-MM-yyyy').format(_endDate)]);
    rowNum += 2;

    final headerTitles = _visibleColumns.map((c) => c.title).toList();
    for (int i = 0; i < headerTitles.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = headerTitles[i];
      cell.cellStyle = boldStyle;
    }
    rowNum++;

    for (final row in _allRows) {
      for (int i = 0; i < _visibleColumns.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = row[_visibleColumns[i].key] ?? '';
      }
      rowNum++;
    }

    // Totals Row in Excel
    for (int i = 0; i < _visibleColumns.length; i++) {
      final colKey = _visibleColumns[i].key;
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      if (colKey == 'restaurant') cell.value = 'Total';
      else if (totals.containsKey(colKey)) cell.value = _to3(totals[colKey]);
      else if (taxTotals.containsKey(colKey)) cell.value = _to3(taxTotals[colKey]);
      else if (settlementTotals.containsKey(colKey)) cell.value = _to3(settlementTotals[colKey]);
      cell.cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();
    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'AllBillwiseSales.xlsx');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel downloaded successfully'), backgroundColor: Color(0xFF27AE60), behavior: SnackBarBehavior.floating));
      }
    } else {
      final String path = '${Directory.current.path}/AllBillwiseSales.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel exported successfully to $path'), backgroundColor: const Color(0xFF27AE60), behavior: SnackBarBehavior.floating));
      }
      try {
        if (Platform.isWindows) await Process.run('start', [path], runInShell: true);
        else if (Platform.isMacOS) await Process.run('open', [path]);
        else if (Platform.isLinux) await Process.run('xdg-open', [path]);
      } catch (_) {}
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
            "Billwise Sales Report",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
          ),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandDropdownItems, safeSelectedDbKey, brandDisplayMap),
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
            _buildFilterSection(brandDropdownItems, safeSelectedDbKey, brandDisplayMap, isMobile),
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
                  child: _buildTable(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSelector(List<String> keys, String selected, Map<String, String> displayMap) {
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
                items: keys.map((key) => DropdownMenuItem(
                  value: key,
                  child: Text(displayMap[key] ?? key, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
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
          const Text("Billwise Sales", style: TextStyle(color: Color(0xFF4154F1), fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(List<String> keys, String selected, Map<String, String> displayMap, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end, // Aligns buttons with the input boxes
          children: [
            _buildDateFilter("Start Date", _startDate, (d) { setState(() => _startDate = d); _fetchData(); }),
            const SizedBox(width: 16),
            _buildDateFilter("End Date", _endDate, (d) { setState(() => _endDate = d); _fetchData(); }),
            const SizedBox(width: 16),
            if (!hasOnlyOneDb) _buildDropdownFilter("Outlet", keys, selected, displayMap),
            const SizedBox(width: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilter(String label, DateTime date, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: 150, height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF7F8C8D)),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(String label, List<String> keys, String selected, Map<String, String> displayMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 4),
        Container(
          width: 180, height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: keys.contains(selected) ? selected : keys.first,
              isExpanded: true,
              items: keys.map((v) => DropdownMenuItem(value: v, child: Text(displayMap[v] ?? v, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) { setState(() => selectedDbKey = val); _fetchData(); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(100, 40),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _fetchData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4154F1),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              minimumSize: const Size(100, 40),
            ),
            child: const Text("Search", style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: const Text("Detailed Sales Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        ),
        Expanded(
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _visibleColumns.length * 180.0,
                child: Column(
                  children: [
                    _buildHeaderRow(),
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScroll,
                        itemCount: _allRows.length,
                        itemBuilder: (context, i) {
                          final row = _allRows[i];
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                            child: Row(
                              children: _visibleColumns.map((col) {
                                // Determine alignment based on key
                                bool isNumeric = [
                                  'subtotal', 'billDiscount', 'netTotal', 'grandAmount',
                                  'roundOff', 'tipAmount', 'packagingCharge', 'deliveryCharges',
                                  'discountPercent'
                                ].contains(col.key) ||
                                    taxColumnNames.contains(col.key) ||
                                    settlementColumnNames.contains(col.key);

                                return Container(
                                  width: 180, height: 48,
                                  alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : const Color(0xFFF9FAFC), border: Border(right: BorderSide(color: Colors.grey.shade200))),
                                  child: Text(row[col.key]?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50))),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildTotalRow(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), border: Border(bottom: BorderSide(color: Colors.grey.shade300), top: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        children: _visibleColumns.map((col) {
          // Align header text with column data
          bool isNumeric = [
            'subtotal', 'billDiscount', 'netTotal', 'grandAmount',
            'roundOff', 'tipAmount', 'packagingCharge', 'deliveryCharges',
            'discountPercent'
          ].contains(col.key) ||
              taxColumnNames.contains(col.key) ||
              settlementColumnNames.contains(col.key);

          return Container(
            width: 180, height: 56,
            alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2C3E50))),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF0F2FF), border: Border(top: BorderSide(color: const Color(0xFF4154F1).withOpacity(0.3), width: 2))),
      child: Row(
        children: _visibleColumns.map((col) {
          String text = '';
          if (col.key == 'restaurant') text = 'Total';
          else if (totals.containsKey(col.key)) text = _to3(totals[col.key]);
          else if (taxTotals.containsKey(col.key)) text = _to3(taxTotals[col.key]);
          else if (settlementTotals.containsKey(col.key)) text = _to3(settlementTotals[col.key]);

          // Determine alignment for the total row
          bool isNumeric = [
            'subtotal', 'billDiscount', 'netTotal', 'grandAmount',
            'roundOff', 'tipAmount', 'packagingCharge', 'deliveryCharges',
            'discountPercent'
          ].contains(col.key) ||
              taxColumnNames.contains(col.key) ||
              settlementColumnNames.contains(col.key);

          return Container(
            width: 180, height: 48,
            alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4154F1))),
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
                elevation: 8, borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: StatefulBuilder(
                    builder: (context, setMenuState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                          child: Row(children: [Icon(Icons.view_column, size: 18, color: widget.color), const SizedBox(width: 8), const Text("Select Columns", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)))]),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: ListView(
                            shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8),
                            children: widget.allColumns.map((col) {
                              final checked = widget.visibleColumns.contains(col);
                              return CheckboxListTile(
                                value: checked, title: Text(col.title, style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50))),
                                activeColor: widget.color, dense: true,
                                onChanged: (v) { widget.onToggleColumn(col, v!); setMenuState(() {}); },
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _removeDropdown, style: ElevatedButton.styleFrom(backgroundColor: widget.color), child: const Text("Done", style: TextStyle(color: Colors.white)))),
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

  void _removeDropdown() { _dropdownOverlay?.remove(); _dropdownOverlay = null; }

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
          minimumSize: const Size(110, 40), // Height set to 40
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

class BillwiseReport {
  final String billNo;
  final String customerName;
  final String billDate;
  final String subtotal;
  final String settlementModeName;
  final String billDiscount;
  final String? billTax;
  final String? remark;
  final String deliveryCharges;
  final String netTotal;
  final String grandAmount;
  final String discountPercent;
  final String packagingCharge;
  final String roundOff;
  final String? tipAmount;
  final List<dynamic>? settlements;
  final List<dynamic>? taxBreakup;
  final List<dynamic>? settlementBreakup;

  BillwiseReport({
    required this.billNo,
    required this.customerName,
    required this.billDate,
    required this.subtotal,
    required this.settlementModeName,
    required this.billDiscount,
    this.billTax,
    this.remark,
    required this.deliveryCharges,
    required this.netTotal,
    required this.grandAmount,
    required this.discountPercent,
    required this.packagingCharge,
    required this.roundOff,
    this.tipAmount,
    this.settlements,
    this.taxBreakup,
    this.settlementBreakup,
  });

  factory BillwiseReport.fromJson(Map<String, dynamic> json) {
    return BillwiseReport(
      billNo: json['billNo'] ?? '',
      customerName: json['customerName'] ?? '',
      billDate: json['billDate'] ?? '',
      subtotal: json['subtotal'] ?? '',
      settlementModeName: json['settlementModeName'] ?? '',
      billDiscount: json['billDiscount'] ?? '',
      billTax: json['billTax']?.toString(),
      remark: json['remark']?.toString(),
      deliveryCharges: json['deliveryCharges'] ?? '',
      netTotal: json['netTotal'] ?? '',
      grandAmount: json['grandAmount'] ?? '',
      discountPercent: json['discountPercent'] ?? '',
      packagingCharge: json['packagingCharge'] ?? '',
      roundOff: json['roundOff'] ?? '',
      tipAmount: json['tipAmount'] ?? '',
      settlements: json['settlements'],
      taxBreakup: json['taxBreakup'],
      settlementBreakup: json['settlementBreakup'],
    );
  }
}