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

class AllDayEndReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllDayEndReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllDayEndReportPage> createState() => _AllDayEndReportPageState();
}

class _AllDayEndReportPageState extends State<AllDayEndReportPage> {
  DateTime _selectedDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;
  bool _isHoveringRefresh = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  // Numeric keys for right alignment
  final List<String> _numericKeys = [
    'dineInSaleAmt', 'homeDeliverySaleAmt', 'takeAwaySaleAmt', 'counterSaleAmt',
    'onlineSaleAmt', 'advanceOrderSaleAmt', 'orderTypeTotal',
    'deliveryChargeAmt', 'packagingChargeAmt', 'roundOffAmt', 'tipAmt',
    'cancelAmt', 'paxCount', 'settlementTotal', 'advanceSettlementTotal'
  ];

  final List<_Col> _baseColumns = [
    const _Col('Restaurant', 'restaurant'),
    const _Col('Date', 'posDate'),
    const _Col('Dine In', 'dineInSaleAmt'),
    const _Col('Home Del', 'homeDeliverySaleAmt'),
    const _Col('Take Away', 'takeAwaySaleAmt'),
    const _Col('Counter', 'counterSaleAmt'),
    const _Col('Online', 'onlineSaleAmt'),
    const _Col('Advance', 'advanceOrderSaleAmt'),
    const _Col('Order Total', 'orderTypeTotal'),
    const _Col('Bills', 'noOfBills'),
    const _Col('Del Chg', 'deliveryChargeAmt'),
    const _Col('Pkg Chg', 'packagingChargeAmt'),
    const _Col('Round Off', 'roundOffAmt'),
    const _Col('Tip', 'tipAmt'),
    const _Col('Cancel Bills', 'noOfCancelBills'),
    const _Col('Cancel Amt', 'cancelAmt'),
    const _Col('Pax', 'paxCount'),
  ];

  List<_Col> _settlementColumns = [];
  List<_Col> _advanceSettlementColumns = [];
  List<_Col> _groupColumns = [];
  List<_Col> _taxColumns = [];

  late List<_Col> _allColumns;
  late List<_Col> _visibleColumns;

  List<Map<String, dynamic>> _allRows = [];
  Map<String, dynamic> totals = {};
  List<GroupSalesData> _allGroupRows = [];

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  final DateFormat _apiDateFormat = DateFormat('dd-MM-yyyy');

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
    // Settlement columns will be populated dynamically from data
    _settlementColumns = [];
    _advanceSettlementColumns = [];
    _groupColumns = [];
    _taxColumns = [];

    _allColumns = [
      ..._baseColumns,
      ..._settlementColumns,
      ..._advanceSettlementColumns,
      ..._taxColumns,
      ..._groupColumns,
    ];

