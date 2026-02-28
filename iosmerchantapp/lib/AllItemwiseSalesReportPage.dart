import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'SidePanel.dart';
import 'main.dart';

class AllItemwiseSalesReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllItemwiseSalesReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllItemwiseSalesReportPage> createState() => _AllItemwiseSalesReportPageState();
}

class _AllItemwiseSalesReportPageState extends State<AllItemwiseSalesReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";

  final List<_Col> _allColumns = [
    const _Col('Restaurants', 'restaurant'),
    const _Col('Product Name', 'productName'),
    const _Col('Product Code', 'productCode'),
    const _Col('Qty Sold', 'totalQntSold'),
    const _Col('Total Sale Amount', 'totalSaleAmount'),
  ];
  late List<_Col> _visibleColumns;

  List<_ItemSalesRow> _allRows = [];
  bool _loading = false;

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

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

    Map<String, List<ItemwiseReport>> dbToItemwise =
    await UserData.fetchItemwiseForDbs(config, dbList, startDate, endDate);

    if (selectedDbKey == null || selectedDbKey == "All") {
      final List<ItemwiseReport> allItems = dbToItemwise.values.expand((x) => x).toList();
      final Map<String, _ItemSalesRow> grouped = {};
      for (final item in allItems) {
        final groupKey = "${item.productCode}|${item.productName.trim()}";
        double qty = double.tryParse(item.totalQntSold.toString()) ?? 0.0;
        double amt = double.tryParse(item.totalSaleAmount.toString()) ?? 0.0;

        if (!grouped.containsKey(groupKey)) {
          grouped[groupKey] = _ItemSalesRow(
            restaurant: "ALL",
            productCode: item.productCode,
            productName: item.productName.trim(),
            totalQntSold: qty,
            totalSaleAmount: amt,
          );
        } else {
          grouped[groupKey] = grouped[groupKey]!.copyWith(
            totalQntSold: grouped[groupKey]!.totalQntSold + qty,
            totalSaleAmount: grouped[groupKey]!.totalSaleAmount + amt,
          );
        }
      }
      _allRows = grouped.values.toList();
    } else {
      List<ItemwiseReport> list = dbToItemwise[selectedDbKey!] ?? [];
      if (list.isEmpty && dbToItemwise.isNotEmpty) {
        list = dbToItemwise.values.first;
      }
      for (final item in list) {
        _allRows.add(_ItemSalesRow(
          restaurant: widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!,
          productCode: item.productCode,
          productName: item.productName,
          totalQntSold: double.tryParse(item.totalQntSold.toString()) ?? 0.0,
          totalSaleAmount: double.tryParse(item.totalSaleAmount.toString()) ?? 0.0,
        ));
      }
    }
    setState(() => _loading = false);
  }

  _ItemSalesRow get totalRow {
    return _ItemSalesRow(
      restaurant: "Total",
      productCode: "",
      productName: "",
      totalQntSold: _allRows.fold(0.0, (a, b) => a + b.totalQntSold),
      totalSaleAmount: _allRows.fold(0.0, (a, b) => a + b.totalSaleAmount),
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
    reportCell.value = "Itemwise Wise";
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

    sheet.appendRow(["Date From", DateFormat('dd-MM-yyyy').format(_startDate), "Date To", DateFormat('dd-MM-yyyy').format(_endDate)]);
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
    final String path = '${Directory.current.path}/ItemwiseWiseReport.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exported to $path')));
    try {
      if (Platform.isWindows) await Process.run('start', [path], runInShell: true);
      else if (Platform.isMacOS) await Process.run('open', [path]);
      else if (Platform.isLinux) await Process.run('xdg-open', [path]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dbKeys = widget.dbToBrandMap.keys.toList();
    final brandDropdownItems = ["All", ...dbKeys];
    final brandDisplayMap = {"All": "All Outlets", ...{for (final db in dbKeys) db: widget.dbToBrandMap[db]!}};
    String safeSelectedDbKey = brandDropdownItems.contains(selectedDbKey) ? selectedDbKey! : "All";
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
                children: [
                  if (!hasOnlyOneDb)
                    Container(
                      margin: const EdgeInsets.only(left: 50, right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(6)),
                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 190),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: safeSelectedDbKey,
                          isExpanded: true,
                          items: brandDropdownItems.map((db) => DropdownMenuItem(value: db, child: Text(brandDisplayMap[db]!))).toList(),
                          onChanged: (value) { setState(() => selectedDbKey = value); _fetchData(); },
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(left: 50, right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(6)),
                      child: Text(singleBrandName ?? ""),
                    ),
                  OutlinedButton.icon(
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.home, color: Colors.grey, size: 18),
                  const SizedBox(width: 7),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Text("Reports", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline))),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                  const Text("Itemwise Wise", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF3F3F3),
              padding: const EdgeInsets.all(20),
              child: Column(
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
                      _dropdownFilter("Restaurants", brandDropdownItems, safeSelectedDbKey, (val) { setState(() => selectedDbKey = val); _fetchData(); }, brandDisplayMap),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(onPressed: _fetchData, icon: const Icon(Icons.search), label: const Text("Search"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white)),
                    ],
                  )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ColumnsDropdownButton(allColumns: _allColumns, visibleColumns: _visibleColumns, onToggleColumn: _toggleColumn),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: _exportExcel, icon: const Icon(Icons.file_download), label: const Text("Excel"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: _loading ? const Center(child: CircularProgressIndicator()) : Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _visibleColumns.length * 180,
                    child: Column(
                      children: [
                        _buildHeaderRow(56.0),
                        Expanded(
                          child: ListView.builder(
                            controller: _verticalScroll,
                            itemCount: _allRows.length,
                            itemExtent: 48.0,
                            itemBuilder: (context, i) {
                              final row = _allRows[i];
                              return Row(children: _visibleColumns.map((col) => Container(
                                width: 180, height: 48, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : Colors.grey[100], border: Border(right: BorderSide(color: Colors.grey[300]!), bottom: BorderSide(color: Colors.grey[300]!))),
                                child: Text(row.getField(col.key).toString()),
                              )).toList());
                            },
                          ),
                        ),
                        _buildTotalRow(48.0),
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
      child: Row(children: _visibleColumns.map((col) => Container(width: 180, height: height, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))), child: Text(col.title, style: const TextStyle(fontWeight: FontWeight.bold)))).toList()),
    );
  }

  Widget _buildTotalRow(double height) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFFFFDD0), border: Border(top: BorderSide(color: Colors.grey[400]!, width: 2))),
      child: Row(children: _visibleColumns.map((col) => Container(width: 180, height: height, alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[400]!))), child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList()),
    );
  }

  Widget _dateFilter(String label, DateTime date, ValueChanged<DateTime> onPicked) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label),
      SizedBox(width: 160, child: TextField(readOnly: true, decoration: InputDecoration(hintText: DateFormat('yyyy-MM-dd').format(date), prefixIcon: const Icon(Icons.calendar_today), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) onPicked(picked);
      }))
    ]);
  }

  Widget _dropdownFilter(String label, List<String> items, String selected, ValueChanged<String?> onChanged, Map<String, String> displayMap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label),
      SizedBox(width: 180, child: DropdownButtonFormField<String>(value: selected, items: items.map((e) => DropdownMenuItem(value: e, child: Text(displayMap[e] ?? e))).toList(), onChanged: onChanged, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))))
    ]);
  }
}

