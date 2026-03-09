import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'SidePanel.dart';
import 'main.dart';
import 'TotalSalesReport.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

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

  bool _isHoveringRefresh = false;

  final List<_Col> _allColumns = const [
    _Col('Restaurants', 'restaurant'),
    _Col('Dine In Sales', 'dineInSales'),
    _Col('Take Away Sales', 'takeAwaySales'),
    _Col('Online Sales', 'onlineSales'),
    _Col('Home Delivery Sales', 'homeDeliverySales'),
    _Col('Counter Sales', 'counterSales'),
    _Col('Grand Total', 'grandTotal'),
    _Col('Bill Tax', 'billTax'),
    _Col('Bill Discount', 'billDiscount'),
    _Col('Round Off', 'roundOffTotal'),
    _Col('Occupied Table Count', 'occupiedTableCount'),
    _Col('Cash Sales', 'cashSales'),
    _Col('Card Sales', 'cardSales'),
    _Col('UPI Sales', 'upiSales'),
    _Col('Others Sales', 'othersSales'),
    _Col('Net Total', 'netTotal'),
  ];

  late List<_Col> _visibleColumns;
  List<_SalesRow> _allRows = [];
  bool _loading = false;

  final _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_allColumns);
    selectedBrand = hasOnlyOneDb ? singleBrandName : "All";
    _fetchData();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  // Helper to determine if a column is numeric (for right alignment)
  bool _isNumericCol(String key) => key != 'restaurant';

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    _allRows = [];
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(_startDate);
    String endDate = DateFormat('dd-MM-yyyy').format(_endDate);

    List<String> dbList = (selectedBrand == null || selectedBrand == "All")
        ? widget.dbToBrandMap.keys.toList()
        : widget.dbToBrandMap.entries
        .where((entry) => entry.value == selectedBrand)
        .map((entry) => entry.key)
        .toList();

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
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];
    final boldStyle = excel.CellStyle(bold: true);

    int rowNum = 0;
    sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum))
      ..value = "All Restaurant Sales Report"
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
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum)).value = row.getField(_visibleColumns[i].key);
      }
      rowNum++;
    }

    for (int i = 0; i < _visibleColumns.length; i++) {
      sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowNum))
        ..value = totalRow.getField(_visibleColumns[i].key)
        ..cellStyle = boldStyle;
    }

    final fileBytes = excelFile.encode();
    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'AllRestaurantSales.xlsx');
    } else {
      final String path = '${Directory.current.path}/AllRestaurantSalesReport.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);
      try {
        if (Platform.isWindows) await Process.run('start', [path], runInShell: true);
        else if (Platform.isMacOS) await Process.run('open', [path]);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isHeaderMobile = size.width < 700;
    final brandNames = <String>{"All", ...widget.dbToBrandMap.values};
    String safeSelectedBrand = brandNames.contains(selectedBrand) ? selectedBrand! : "All";

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
          title: const Text("Restaurant Sales Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandNames.toList(), safeSelectedBrand),
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
            _buildFilterSection(brandNames.toList(), safeSelectedBrand),
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
                child: ClipRRect(borderRadius: BorderRadius.circular(20), child: _buildTable()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSelector(List<String> items, String selected) {
    return Row(
      children: [
        const SizedBox(width: 70),
        if (!hasOnlyOneDb)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(12), color: Colors.white),
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D)),
                isExpanded: true,
                items: items.map((brand) => DropdownMenuItem(value: brand, child: Text(brand, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))))).toList(),
                onChanged: (value) {
                  setState(() => selectedBrand = value);
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
          const Text("Restaurant Sales", style: TextStyle(color: Color(0xFF4154F1), fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(List<String> items, String selected) {
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildDateFilter("Start Date", _startDate, (d) { setState(() => _startDate = d); _fetchData(); }),
            const SizedBox(width: 16),
            _buildDateFilter("End Date", _endDate, (d) { setState(() => _endDate = d); _fetchData(); }),
            const SizedBox(width: 16),
            if (!hasOnlyOneDb) _buildDropdownFilter("Outlet", items, selected),
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

  Widget _buildDropdownFilter(String label, List<String> items, String selected) {
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
              value: items.contains(selected) ? selected : items.first,
              isExpanded: true,
              items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) { setState(() => selectedBrand = val); _fetchData(); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ColumnsDropdownButton(allColumns: _allColumns, visibleColumns: _visibleColumns, onToggleColumn: _toggleColumn),
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
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(100, 40),
            elevation: 0,
          ),
          child: const Text("Search", style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: const Text("Sales Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
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
                                return Container(
                                  width: 180, height: 48,
                                  alignment: _isNumericCol(col.key) ? Alignment.centerRight : Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: i % 2 == 0 ? Colors.white : const Color(0xFFF9FAFC), border: Border(right: BorderSide(color: Colors.grey.shade200))),
                                  child: Text(row.getField(col.key).toString(), style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50))),
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
          // Headers now align right if numeric, to match the rows and total row
          return Container(
            width: 180, height: 56,
            alignment: _isNumericCol(col.key) ? Alignment.centerRight : Alignment.centerLeft,
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
        children: _visibleColumns.map((col) => Container(
          width: 180, height: 48,
          alignment: _isNumericCol(col.key) ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300))),
          child: Text(totalRow.getField(col.key).toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4154F1))),
        )).toList(),
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

class _SalesRow {
  final String restaurant;
  final double dineInSales, takeAwaySales, onlineSales, homeDeliverySales, counterSales, grandTotal, billTax, billDiscount, roundOffTotal, occupiedTableCount, cashSales, cardSales, upiSales, othersSales, netTotal;

  _SalesRow({
    required this.restaurant,
    this.dineInSales = 0.0, this.takeAwaySales = 0.0, this.onlineSales = 0.0, this.homeDeliverySales = 0.0, this.counterSales = 0.0, this.grandTotal = 0.0, this.billTax = 0.0, this.billDiscount = 0.0, this.roundOffTotal = 0.0, this.occupiedTableCount = 0.0, this.cashSales = 0.0, this.cardSales = 0.0, this.upiSales = 0.0, this.othersSales = 0.0, this.netTotal = 0.0,
  });

  dynamic getField(String key) {
    switch (key) {
      case 'restaurant': return restaurant;
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

class ColumnsDropdownButton extends StatefulWidget {
  final List<_Col> allColumns, visibleColumns;
  final void Function(_Col col, bool value) onToggleColumn;

  const ColumnsDropdownButton({super.key, required this.allColumns, required this.visibleColumns, required this.onToggleColumn});

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
                          child: const Row(children: [Icon(Icons.view_column, size: 18, color: Color(0xFF4154F1)), SizedBox(width: 8), Text("Select Columns", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50)))]),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 350),
                          child: ListView(
                            shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8),
                            children: widget.allColumns.map((col) {
                              final checked = widget.visibleColumns.contains(col);
                              return CheckboxListTile(
                                value: checked, title: Text(col.title, style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50))),
                                activeColor: const Color(0xFF4154F1), dense: true,
                                onChanged: (v) { widget.onToggleColumn(col, v!); setMenuState(() {}); },
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _removeDropdown, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4154F1)), child: const Text("Done", style: TextStyle(color: Colors.white)))),
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
        icon: const Icon(Icons.view_column, size: 16, color: Color(0xFF4154F1)),
        label: const Text("Columns", style: TextStyle(fontSize: 13, color: Color(0xFF4154F1))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          minimumSize: const Size(110, 40),
        ),
      ),
    );
  }
}