import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'SidePanel.dart';
import 'main.dart';
import 'TotalSalesReport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

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

class AllRestaurantSalesReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllRestaurantSalesReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllRestaurantSalesReportPage> createState() => _AllRestaurantSalesReportPageState();
}

class _AllRestaurantSalesReportPageState extends State<AllRestaurantSalesReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedBrand = "All";
  final List<_Col> _allColumns = [
    const _Col('Restaurants', 'restaurant'),
    const _Col('Dine In Sales', 'dineInSales'),
    const _Col('Take Away Sales', 'takeAwaySales'),
    const _Col('Online Sales', 'onlineSales'),
    const _Col('Home Delivery Sales', 'homeDeliverySales'),
    const _Col('Counter Sales', 'counterSales'),
    const _Col('Grand Total', 'grandTotal'),
    const _Col('Bill Tax', 'billTax'),
    const _Col('Bill Discount', 'billDiscount'),
    const _Col('Round Off', 'roundOffTotal'),
    const _Col('Occupied Table Count', 'occupiedTableCount'),
    const _Col('Cash Sales', 'cashSales'),
    const _Col('Card Sales', 'cardSales'),
    const _Col('UPI Sales', 'upiSales'),
    const _Col('Others Sales', 'othersSales'),
    const _Col('Net Total', 'netTotal'),
  ];
  late List<_Col> _visibleColumns;
  List<_SalesRow> _allRows = [];
  bool _loading = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    if (hasOnlyOneDb) {
      selectedBrand = singleBrandName;
    } else {
      selectedBrand = "All";
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
    if (selectedBrand == null || selectedBrand == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    Map<String, TotalSalesReport> dbToReport =
    (await UserData.fetchTotalSalesForDbs(config, dbList, startDate, endDate)).cast<String, TotalSalesReport>();

    dbToReport.remove('ALL');
    dbToReport.remove('all');

    _allRows = dbToReport.entries.map((e) {
      final r = e.value;
      return _SalesRow(
        restaurant: widget.dbToBrandMap[e.key] ?? e.key,
        dineInSales: double.tryParse(r.getField("dineInSales", fallback: "0")) ?? 0.0,
        takeAwaySales: double.tryParse(r.getField("takeAwaySales", fallback: "0")) ?? 0.0,
        onlineSales: double.tryParse(r.getField("onlineSales", fallback: "0")) ?? 0.0,
        homeDeliverySales: double.tryParse(r.getField("homeDeliverySales", fallback: "0")) ?? 0.0,
        counterSales: double.tryParse(r.getField("counterSales", fallback: "0")) ?? 0.0,
        grandTotal: double.tryParse(r.getField("grandTotal", fallback: "0")) ?? 0.0,
        billTax: double.tryParse(r.getField("billTax", fallback: "0")) ?? 0.0,
        billDiscount: double.tryParse(r.getField("billDiscount", fallback: "0")) ?? 0.0,
        roundOffTotal: double.tryParse(r.getField("roundOffTotal", fallback: "0")) ?? 0.0,
        occupiedTableCount: double.tryParse(r.getField("occupiedTableCount", fallback: "0")) ?? 0.0,
        cashSales: double.tryParse(r.getField("cashSales", fallback: "0")) ?? 0.0,
        cardSales: double.tryParse(r.getField("cardSales", fallback: "0")) ?? 0.0,
        upiSales: double.tryParse(r.getField("upiSales", fallback: "0")) ?? 0.0,
        othersSales: double.tryParse(r.getField("othersSales", fallback: "0")) ?? 0.0,
        netTotal: double.tryParse(r.getField("netTotal", fallback: "0")) ?? 0.0,
      );
    }).toList();

    setState(() => _loading = false);
  }

  _SalesRow get totalRow {
    return _SalesRow(
      restaurant: "Total",
      dineInSales: _allRows.fold(0.0, (a, b) => a + b.dineInSales),
      takeAwaySales: _allRows.fold(0.0, (a, b) => a + b.takeAwaySales),
      onlineSales: _allRows.fold(0.0, (a, b) => a + b.onlineSales),
      homeDeliverySales: _allRows.fold(0.0, (a, b) => a + b.homeDeliverySales),
      counterSales: _allRows.fold(0.0, (a, b) => a + b.counterSales),
      grandTotal: _allRows.fold(0.0, (a, b) => a + b.grandTotal),
      billTax: _allRows.fold(0.0, (a, b) => a + b.billTax),
      billDiscount: _allRows.fold(0.0, (a, b) => a + b.billDiscount),
      roundOffTotal: _allRows.fold(0.0, (a, b) => a + b.roundOffTotal),
      occupiedTableCount: _allRows.fold(0.0, (a, b) => a + b.occupiedTableCount),
      cashSales: _allRows.fold(0.0, (a, b) => a + b.cashSales),
      cardSales: _allRows.fold(0.0, (a, b) => a + b.cardSales),
      upiSales: _allRows.fold(0.0, (a, b) => a + b.upiSales),
      othersSales: _allRows.fold(0.0, (a, b) => a + b.othersSales),
      netTotal: _allRows.fold(0.0, (a, b) => a + b.netTotal),
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
    reportCell.value = "All Restaurant Sales Report";
    reportCell.cellStyle = boldStyle;
    rowNum += 2;

    if (selectedBrand == null || selectedBrand == "All") {
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
      brandCell.value = selectedBrand;
      brandCell.cellStyle = boldStyle;
      rowNum += 2;
    }

    sheet.appendRow([
      "Date From", DateFormat('dd-MM-yyyy').format(_startDate),
      "Date To", DateFormat('dd-MM-yyyy').format(_endDate)
    ]);
    rowNum += 2;

    final headerRow = _visibleColumns.map((c) => c.title).toList();
    for (int i = 0; i < headerRow.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = headerRow[i];
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

    final total = _visibleColumns.map((c) => totalRow.getField(c.key)).toList();
    for (int i = 0; i < total.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
      cell.value = total[i];
      cell.cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();

    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'AllRestaurantSalesReport.xlsx');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel downloaded successfully'))
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/AllRestaurantSalesReport.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel exported to $path'))
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
    final brandNames = <String>{"All", ...widget.dbToBrandMap.values};
    String safeSelectedBrand = brandNames.contains(selectedBrand) ? selectedBrand! : "All";
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

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
                          value: safeSelectedBrand,
                          hint: const Text(
                            "All Outlets",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                            overflow: TextOverflow.ellipsis,
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                          isExpanded: true,
                          items: brandNames.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.normal),
                            ),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBrand = value;
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
                  Padding(
                    padding: EdgeInsets.only(left: isMobile ? 150 : 900),
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      height: isMobile ? 32 : 40,
                    ),
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
                bottom: 3,
              ),
              child: Row(
                children: [
                  Icon(Icons.home, color: Colors.grey, size: isMobile ? 16 : 18),
                  const SizedBox(width: 7),
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
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  Expanded(
                    child: Text(
                      "All Restaurant Sales Report",
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _dateFilter("Start Date", _startDate, (d) {
                        setState(() => _startDate = d);
                        _fetchData();
                      }),
                      const SizedBox(width: 18),
                      _dateFilter("End Date", _endDate, (d) {
                        setState(() => _endDate = d);
                        _fetchData();
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dropdownFilter(
                        "Restaurants",
                        brandNames.toList(),
                        safeSelectedBrand,
                            (val) {
                          setState(() => selectedBrand = val);
                          _fetchData();
                        },
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
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
              child: Row(
                children: [
                  ColumnsDropdownButton(
                    allColumns: _allColumns,
                    visibleColumns: _visibleColumns,
                    onToggleColumn: _toggleColumn,
                    color: const Color(0xFFD5282B),
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
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _visibleColumns.length * 180,
                  child: ListView(
                    children: [
                      Container(
                        color: const Color(0xFFF3F3F3),
                        child: Row(
                          children: _visibleColumns.map((col) =>
                              Container(
                                width: 180,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ).toList(),
                        ),
                      ),
                      ..._allRows.map((row) => Row(
                        children: _visibleColumns.map((col) =>
                            Container(
                              width: 180,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              alignment: Alignment.centerLeft,
                              child: Text(row.getField(col.key).toString()),
                            )
                        ).toList(),
                      )),
                      Container(
                        color: const Color(0xFFFFFDD0),
                        child: Row(
                          children: _visibleColumns.map((col) =>
                              Container(
                                width: 180,
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                alignment: Alignment.centerLeft,
                                child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              )
                          ).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Widget _dropdownFilter(String label, List<String> options, String selected, ValueChanged<String?> onChanged) {
    String safeSelected = options.contains(selected) ? selected : options.first;
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
            items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
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

class _SalesRow {
  final String restaurant;
  final double dineInSales;
  final double takeAwaySales;
  final double onlineSales;
  final double homeDeliverySales;
  final double counterSales;
  final double grandTotal;
  final double billTax;
  final double billDiscount;
  final double roundOffTotal;
  final double occupiedTableCount;
  final double cashSales;
  final double cardSales;
  final double upiSales;
  final double othersSales;
  final double netTotal;

  _SalesRow({
    required this.restaurant,
    this.dineInSales = 0.0,
    this.takeAwaySales = 0.0,
    this.onlineSales = 0.0,
    this.homeDeliverySales = 0.0,
    this.counterSales = 0.0,
    this.grandTotal = 0.0,
    this.billTax = 0.0,
    this.billDiscount = 0.0,
    this.roundOffTotal = 0.0,
    this.occupiedTableCount = 0.0,
    this.cashSales = 0.0,
    this.cardSales = 0.0,
    this.upiSales = 0.0,
    this.othersSales = 0.0,
    this.netTotal = 0.0,
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
    // Updated all numerical fields to 3 decimal places
      case 'dineInSales': return dineInSales.toStringAsFixed(3);
      case 'takeAwaySales': return takeAwaySales.toStringAsFixed(3);
      case 'onlineSales': return onlineSales.toStringAsFixed(3);
      case 'homeDeliverySales': return homeDeliverySales.toStringAsFixed(3);
      case 'counterSales': return counterSales.toStringAsFixed(3);
      case 'grandTotal': return grandTotal.toStringAsFixed(3);
      case 'billTax': return billTax.toStringAsFixed(3);
      case 'billDiscount': return billDiscount.toStringAsFixed(3);
      case 'roundOffTotal': return roundOffTotal.toStringAsFixed(3);
      case 'occupiedTableCount': return occupiedTableCount.toStringAsFixed(3);
      case 'cashSales': return cashSales.toStringAsFixed(3);
      case 'cardSales': return cardSales.toStringAsFixed(3);
      case 'upiSales': return upiSales.toStringAsFixed(3);
      case 'othersSales': return othersSales.toStringAsFixed(3);
      case 'netTotal': return netTotal.toStringAsFixed(3);
      default: return '';
    }
  }
}