class _Col {
  final String title, key;
  const _Col(this.title, this.key);
}

class _ItemSalesRow {
  final String restaurant, productName, productCode;
  final double totalQntSold, totalSaleAmount;

  _ItemSalesRow({required this.restaurant, required this.productName, required this.productCode, this.totalQntSold = 0.0, this.totalSaleAmount = 0.0});

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'productName': return productName;
      case 'productCode': return productCode;
    // Updated to 3 decimal places
      case 'totalQntSold': return totalQntSold.toStringAsFixed(3);
      case 'totalSaleAmount': return totalSaleAmount.toStringAsFixed(3);
      default: return '';
    }
  }

  _ItemSalesRow copyWith({String? restaurant, String? productName, String? productCode, double? totalQntSold, double? totalSaleAmount}) {
    return _ItemSalesRow(
      restaurant: restaurant ?? this.restaurant,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      totalQntSold: totalQntSold ?? this.totalQntSold,
      totalSaleAmount: totalSaleAmount ?? this.totalSaleAmount,
    );
  }
}

class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns, visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;
  final Color color;
  const ColumnsDropdownButton({super.key, required this.allColumns, required this.visibleColumns, required this.onToggleColumn, this.color = const Color(0xFFD5282B)});
  @override
  State<ColumnsDropdownButton> createState() => _ColumnsDropdownButtonState();
}

class _ColumnsDropdownButtonState extends State<ColumnsDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _dropdownOverlay;
  void _showDropdown() {
    if (_dropdownOverlay != null) return;
    _dropdownOverlay = OverlayEntry(builder: (context) => Stack(children: [
      Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _removeDropdown)),
      Positioned(width: 280, child: CompositedTransformFollower(link: _layerLink, offset: const Offset(0, 44), child: Material(child: Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
        child: StatefulBuilder(builder: (context, setMenuState) => Column(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(constraints: const BoxConstraints(maxHeight: 350), child: ListView(shrinkWrap: true, children: widget.allColumns.map((col) {
            final checked = widget.visibleColumns.contains(col);
            return CheckboxListTile(value: checked, title: Text(col.title), activeColor: widget.color, onChanged: (v) { widget.onToggleColumn(col, v!); setMenuState(() {}); });
          }).toList())),
          ElevatedButton(onPressed: _removeDropdown, style: ElevatedButton.styleFrom(backgroundColor: widget.color), child: const Text("Done", style: TextStyle(color: Colors.white)))
        ])),
      ))))
    ]));
    Overlay.of(context, rootOverlay: true)!.insert(_dropdownOverlay!);
  }
  void _removeDropdown() { _dropdownOverlay?.remove(); _dropdownOverlay = null; }
  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _layerLink, child: ElevatedButton.icon(onPressed: _showDropdown, icon: const Icon(Icons.view_column), label: const Text("Columns"), style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white)));
  }
}