    _visibleColumns = List.from(_allColumns);
  }

  String _format3(dynamic value) {
    if (value == null) return '0.000';
    double? d = double.tryParse(value.toString().replaceAll(',', ''));
    return d != null ? d.toStringAsFixed(3) : '0.000';
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    _allGroupRows = [];

    // Reset totals
    totals = {
      'dineInSaleAmt': 0.0,
      'homeDeliverySaleAmt': 0.0,
      'takeAwaySaleAmt': 0.0,
      'counterSaleAmt': 0.0,
      'onlineSaleAmt': 0.0,
      'advanceOrderSaleAmt': 0.0,
      'orderTypeTotal': 0.0,
      'noOfBills': 0.0,
      'deliveryChargeAmt': 0.0,
      'packagingChargeAmt': 0.0,
      'roundOffAmt': 0.0,
      'tipAmt': 0.0,
      'noOfCancelBills': 0.0,
      'cancelAmt': 0.0,
      'paxCount': 0.0,
      'settlementTotal': 0.0,
      'advanceSettlementTotal': 0.0,
    };

    final config = await Config.loadFromAsset();
    String posDate = _apiDateFormat.format(_selectedDate);

    List<String> dbList = (selectedDbKey == null || selectedDbKey == "All")
        ? widget.dbToBrandMap.keys.toList()
        : [selectedDbKey!];

    Map<String, DayEndReport> dbToDayEnd =
    await UserData.fetchDayEndForDbs(config, dbList, posDate);

    // Collect unique settlement and advance settlement modes
    Set<String> uniqueSettlementModes = {};
    Set<String> uniqueAdvanceSettlementModes = {};
    Set<String> taxKeys = {};
    Map<String, double> settlementTotals = {};
    Map<String, double> advanceSettlementTotals = {};
    Map<String, double> taxTotals = {};

    for (final entry in dbToDayEnd.entries) {
      final report = entry.value;

      // Collect settlement modes
      report.settlementAmounts.forEach((mode, amount) {
        uniqueSettlementModes.add(mode);
        settlementTotals[mode] = (settlementTotals[mode] ?? 0) + (double.tryParse(amount.toString()) ?? 0);
      });

      // Collect advance settlement modes
      report.advanceSettlementAmounts.forEach((mode, amount) {
        uniqueAdvanceSettlementModes.add(mode);
        advanceSettlementTotals[mode] = (advanceSettlementTotals[mode] ?? 0) + (double.tryParse(amount.toString()) ?? 0);
      });

      // Collect tax keys
      report.parsedTaxes.forEach((name, amount) {
        taxKeys.add(name);
        taxTotals[name] = (taxTotals[name] ?? 0) + amount;
      });

      // Collect group data
      _allGroupRows.addAll(report.groupSalesList);
    }

    // Create dynamic columns
    _settlementColumns = uniqueSettlementModes.map((mode) =>
        _Col('Settle: $mode', 'settle_$mode')).toList();

    _advanceSettlementColumns = uniqueAdvanceSettlementModes.map((mode) =>
        _Col('Adv: $mode', 'advSettle_$mode')).toList();

    _taxColumns = taxKeys.map((name) =>
        _Col('Tax: $name', 'tax_$name')).toList();

    // Create rows
    for (final entry in dbToDayEnd.entries) {
      final dbKey = entry.key;
      final report = entry.value;
      final brand = widget.dbToBrandMap[dbKey] ?? dbKey;

      Map<String, dynamic> row = {
        'restaurant': brand,
        'posDate': posDate,
        'dineInSaleAmt': _format3(report.dineInSaleAmt),
        'homeDeliverySaleAmt': _format3(report.homeDeliverySaleAmt),
        'takeAwaySaleAmt': _format3(report.takeAwaySaleAmt),
        'counterSaleAmt': _format3(report.counterSaleAmt),
        'onlineSaleAmt': _format3(report.onlineSaleAmt),
        'advanceOrderSaleAmt': _format3(report.advanceOrderSaleAmt),
        'orderTypeTotal': _format3(report.orderTypeTotal),
        'noOfBills': report.noOfBills,
        'deliveryChargeAmt': _format3(report.deliveryChargeAmt),
        'packagingChargeAmt': _format3(report.packagingChargeAmt),
        'roundOffAmt': _format3(report.roundOffAmt),
        'tipAmt': _format3(report.tipAmt),
        'noOfCancelBills': report.noOfCancelBills,
        'cancelAmt': _format3(report.cancelAmt),
        'paxCount': report.paxCount,
      };

      // Add settlement amounts
      for (final mode in uniqueSettlementModes) {
        row['settle_$mode'] = _format3(report.settlementAmounts[mode]);
      }

      // Add advance settlement amounts
      for (final mode in uniqueAdvanceSettlementModes) {
        row['advSettle_$mode'] = _format3(report.advanceSettlementAmounts[mode]);
      }

      // Add tax amounts
      final parsedTaxes = report.parsedTaxes;
      for (final name in taxKeys) {
        row['tax_$name'] = _format3(parsedTaxes[name]);
      }

      _allRows.add(row);

      // Calculate totals
      totals['dineInSaleAmt'] = totals['dineInSaleAmt']! + (double.tryParse(report.dineInSaleAmt) ?? 0);
      totals['homeDeliverySaleAmt'] = totals['homeDeliverySaleAmt']! + (double.tryParse(report.homeDeliverySaleAmt) ?? 0);
      totals['takeAwaySaleAmt'] = totals['takeAwaySaleAmt']! + (double.tryParse(report.takeAwaySaleAmt) ?? 0);
      totals['counterSaleAmt'] = totals['counterSaleAmt']! + (double.tryParse(report.counterSaleAmt) ?? 0);
      totals['onlineSaleAmt'] = totals['onlineSaleAmt']! + (double.tryParse(report.onlineSaleAmt) ?? 0);
      totals['advanceOrderSaleAmt'] = totals['advanceOrderSaleAmt']! + (double.tryParse(report.advanceOrderSaleAmt) ?? 0);
      totals['orderTypeTotal'] = totals['orderTypeTotal']! + report.orderTypeTotal;
      totals['noOfBills'] = totals['noOfBills']! + (double.tryParse(report.noOfBills) ?? 0);
      totals['deliveryChargeAmt'] = totals['deliveryChargeAmt']! + (double.tryParse(report.deliveryChargeAmt) ?? 0);
      totals['packagingChargeAmt'] = totals['packagingChargeAmt']! + (double.tryParse(report.packagingChargeAmt) ?? 0);
      totals['roundOffAmt'] = totals['roundOffAmt']! + (double.tryParse(report.roundOffAmt) ?? 0);
      totals['tipAmt'] = totals['tipAmt']! + (double.tryParse(report.tipAmt) ?? 0);
      totals['noOfCancelBills'] = totals['noOfCancelBills']! + (double.tryParse(report.noOfCancelBills) ?? 0);
      totals['cancelAmt'] = totals['cancelAmt']! + (double.tryParse(report.cancelAmt) ?? 0);
      totals['paxCount'] = totals['paxCount']! + (double.tryParse(report.paxCount) ?? 0);
      totals['settlementTotal'] = totals['settlementTotal']! + report.settlementTotal;
      totals['advanceSettlementTotal'] = totals['advanceSettlementTotal']! + report.advanceSettlementTotal;
    }

    // Add group summary columns
    if (_allGroupRows.isNotEmpty) {
      _groupColumns = [
        const _Col('Group', 'groupName'),
        const _Col('Group Net', 'groupNetTotal'),
        const _Col('Group Gross', 'groupGrossTotal'),
      ];
    }

    _updateColumnLists();
    setState(() => _loading = false);
  }

  Map<String, dynamic> get totalRow {
    Map<String, dynamic> row = {
      'restaurant': 'Total',
      'posDate': '',
      'dineInSaleAmt': _format3(totals['dineInSaleAmt']),
      'homeDeliverySaleAmt': _format3(totals['homeDeliverySaleAmt']),
      'takeAwaySaleAmt': _format3(totals['takeAwaySaleAmt']),
      'counterSaleAmt': _format3(totals['counterSaleAmt']),
      'onlineSaleAmt': _format3(totals['onlineSaleAmt']),
      'advanceOrderSaleAmt': _format3(totals['advanceOrderSaleAmt']),
      'orderTypeTotal': _format3(totals['orderTypeTotal']),
      'noOfBills': totals['noOfBills']?.toStringAsFixed(0) ?? '0',
      'deliveryChargeAmt': _format3(totals['deliveryChargeAmt']),
      'packagingChargeAmt': _format3(totals['packagingChargeAmt']),
      'roundOffAmt': _format3(totals['roundOffAmt']),
      'tipAmt': _format3(totals['tipAmt']),
      'noOfCancelBills': totals['noOfCancelBills']?.toStringAsFixed(0) ?? '0',
      'cancelAmt': _format3(totals['cancelAmt']),
      'paxCount': totals['paxCount']?.toStringAsFixed(0) ?? '0',
    };

    // Add settlement totals
    for (final col in _settlementColumns) {
      String mode = col.key.replaceFirst('settle_', '');
      double total = 0;
      for (final row in _allRows) {
        total += double.tryParse(row[col.key]?.toString() ?? '0') ?? 0;
      }
      row[col.key] = _format3(total);
    }

    // Add advance settlement totals
    for (final col in _advanceSettlementColumns) {
      String mode = col.key.replaceFirst('advSettle_', '');
      double total = 0;
      for (final row in _allRows) {
        total += double.tryParse(row[col.key]?.toString() ?? '0') ?? 0;
      }
      row[col.key] = _format3(total);
    }

    // Add tax totals
    for (final col in _taxColumns) {
      String name = col.key.replaceFirst('tax_', '');
      double total = 0;
      for (final row in _allRows) {
        total += double.tryParse(row[col.key]?.toString() ?? '0') ?? 0;
      }
      row[col.key] = _format3(total);
    }

    return row;
  }

  void _toggleColumn(_Col col, bool value) {
    setState(() {
      if (value) {
        if (!_visibleColumns.contains(col)) {
          int originalIndex = _allColumns.indexOf(col);
          int insertIndex = 0;
          for (int i = 0; i < _visibleColumns.length; i++) {
            if (_allColumns.indexOf(_visibleColumns[i]) > originalIndex) break;
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
      final sheet = excelFile['Day End Report'];
      final boldStyle = excel.CellStyle(bold: true);

      int rowNum = 0;
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum))
        ..value = "Day End Report"
        ..cellStyle = boldStyle;
      rowNum += 2;

      sheet.appendRow(["POS Date", _apiDateFormat.format(_selectedDate)]);
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
            ..value = row[_visibleColumns[i].key] ?? '';
        }
        rowNum++;
      }

      // Totals row
      for (int i = 0; i < _visibleColumns.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum))
          ..value = totalRow[_visibleColumns[i].key] ?? ''
          ..cellStyle = boldStyle;
      }
      rowNum += 2;

      // Group Sales section if available
      if (_allGroupRows.isNotEmpty) {
        sheet.appendRow([]);
        sheet.appendRow(["Group Sales Details"]);
        sheet.appendRow(["Group Name", "Net Total", "Gross Total"]);

        double groupNetTotal = 0;
        double groupGrossTotal = 0;

        for (final group in _allGroupRows) {
          sheet.appendRow([
            group.groupName,
            group.netTotal,
            group.grossTotal,
          ]);
          groupNetTotal += double.tryParse(group.netTotal) ?? 0;
          groupGrossTotal += double.tryParse(group.grossTotal) ?? 0;
        }

        sheet.appendRow([
          "Total",
          _format3(groupNetTotal),
          _format3(groupGrossTotal),
        ]);
      }

      final fileBytes = excelFile.encode();

      if (kIsWeb) {
        web_exporter.saveFileWeb(fileBytes!, 'DayEndReport.xlsx');
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
        final String path = '${directory.path}/DayEndReport_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
            "Day End",
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
    return Row(children: [
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
              onChanged: (v) {
                setState(() => selectedDbKey = v);
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
    ]);
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
      child: Row(children: [
        const Icon(Icons.home, color: Color(0xFF7F8C8D), size: 16),
        const SizedBox(width: 7),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text("Reports", style: TextStyle(color: Color(0xFF7F8C8D), decoration: TextDecoration.underline, fontSize: 13)),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF7F8C8D), size: 16),
        const Text("Day End", style: TextStyle(color: Color(0xFF4154F1), fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
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
          _buildDateFilter("POS Date", _selectedDate, (d) { setState(() => _selectedDate = d); _fetchData(); }, isMobile: false),
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
        // Date filter (full width on mobile)
        _buildDateFilter("POS Date", _selectedDate, (d) { setState(() => _selectedDate = d); _fetchData(); }, isMobile: true),
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
              lastDate: DateTime.now(),
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
      return Row(children: [
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
      ]);
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
    double colWidth = isMobile ? 100.0 : 130.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: const Text("Day End Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
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
                              children: _visibleColumns.map((col) {
                                bool isNumeric = _numericKeys.contains(col.key) ||
                                    col.key.startsWith('settle_') ||
                                    col.key.startsWith('advSettle_') ||
                                    col.key.startsWith('tax_');
                                return Container(
                                  width: colWidth,
                                  height: 48,
                                  alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(
                                      color: i % 2 == 0 ? Colors.white : const Color(0xFFF9FAFC),
                                      border: Border(right: BorderSide(color: Colors.grey.shade200))
                                  ),
                                  child: Text(
                                    row[col.key]?.toString() ?? '',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2C3E50)),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
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

  Widget _buildHeaderRow(double h, double w) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          bool isNumeric = _numericKeys.contains(col.key) ||
              col.key.startsWith('settle_') ||
              col.key.startsWith('advSettle_') ||
              col.key.startsWith('tax_');
          return Container(
            width: w,
            height: h,
            alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text(
              col.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2C3E50)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              textAlign: isNumeric ? TextAlign.right : TextAlign.left,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow(double h, double w) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        border: Border(top: BorderSide(color: const Color(0xFF4154F1).withOpacity(0.3), width: 2)),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          bool isNumeric = _numericKeys.contains(col.key) ||
              col.key.startsWith('settle_') ||
              col.key.startsWith('advSettle_') ||
              col.key.startsWith('tax_');
          return Container(
            width: w,
            height: h,
            alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
            child: Text(
              totalRow[col.key]?.toString() ?? '',
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

// Reuse the ColumnsDropdownButton from your existing code
class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns, visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;
  final Color color;

  const ColumnsDropdownButton({
    super.key,
    required this.allColumns,
    required this.visibleColumns,
    required this.onToggleColumn,
    this.color = const Color(0xFF4154F1),
  });

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
                          child: Row(
                            children: [
                              Icon(Icons.view_column, size: 18, color: widget.color),
                              const SizedBox(width: 8),
                              const Text(
                                "Select Columns",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)),
                              ),
                            ],
                          ),
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
                              child: const Text("Done", style: TextStyle(color: Colors.white)),
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