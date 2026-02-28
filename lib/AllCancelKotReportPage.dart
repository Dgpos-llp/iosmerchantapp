import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'SidePanel.dart';
import 'main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

class AllCancelKotReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const AllCancelKotReportPage({super.key, required this.dbToBrandMap});

  @override
  State<AllCancelKotReportPage> createState() => _AllCancelKotReportPageState();
}

class _AllCancelKotReportPageState extends State<AllCancelKotReportPage> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? selectedDbKey = "All";
  bool _loading = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  final List<_Col> _allColumns = [
    _Col('Restaurants', 'restaurant'),
    _Col('KOT ID', 'kotId'),
    _Col('Item Names', 'itemNames'),
    _Col('Quantity', 'quantity'),
    _Col('Amount', 'amount'),
    _Col('Status', 'status'),
    _Col('Notes', 'notes'),
    _Col('Table Number', 'tableNumber'),
    _Col('Order Date', 'orderDate'),
    _Col('Order Time', 'orderTime'),
    _Col('Cancel Time', 'cancelTime'),
  ];
  late List<_Col> _visibleColumns;

  List<_CancelKotRow> _allRows = [];

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  final DateFormat _displayDateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _apiDateFormat = DateFormat('dd-MM-yyyy');

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

  String _format3(dynamic value) {
    if (value == null) return '0.000';
    double? d = double.tryParse(value.toString());
    return d != null ? d.toStringAsFixed(3) : '0.000';
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    final config = await Config.loadFromAsset();
    String startDate = _apiDateFormat.format(_startDate);
    String endDate = _apiDateFormat.format(_endDate);

    List<String> dbList;
    if (selectedDbKey == null || selectedDbKey == "All") {
      dbList = widget.dbToBrandMap.keys.toList();
    } else {
      dbList = [selectedDbKey!];
    }

    Map<String, List<CancelKotReport>> dbToCancelKot =
    await UserData.fetchCancelKotForDbs(config.apiUrl, dbList, startDate, endDate);

    if (selectedDbKey == null || selectedDbKey == "All") {
      final List<CancelKotReport> allItems = dbToCancelKot.values.expand((x) => x).toList();
      for (final item in allItems) {
        _allRows.add(_CancelKotRow(
          restaurant: "ALL",
          kotId: item.kotId,
          quantity: item.quantity,
          amount: item.amount,
          status: item.status,
          notes: item.notes,
          tableNumber: item.tableNumber,
          orderDate: item.orderDate,
          orderTime: item.orderTime,
          itemNames: item.itemNames,
          cancelTime: item.cancelTime,
          formatter: _format3,
        ));
      }
    } else {
      for (final list in dbToCancelKot.values) {
        for (final item in list) {
          _allRows.add(_CancelKotRow(
            restaurant: widget.dbToBrandMap[selectedDbKey!] ?? selectedDbKey!,
            kotId: item.kotId,
            quantity: item.quantity,
            amount: item.amount,
            status: item.status,
            notes: item.notes,
            tableNumber: item.tableNumber,
            orderDate: item.orderDate,
            orderTime: item.orderTime,
            itemNames: item.itemNames,
            cancelTime: item.cancelTime,
            formatter: _format3,
          ));
        }
      }
    }
    setState(() => _loading = false);
  }

  _CancelKotRow get totalRow {
    double sumAmount() {
      return _allRows.fold(0.0, (a, b) {
        final value = double.tryParse(b.amount ?? '0.000');
        return a + (value ?? 0.0);
      });
    }

    double sumQuantity() {
      return _allRows.fold(0.0, (a, b) => a + (b.quantity ?? 0.0));
    }

    return _CancelKotRow(
      restaurant: "Total",
      kotId: "",
      itemNames: "",
      quantity: sumQuantity(),
      amount: sumAmount().toString(),
      status: "",
      notes: "",
      tableNumber: "",
      orderDate: "",
      orderTime: "",
      cancelTime: "",
      formatter: _format3,
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
    reportCell.value = "All Cancel KOT Report";
    reportCell.cellStyle = boldStyle;
    rowNum++;
    rowNum++;

    if (selectedDbKey == null || selectedDbKey == "All") {
      final brands = widget.dbToBrandMap.values.toSet().toList();
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
      cell.value = "Brands/DBs:";
      cell.cellStyle = boldStyle;
      rowNum++;
      for (int i = 0; i < brands.length; i++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum));
        cell.value = brands[i];
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
      "Date From", _apiDateFormat.format(_startDate),
      "Date To", _apiDateFormat.format(_endDate)
    ]);
    rowNum++;
    sheet.appendRow([]);
    rowNum++;

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
      web_exporter.saveFileWeb(fileBytes!, 'AllCancelKotReport.xlsx');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel downloaded successfully')),
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/AllCancelKotReport.xlsx';
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final rowHeight = 48.0;
    final headerHeight = 56.0;

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
                          hint: Text(
                            brandDisplayMap["All"]!,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
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
                  Padding(
                    padding: const EdgeInsets.only(left: 150),
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
                      "All Cancel KOT Report",
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
              child: Column(
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
                            const Text("Restaurants", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
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
                  : Scrollbar(
                controller: _horizontalScroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
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
                              physics: const ClampingScrollPhysics(),
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
            child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
              hintText: _displayDateFormat.format(date),
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

class _CancelKotRow {
  final String restaurant;
  final String kotId;
  final double? quantity;
  final String? amount;
  final String status;
  final String? notes;
  final String tableNumber;
  final String orderDate;
  final String orderTime;
  final String itemNames;
  final String? cancelTime;
  final String Function(dynamic) formatter;

  _CancelKotRow({
    required this.restaurant,
    required this.kotId,
    required this.quantity,
    required this.amount,
    required this.status,
    required this.notes,
    required this.tableNumber,
    required this.orderDate,
    required this.orderTime,
    required this.itemNames,
    required this.cancelTime,
    required this.formatter,
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'kotId': return kotId;
      case 'quantity': return formatter(quantity);
      case 'amount': return formatter(amount);
      case 'status': return status;
      case 'notes': return notes ?? '';
      case 'tableNumber': return tableNumber;
      case 'orderDate': return orderDate;
      case 'orderTime': return orderTime;
      case 'itemNames': return itemNames;
      case 'cancelTime': return cancelTime ?? '';
      default: return '';
    }
  }
}

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