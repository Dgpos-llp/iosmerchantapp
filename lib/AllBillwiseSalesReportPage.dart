import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/main.dart';
import 'SidePanel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;  // ADD THIS
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

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  final List<_Col> _baseColumns = [
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

  void _updateColumnLists() {
    _taxColumns = taxColumnNames.map((name) {
      String displayName = name.replaceAll('_', ' ');
      displayName = displayName.replaceAllMapped(
          RegExp(r'(\d+(\.\d+)?)$'),
              (match) => '${match.group(1)}%'
      );
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
          _addRowsFromBill(bill, "ALL");
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

  void _processTaxData() {
    taxTotals.forEach((key, value) {
      taxTotals[key] = double.parse(value.toStringAsFixed(3));
    });
  }

  void _processSettlementData() {
    settlementTotals.forEach((key, value) {
      settlementTotals[key] = double.parse(value.toStringAsFixed(3));
    });
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
      var settlement = settlements[i];
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
        if (!_visibleColumns.contains(col)) _visibleColumns.add(col);
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
    reportCell.value = "Billwise Wise";
    reportCell.cellStyle = boldStyle;
    rowNum++;
    rowNum++;

    if (selectedDbKey == null || selectedDbKey == "All") {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brands/DBs:";
      cell.cellStyle = boldStyle;
      rowNum++;
      for (int i = 0; i < widget.dbToBrandMap.values.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = widget.dbToBrandMap.values.toList()[i];
        cell.cellStyle = boldStyle;
      }
      rowNum++;
      rowNum++;
    } else {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brand/DB:";
      cell.cellStyle = boldStyle;
      rowNum++;
      final brandCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      brandCell.value = widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!;
      brandCell.cellStyle = boldStyle;
      rowNum++;
      rowNum++;
    }

    sheet.appendRow([
      "Date From", DateFormat('dd-MM-yyyy').format(_startDate),
      "Date To", DateFormat('dd-MM-yyyy').format(_endDate)
    ]);
    rowNum++;
    sheet.appendRow([]);
    rowNum++;

    List<String> headers = [
      'Bill No',
      'Customer Name',
      'Bill Date',
      'Subtotal',
      'Bill Discount',
      'Net Total',
      'Grand Amount',
      'Round Off',
      'Tip Amount',
    ];

    for (String settlementColumn in settlementColumnNames) {
      headers.add(settlementColumn);
    }

    for (String taxColumn in taxColumnNames) {
      String displayName = taxColumn.replaceAll('_', ' ');
      displayName = displayName.replaceAllMapped(
          RegExp(r'(\d+(\.\d+)?)$'),
              (match) => '${match.group(1)}%'
      );
      headers.add(displayName);
    }

    headers.addAll([
      'Remark',
      'Packaging Charge',
      'Delivery Charges',
    ]);

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = headers[i];
      cell.cellStyle = boldStyle;
    }
    rowNum++;

    for (final row in _allRows) {
      List<dynamic> rowData = [
        row['billNo'] ?? '',
        row['customerName'] ?? '',
        row['billDate'] ?? '',
        row['subtotal'] ?? '0.000',
        row['billDiscount'] ?? '0.000',
        row['netTotal'] ?? '0.000',
        row['grandAmount'] ?? '0.000',
        row['roundOff'] ?? '0.000',
        row['tipAmount'] ?? '0.000',
      ];

      for (String settlementColumn in settlementColumnNames) {
        rowData.add(row[settlementColumn] ?? '0.000');
      }

      for (String taxColumn in taxColumnNames) {
        rowData.add(row[taxColumn] ?? '0.000');
      }

      rowData.addAll([
        row['remark'] ?? '',
        row['packagingCharge'] ?? '0.000',
        row['deliveryCharges'] ?? '0.000',
      ]);

      for (int i = 0; i < rowData.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = rowData[i];
      }
      rowNum++;
    }

    List<dynamic> totalsRow = [
      'Total',
      '',
      '',
      totals['subtotal']?.toStringAsFixed(3) ?? '0.000',
      totals['billDiscount']?.toStringAsFixed(3) ?? '0.000',
      totals['netTotal']?.toStringAsFixed(3) ?? '0.000',
      totals['grandAmount']?.toStringAsFixed(3) ?? '0.000',
      totals['roundOff']?.toStringAsFixed(3) ?? '0.000',
      totals['tipAmount']?.toStringAsFixed(3) ?? '0.000',
    ];

    for (String settlementColumn in settlementColumnNames) {
      totalsRow.add(settlementTotals[settlementColumn]?.toStringAsFixed(3) ?? '0.000');
    }

    for (String taxColumn in taxColumnNames) {
      totalsRow.add(taxTotals[taxColumn]?.toStringAsFixed(3) ?? '0.000');
    }

    totalsRow.addAll([
      '',
      totals['packagingCharge']?.toStringAsFixed(3) ?? '0.000',
      totals['deliveryCharges']?.toStringAsFixed(3) ?? '0.000',
    ]);

    for (int i = 0; i < totalsRow.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = totalsRow[i];
      cell.cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();

    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'AllBillwiseSalesReport.xlsx');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel downloaded successfully')),
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/BillwiseWise.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel exported to $path')),
        );
      }

      // Only try to open the file on desktop platforms
      try {
        if (Platform.isWindows) {
          await Process.run('start', [path], runInShell: true);
        } else if (Platform.isMacOS) {
          await Process.run('open', [path]);
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [path]);
        }
        // Android will just save the file without opening
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbKeys = widget.dbToBrandMap.keys.toList();
    final brandDropdownItems = ["All", ...dbKeys];
    final brandDisplayMap = {
      "All": "All Outlets",
      ...{for (final db in dbKeys) db: widget.dbToBrandMap[db]!}
    };

    String safeSelectedDbKey = brandDropdownItems.contains(selectedDbKey) ? selectedDbKey! : "All";
    final rowHeight = 48.0;
    final headerHeight = 56.0;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
            automaticallyImplyLeading: false,
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!hasOnlyOneDb)
                    Container(
                      margin: const EdgeInsets.only(left: 50, right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 100,
                        maxWidth: 190,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeSelectedDbKey,
                          hint: const Text(
                            "All Outlets",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                            overflow: TextOverflow.ellipsis,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                          isExpanded: true,
                          items: brandDropdownItems.map((db) => DropdownMenuItem(
                            value: db,
                            child: Text(
                              brandDisplayMap[db]!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.normal),
                            ),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDbKey = value;
                            });
                            _fetchData();
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(left: 50, right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        singleBrandName ?? "",
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.black87),
                    label: const Text(""),
                    onPressed: () {
                      _fetchData();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(
                left: isMobile ? 8 : 22,
                top: isMobile ? 10 : 18,
                bottom: isMobile ? 0 : 3,
              ),
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.grey, size: isMobile ? 16 : 18),
                  SizedBox(width: isMobile ? 3 : 7),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      "Reports",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isMobile ? 13 : 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey, size: isMobile ? 16 : 18),
                  Expanded(
                    child: Text(
                      "Billwise Wise",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 14 : 17,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 160,
                              child: _dateFilter("Start Date", _startDate, (d) {
                                setState(() => _startDate = d);
                                _fetchData();
                              }),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(
                              width: 160,
                              child: _dateFilter("End Date", _endDate, (d) {
                                setState(() => _endDate = d);
                                _fetchData();
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!hasOnlyOneDb)
                            _dropdownFilter(
                              "Restaurants",
                              brandDropdownItems,
                              safeSelectedDbKey,
                                  (val) {
                                setState(() => selectedDbKey = val);
                                _fetchData();
                              },
                              brandDisplayMap,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Restaurants", style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
                                const SizedBox(height: 4),
                                Container(
                                  width: 180,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    singleBrandName ?? "",
                                    style: const TextStyle(fontWeight: FontWeight.normal),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _fetchData,
                              icon: const Icon(Icons.search),
                              label: const Text("Search"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              child: Row(
                children: [
                  ColumnsDropdownButton(
                    allColumns: _allColumns,
                    visibleColumns: _visibleColumns,
                    onToggleColumn: _toggleColumn,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _exportExcel,
                    icon: const Icon(Icons.file_download),
                    label: const Text("Excel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _visibleColumns.length * 180,
                    child: Column(
                      children: [
                        _buildHeaderRow(headerHeight),
                        Expanded(
                          child: Scrollbar(
                            controller: _verticalScroll,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _verticalScroll,
                              itemCount: _allRows.length,
                              itemExtent: rowHeight,
                              itemBuilder: (context, i) {
                                final row = _allRows[i];
                                return Row(
                                  children: _visibleColumns.map((col) {
                                    return Container(
                                      width: 180,
                                      height: rowHeight,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: i % 2 == 0 ? Colors.white : Colors.grey[100],
                                        border: Border(
                                          right: BorderSide(color: Colors.grey[300]!),
                                          bottom: BorderSide(color: Colors.grey[300]!),
                                        ),
                                      ),
                                      child: Text(row[col.key]?.toString() ?? ''),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ),
                        _buildTotalRow(rowHeight),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(double height) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        border: Border(
          bottom: BorderSide(color: Colors.grey[400]!),
          top: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          return Container(
            width: 180,
            height: height,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow(double rowHeight) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDD0),
        border: Border(
          top: BorderSide(color: Colors.grey[400]!, width: 2),
          bottom: BorderSide(color: Colors.grey[400]!),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) {
          String text = '';
          if (col.key == 'restaurant') text = 'Total';
          else if (totals.containsKey(col.key)) text = _to3(totals[col.key]);
          else if (taxTotals.containsKey(col.key)) text = _to3(taxTotals[col.key]);
          else if (settlementTotals.containsKey(col.key)) text = _to3(settlementTotals[col.key]);

          return Container(
            width: 180,
            height: rowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey[400]!),
              ),
            ),
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _dateFilter(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 160,
          child: TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: DateFormat('yyyy-MM-dd').format(date),
              prefixIcon: Icon(Icons.calendar_today, color: Colors.red[700]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPicked(picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdownFilter(String label, List<String> dbKeys, String selectedDbKey, ValueChanged<String?> onChanged, Map<String, String> dbKeyToBrand) {
    String safeSelected = dbKeys.contains(selectedDbKey) ? selectedDbKey : dbKeys.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: safeSelected,
            items: dbKeys.map((db) => DropdownMenuItem(
              value: db,
              child: Text(dbKeyToBrand[db] ?? db),
            )).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _Col {
  final String title;
  final String key;
  const _Col(this.title, this.key);

  @override
  bool operator ==(Object other) => other is _Col && other.key == key;
  @override
  int get hashCode => key.hashCode;
}

class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns;
  final List<_Col> visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;

  const ColumnsDropdownButton({
    super.key,
    required this.allColumns,
    required this.visibleColumns,
    required this.onToggleColumn,
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
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeDropdown,
                child: Container(),
              ),
            ),
            Positioned(
              width: 280,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0.0, 44),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: StatefulBuilder(
                      builder: (context, setStateMenu) {
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              ...widget.allColumns.map((col) {
                                final checked = widget.visibleColumns.contains(col);
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  activeColor: Colors.red[700],
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: Text(
                                    col.title,
                                    style: TextStyle(
                                      fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                                      color: Colors.black,
                                    ),
                                  ),
                                  onChanged: (val) {
                                    widget.onToggleColumn(col, val!);
                                    setStateMenu(() {});
                                  },
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, left: 12, right: 12),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                    backgroundColor: Colors.red[700],
                                  ),
                                  onPressed: _removeDropdown,
                                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true)!.insert(_dropdownOverlay!);
  }

  void _removeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    setState(() {});
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _showDropdown,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.view_column, color: Colors.black),
              SizedBox(width: 8),
              Text("Columns", style: TextStyle(color: Colors.black)),
            ],
          ),
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