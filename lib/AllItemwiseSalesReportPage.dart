import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:merchant/TotalSalesReport.dart';
import 'SidePanel.dart';
import 'main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

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

  // Animation states
  bool _isHoveringRefresh = false;
  bool _isHoveringColumns = false;
  bool _isHoveringExport = false;

  final List<_Col> _allColumns = const [
    _Col('Restaurants', 'restaurant'),
    _Col('Product Name', 'productName'),
    _Col('Product Code', 'productCode'),
    _Col('Qty Sold', 'totalQntSold'),
    _Col('Total Sale Amount', 'totalSaleAmount'),
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

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
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
        if (!_visibleColumns.contains(col)) {
          // Find original index in allColumns and insert at that position
          int originalIndex = _allColumns.indexOf(col);
          int insertIndex = 0;

          // Find where to insert based on original order
          for (int i = 0; i < _visibleColumns.length; i++) {
            int currentOriginalIndex = _allColumns.indexOf(_visibleColumns[i]);
            if (currentOriginalIndex > originalIndex) {
              break;
            }
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
    reportCell.value = "Itemwise Sales Report";
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

    if (kIsWeb) {
      // WEB PLATFORM
      final blob = html.Blob([fileBytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'ItemwiseSalesReport.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel downloaded successfully'),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/ItemwiseSalesReport.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel exported successfully'),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
        );
      }

      // Only try to open the file on desktop platforms
      try {
        if (Platform.isWindows) await Process.run('start', [path], runInShell: true);
        else if (Platform.isMacOS) await Process.run('open', [path]);
        else if (Platform.isLinux) await Process.run('xdg-open', [path]);
        // Android will just save the file without opening
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
    final brandDisplayMap = {"All": "All Outlets", ...{for (final db in dbKeys) db: widget.dbToBrandMap[db]!}};
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
            "Itemwise Sales Report",
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
                  ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4154F1)),
                ),
              )
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildTable(size.width),
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
                hint: const Text(
                  "All Outlets",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50)),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D)),
                isExpanded: true,
                items: items.map((db) => DropdownMenuItem(
                  value: db,
                  child: Text(
                    displayMap[db]!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50)),
                  ),
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
            child: Text(
              singleBrandName ?? "",
              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50)),
            ),
          ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isHovering,
    required Function(bool) onHover,
  }) {
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
            padding: const EdgeInsets.all(10),
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
          Icon(Icons.home, color: const Color(0xFF7F8C8D), size: 16),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              "Reports",
              style: TextStyle(
                color: const Color(0xFF7F8C8D),
                decoration: TextDecoration.underline,
                fontSize: 13,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: const Color(0xFF7F8C8D), size: 16),
          Text(
            "Itemwise Sales",
            style: TextStyle(
              color: const Color(0xFF4154F1),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(List<String> items, Map<String, String> displayMap, String selected, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Reduced vertical padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate total width needed for all filters + buttons
          double totalWidth = 150 * 3 + 16 * 4 + 350; // 3 dropdowns + spacings + buttons

          if (constraints.maxWidth < totalWidth) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDateFilter("Start Date", _startDate),
                  const SizedBox(width: 16),
                  _buildDateFilter("End Date", _endDate),
                  const SizedBox(width: 16),
                  if (!hasOnlyOneDb) _buildDropdownFilter("Outlet", items, selected, displayMap),
                  const SizedBox(width: 16),
                  _buildActionButtons(),
                ],
              ),
            );
          } else {
            return Row(
              children: [
                _buildDateFilter("Start Date", _startDate),
                const SizedBox(width: 16),
                _buildDateFilter("End Date", _endDate),
                const SizedBox(width: 16),
                if (!hasOnlyOneDb) _buildDropdownFilter("Outlet", items, selected, displayMap),
                const SizedBox(width: 16),
                _buildActionButtons(),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDateFilter(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
        ),
        const SizedBox(height: 4), // Reduced spacing
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF4154F1),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                if (label == "Start Date") {
                  _startDate = picked;
                } else {
                  _endDate = picked;
                }
              });
              _fetchData();
            }
          },
          child: Container(
            width: 150,
            height: 40, // Reduced height from 48 to 40
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: const Color(0xFF7F8C8D)), // Smaller icon
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)), // Smaller font
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter(String label, List<String> items, String selected, Map<String, String> displayMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
        ),
        const SizedBox(height: 4), // Reduced spacing
        Container(
          width: 180,
          height: 40, // Reduced height from 48 to 40
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D), size: 20),
              items: items.map((db) => DropdownMenuItem(
                value: db,
                child: Text(
                  displayMap[db]!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)),
                ),
              )).toList(),
              onChanged: (value) {
                setState(() => selectedDbKey = value);
                _fetchData();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringColumns = true),
          onExit: (_) => setState(() => _isHoveringColumns = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: _isHoveringColumns ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
            child: ColumnsDropdownButton(
              allColumns: _allColumns,
              visibleColumns: _visibleColumns,
              onToggleColumn: _toggleColumn,
              color: const Color(0xFF4154F1),
            ),
          ),
        ),
        const SizedBox(width: 12),
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringExport = true),
          onExit: (_) => setState(() => _isHoveringExport = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: _isHoveringExport ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
            child: ElevatedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.file_download, size: 16),
              label: const Text("Excel", style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced vertical padding
                minimumSize: const Size(100, 40), // Reduced height
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _fetchData,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4154F1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Reduced vertical padding
            minimumSize: const Size(100, 40), // Reduced height
          ),
          child: const Text(
            "Search",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: const Text(
            "Item Details",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _visibleColumns.length * 200.0,
                child: Column(
                  children: [
                    _buildHeaderRow(56),
                    Expanded(
                      child: ListView.builder(
                        controller: _verticalScroll,
                        itemCount: _allRows.length,
                        itemBuilder: (context, i) {
                          final row = _allRows[i];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: _visibleColumns.map((col) => Container(
                                width: 200,
                                height: 48,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: i % 2 == 0 ? Colors.white : const Color(0xFFF9FAFC),
                                  border: Border(
                                    right: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Text(
                                  row.getField(col.key).toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF2C3E50),
                                    fontWeight: col.key == 'totalSaleAmount' ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              )).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    _buildTotalRow(48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(double height) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) => Container(
          width: 200,
          height: height,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            col.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF2C3E50),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTotalRow(double height) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        border: Border(
          top: BorderSide(color: const Color(0xFF4154F1).withOpacity(0.3), width: 2),
        ),
      ),
      child: Row(
        children: _visibleColumns.map((col) => Container(
          width: 200,
          height: height,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            totalRow.getField(col.key).toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF4154F1),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _Col {
  final String title, key;
  const _Col(this.title, this.key);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _Col && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

class _ItemSalesRow {
  final String restaurant, productName, productCode;
  final double totalQntSold, totalSaleAmount;

  _ItemSalesRow({
    required this.restaurant,
    required this.productName,
    required this.productCode,
    this.totalQntSold = 0.0,
    this.totalSaleAmount = 0.0
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
      case 'productName': return productName;
      case 'productCode': return productCode;
      case 'totalQntSold': return totalQntSold.toStringAsFixed(1);
      case 'totalSaleAmount': return totalSaleAmount.toStringAsFixed(3);
      default: return '';
    }
  }

  _ItemSalesRow copyWith({
    String? restaurant,
    String? productName,
    String? productCode,
    double? totalQntSold,
    double? totalSaleAmount
  }) {
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

  const ColumnsDropdownButton({
    super.key,
    required this.allColumns,
    required this.visibleColumns,
    required this.onToggleColumn,
    this.color = const Color(0xFF4154F1)
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
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeDropdown,
            ),
          ),
          Positioned(
            width: 280,
            child: CompositedTransformFollower(
              link: _layerLink,
              offset: const Offset(0, 45),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: StatefulBuilder(
                    builder: (context, setMenuState) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.view_column, size: 18, color: Color(0xFF4154F1)),
                              SizedBox(width: 8),
                              Text(
                                "Select Columns",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF2C3E50),
                                ),
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
                                title: Text(
                                  col.title,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
                                ),
                                activeColor: widget.color,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                dense: true,
                                onChanged: (v) {
                                  widget.onToggleColumn(col, v!);
                                  setMenuState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _removeDropdown,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.color,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                "Done",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced vertical padding
          minimumSize: const Size(100, 40), // Reduced height
        ),
      ),
    );
  }
}