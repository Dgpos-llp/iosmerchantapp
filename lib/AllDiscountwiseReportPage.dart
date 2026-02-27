import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/main.dart';
import 'SidePanel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

// ---- ColumnsDropdownButton copied here for reuse ----
class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns;
  final List<_Col> visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;
  final Color color;

  const ColumnsDropdownButton({
    super.key,
    required this.allColumns,
    required this.visibleColumns,
    required this.onToggleColumn,
    this.color = const Color(0xFFD5282B),
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
                      boxShadow: const [
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
                                  activeColor: widget.color,
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
                                    backgroundColor: widget.color,
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
            color: widget.color,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.view_column, color: Colors.white),
              SizedBox(width: 8),
              Text("Columns", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
// ---- End ColumnsDropdownButton ----

class AllDiscountwiseReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllDiscountwiseReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllDiscountwiseReportPage> createState() => _AllDiscountwiseReportPageState();
}

class _AllDiscountwiseReportPageState extends State<AllDiscountwiseReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  final List<_Col> _allColumns = [
    const _Col('Restaurants', 'restaurant'),
    const _Col('Bill No', 'billNo'),
    const _Col('Bill Date', 'billDate'),
    const _Col('Gross Amount', 'amount'),
    const _Col('Discount Amount', 'discount'),
    const _Col('Net Amount', 'netAmount'),
    const _Col('Discount On Amt', 'discountOnAmt'),
    const _Col('Discount %', 'discountPercent'),
    const _Col('Remark', 'remark'),
  ];
  late List<_Col> _visibleColumns;
  List<_DiscountwiseRow> _allRows = [];

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    if (hasOnlyOneDb) {
      selectedDbKey = widget.dbToBrandMap.keys.first;
    } else {
      selectedDbKey = "All";
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList;
    if (selectedDbKey == null || selectedDbKey == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = [selectedDbKey!];
    }

    Map<String, List<DiscountwiseReport>> dbToDiscountwise =
    await UserData.fetchDiscountwiseForDbs(config, dbList, startDate, endDate);

    if (selectedDbKey == null || selectedDbKey == "All") {
      for (final list in dbToDiscountwise.values) {
        for (final report in list) {
          _allRows.add(_DiscountwiseRow.fromReport(
            report: report,
            restaurant: "ALL",
          ));
        }
      }
    } else {
      for (final list in dbToDiscountwise.values) {
        for (final report in list) {
          _allRows.add(_DiscountwiseRow.fromReport(
            report: report,
            restaurant: widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!,
          ));
        }
      }
    }
    setState(() => _loading = false);
  }

  _DiscountwiseRow get totalRow {
    double sum(String Function(_DiscountwiseRow) getter) =>
        _allRows.fold(0.0, (a, b) => a + (double.tryParse(getter(b)) ?? 0.0));

    // Formatting sums to 3 decimal places
    return _DiscountwiseRow(
      restaurant: "Total",
      billNo: "",
      billDate: "",
      amount: sum((r) => r.amount).toStringAsFixed(3),
      discount: sum((r) => r.discount).toStringAsFixed(3),
      netAmount: sum((r) => r.netAmount).toStringAsFixed(3),
      discountOnAmt: sum((r) => r.discountOnAmt).toStringAsFixed(3),
      discountPercent: "",
      remark: "",
    );
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
    reportCell.value = "All Discountwise Report";
    reportCell.cellStyle = boldStyle;
    rowNum += 2;

    if (selectedDbKey == null || selectedDbKey == "All") {
      final brands = widget.dbToBrandMap.values.toSet().toList();
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brands/DBs:";
      cell.cellStyle = boldStyle;
      rowNum++;
      for (int i = 0; i < brands.length; i++) {
        final bCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        bCell.value = brands[i];
        bCell.cellStyle = boldStyle;
      }
      rowNum += 2;
    } else {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brand/DB:";
      cell.cellStyle = boldStyle;
      rowNum++;
      final brandCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      brandCell.value = widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!;
      brandCell.cellStyle = boldStyle;
      rowNum += 2;
    }

    sheet.appendRow([
      "Date From", DateFormat('dd-MM-yyyy').format(_startDate),
      "Date To", DateFormat('dd-MM-yyyy').format(_endDate)
    ]);
    rowNum += 2;

    final headerRowLabels = _visibleColumns.map((c) => c.title).toList();
    for (int i = 0; i < headerRowLabels.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = headerRowLabels[i];
      cell.cellStyle = boldStyle;
    }
    rowNum++;

    for (final row in _allRows) {
      for (int i = 0; i < _visibleColumns.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = row.getField(_visibleColumns[i].key);
      }
      rowNum++;
    }

    final totalData = _visibleColumns.map((c) => totalRow.getField(c.key)).toList();
    for (int i = 0; i < totalData.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = totalData[i];
      cell.cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();

    if (kIsWeb) {
      // WEB PLATFORM
      final blob = html.Blob([fileBytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'AllDiscountwiseReport.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel downloaded successfully')),
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/AllDiscountwiseReport.xlsx';
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    const rowHeight = 48.0;
    const headerHeight = 56.0;

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
                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 190),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeSelectedDbKey,
                          hint: const Text("All Outlets", style: TextStyle(color: Colors.black)),
                          isExpanded: true,
                          items: brandDropdownItems.map((db) => DropdownMenuItem(
                            value: db,
                            child: Text(brandDisplayMap[db]!, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (value) {
                            setState(() => selectedDbKey = value);
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
                      child: Text(singleBrandName ?? ""),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.black87),
                    label: const Text(""),
                    onPressed: _fetchData,
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: isMobile ? 150 : 900),
                    child: Image.asset('assets/images/logo.jpg', height: isMobile ? 32 : 40),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Breadcrumb
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(left: isMobile ? 8 : 22, top: isMobile ? 10 : 18, bottom: 3),
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.grey, size: isMobile ? 16 : 18),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text("Reports", style: TextStyle(color: Colors.grey, fontSize: isMobile ? 13 : 16, decoration: TextDecoration.underline)),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  Expanded(
                    child: Text("All Discountwise Report", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: isMobile ? 14 : 17)),
                  ),
                ],
              ),
            ),
            // Filters
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _dateFilter("Start Date", _startDate, (d) { setState(() => _startDate = d); _fetchData(); }),
                      const SizedBox(width: 18),
                      _dateFilter("End Date", _endDate, (d) { setState(() => _endDate = d); _fetchData(); }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!hasOnlyOneDb)
                        _dropdownFilter("Restaurants", brandDropdownItems, safeSelectedDbKey, (val) {
                          setState(() => selectedDbKey = val);
                          _fetchData();
                        }, brandDisplayMap)
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Restaurants", style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Container(
                              width: 180,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                              child: Text(singleBrandName ?? ""),
                            ),
                          ],
                        ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                          onPressed: _fetchData,
                          icon: const Icon(Icons.search),
                          label: const Text("Search"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Container(
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
            // Table
            Expanded(
              child: Scrollbar(
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
                                        border: Border(right: BorderSide(color: Colors.grey[300]!), bottom: BorderSide(color: Colors.grey[300]!)),
                                      ),
                                      child: Text(row.getField(col.key).toString()),
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
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(double height) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF3F3F3), border: Border.symmetric(horizontal: BorderSide(color: Colors.grey[400]!))),
      child: Row(
        children: _visibleColumns.map((col) => Container(
          width: 180, height: height, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))),
          child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _buildTotalRow(double rowHeight) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFFFDD0), border: Border(top: BorderSide(color: Colors.grey[400]!, width: 2))),
      child: Row(
        children: _visibleColumns.map((col) => Container(
          width: 180, height: rowHeight, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))),
          child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        )).toList(),
      ),
    );
  }

  Widget _dateFilter(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
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
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
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
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: safeSelected,
            items: dbKeys.map((db) => DropdownMenuItem(value: db, child: Text(dbKeyToBrand[db] ?? db))).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.all(8)),
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

class _DiscountwiseRow {
  final String restaurant;
  final String billNo;
  final String billDate;
  final String amount;
  final String discount;
  final String netAmount;
  final String discountOnAmt;
  final String discountPercent;
  final String? remark;

  _DiscountwiseRow({
    required this.restaurant,
    required this.billNo,
    required this.billDate,
    required this.amount,
    required this.discount,
    required this.netAmount,
    required this.discountOnAmt,
    required this.discountPercent,
    required this.remark,
  });

  factory _DiscountwiseRow.fromReport({required DiscountwiseReport report, required String restaurant}) {
    // Helper to format string numbers safely to 3 decimal places
    String format3(String? val) {
      if (val == null) return "0.000";
      double d = double.tryParse(val) ?? 0.0;
      return d.toStringAsFixed(3);
    }

    return _DiscountwiseRow(
      restaurant: restaurant,
      billNo: report.billNo,
      billDate: report.billDate,
      amount: format3(report.amount),
      discount: format3(report.discount),
      netAmount: format3(report.netAmount),
      discountOnAmt: format3(report.discountOnAmt),
      discountPercent: report.discountPercent, // Percent usually stays as is or can be formatted if needed
      remark: report.remark,
    );
  }

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'billNo': return billNo;
      case 'billDate': return billDate;
      case 'amount': return amount;
      case 'discount': return discount;
      case 'netAmount': return netAmount;
      case 'discountOnAmt': return discountOnAmt;
      case 'discountPercent': return discountPercent;
      case 'remark': return remark ?? "";
      default: return '';
    }
  }
}