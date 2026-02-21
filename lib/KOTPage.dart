import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'package:merchant/SidePanel.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'main.dart' as app;

class KOTPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const KOTPage({super.key, required this.dbToBrandMap});

  @override
  State<KOTPage> createState() => _KOTPageState();
}

class _KOTPageState extends State<KOTPage> {
  String? selectedBrand = "All";
  String selectedOrderType = "All";
  String selectedStatus = "All";
  DateTime startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime endDate = DateTime.now();
  final TextEditingController kotIdController = TextEditingController();

  final List<String> orderTypes = ["All", "Dine", "Take Away", "Home Delivery", "Counter", "Online"];
  final List<String> statuses = ["All", "Active", "Billed"];

  List<Map<String, dynamic>> kotRecords = [];
  bool isLoading = false;
  int currentPage = 1;
  int pageSize = 10;
  int totalRecords = 0;

  final ScrollController _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();
  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    if (hasOnlyOneDb) selectedBrand = singleBrandName;
    fetchKotSummary();
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  Future<void> fetchKotSummary() async {
    setState(() => isLoading = true);
    final config = await app.Config.loadFromAsset();
    List<String> dbNames = (selectedBrand == null || selectedBrand == "All")
        ? widget.dbToBrandMap.keys.toList()
        : widget.dbToBrandMap.entries.where((e) => e.value == selectedBrand).map((e) => e.key).toList();

    final start = DateFormat('dd-MM-yyyy').format(startDate);
    final end = DateFormat('dd-MM-yyyy').format(endDate);
    Map<String, List<dynamic>> dbToKotSummaryMap = await app.UserData.fetchKotSummaryForDbs(config, dbNames, start, end);

    List<Map<String, dynamic>> all = [];
    dbToKotSummaryMap.forEach((db, list) {
      for (final k in list) { all.add({'dbName': db, 'record': k}); }
    });

    final kotId = kotIdController.text.trim();
    List<Map<String, dynamic>> filtered = all.where((m) {
      final k = m['record'] as KotSummaryReport;
      bool match = true;
      if (kotId.isNotEmpty) match &= (k.kotId?.toLowerCase().contains(kotId.toLowerCase()) ?? false);
      if (selectedOrderType != "All") match &= (k.orderType?.toLowerCase() == selectedOrderType.toLowerCase());
      if (selectedStatus != "All") {
        if (selectedStatus == "Active") match &= (k.kotStatus?.toLowerCase() == "active" || k.kotStatus?.toLowerCase() == "open");
        else if (selectedStatus == "Billed") match &= (k.kotStatus?.toLowerCase() == "billed" || k.kotStatus?.toLowerCase() == "used in bill");
        else match &= (k.kotStatus?.toLowerCase() == selectedStatus.toLowerCase());
      }
      return match;
    }).toList();

    setState(() {
      kotRecords = filtered;
      totalRecords = filtered.length;
      currentPage = 1;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get paginatedRecords {
    int start = (currentPage - 1) * pageSize;
    int end = (start + pageSize).clamp(0, kotRecords.length);
    if (start >= kotRecords.length) return [];
    return kotRecords.sublist(start, end);
  }

  void handleSearch() => fetchKotSummary();

  void handleShowAll() {
    kotIdController.clear();
    setState(() {
      selectedOrderType = "All";
      selectedStatus = "All";
      selectedBrand = hasOnlyOneDb ? singleBrandName : "All";
    });
    fetchKotSummary();
  }

  Future<void> exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['KOT Summary Report'];
    final headerStyle = excel.CellStyle(bold: true);

    Map<String, List<KotSummaryReport>> brandWiseData = {};
    for (var row in kotRecords) {
      final brand = widget.dbToBrandMap[row['dbName']] ?? "Unknown";
      brandWiseData.putIfAbsent(brand, () => []).add(row['record']);
    }

    int rowIndex = 0;
    for (var entry in brandWiseData.entries) {
      sheet.appendRow([entry.key]); rowIndex++;
      final headerRow = ['KOT ID', 'Order Type', 'No. Of Item', 'Items', 'Status'];
      sheet.appendRow(headerRow);
      for (int i = 0; i < headerRow.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).cellStyle = headerStyle;
      }
      rowIndex++;
      for (var row in entry.value) {
        sheet.appendRow([row.kotId ?? '', row.orderType ?? '', _sumNoOfItemDouble(row.items).toStringAsFixed(3), row.items ?? '', row.kotStatus ?? '']);
        rowIndex++;
      }
      sheet.appendRow([]); rowIndex++;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/KOTSummaryReport.xlsx';
    final file = File(filePath)..createSync(recursive: true)..writeAsBytesSync(excelFile.encode()!);
    OpenFile.open(filePath);
  }

  static double _sumNoOfItemDouble(String? itemsStr) {
    if (itemsStr == null || itemsStr.trim().isEmpty) return 0.0;
    final List<String> items = itemsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    double sum = 0.0;
    for (var item in items) {
      final match = RegExp(r'^(.*?)(?:\s*[xX](\d+(\.\d+)?))?$').firstMatch(item);
      sum += (match != null) ? (double.tryParse(match.group(2) ?? '1.0') ?? 1.0) : 1.0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;
    final bool isHeaderMobile = size.width < 700;
    final brandNames = widget.dbToBrandMap.values.toSet();

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
          title: const Text("KOT Reports", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandNames),
          actions: [
            _buildIconButton(Icons.download, exportToExcel),
            _buildIconButton(Icons.refresh, fetchKotSummary),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterCard(),
                    const SizedBox(height: 24),
                    _buildTableContainer(size.width),
                  ],
                ),
              ),
            ),
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSelector(Set<String> brandNames) {
    return Row(children: [
      const SizedBox(width: 70),
      if (!hasOnlyOneDb)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(12), color: Colors.white),
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBrand, isExpanded: true,
              items: [const DropdownMenuItem(value: "All", child: Text("All Outlets")), ...brandNames.map((b) => DropdownMenuItem(value: b, child: Text(b)))],
              onChanged: (v) { setState(() => selectedBrand = v); fetchKotSummary(); },
            ),
          ),
        )
      else
        Padding(padding: const EdgeInsets.only(left: 12), child: Text(widget.dbToBrandMap.values.first, style: const TextStyle(fontWeight: FontWeight.w500))),
    ]);
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF7F8C8D), size: 20), onPressed: onTap),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      width: double.infinity, // Use full width
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _buildDatePicker("Start Date", startDate, (d) => setState(() => startDate = d)),
            _buildDatePicker("End Date", endDate, (d) => setState(() => endDate = d)),
            _buildModernTextField("KOT ID", kotIdController),
            _buildModernDropdown("Order Type", selectedOrderType, orderTypes, (v) => setState(() => selectedOrderType = v!)),
            _buildModernDropdown("Status", selectedStatus, statuses, (v) => setState(() => selectedStatus = v!)),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final res = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (res != null) { onSelect(res); fetchKotSummary(); }
          },
          child: Container(
            width: 150, height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Color(0xFF7F8C8D)), const SizedBox(width: 8), Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 13))]),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 8),
        Container(
          width: 150, height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(), onChanged: onChanged)),
        )
      ],
    );
  }

  Widget _buildModernTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
        const SizedBox(height: 8),
        SizedBox(
          width: 120, height: 48,
          child: TextField(controller: controller, decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))))),
        )
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: handleSearch,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
          child: const Text("Search", style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: handleShowAll,
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF4154F1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
          child: const Text("Reset", style: TextStyle(color: Color(0xFF4154F1))),
        ),
      ],
    );
  }

  Widget _buildTableContainer(double screenWidth) {
    final paginatedKots = paginatedRecords.map((m) => m['record'] as KotSummaryReport).toList();
    double totalNoOfItem = paginatedKots.fold(0.0, (sum, k) => sum + _sumNoOfItemDouble(k.items));

    return Container(
      width: double.infinity, // Use full width
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(20), child: Text("KOT Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          isLoading ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())) :
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: screenWidth - 48),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                columns: const [
                  DataColumn(label: Text("KOT ID")), DataColumn(label: Text("Order Type")),
                  DataColumn(label: Text("No. Of Item")), DataColumn(label: Text("Items")), DataColumn(label: Text("Status"))
                ],
                rows: [
                  ...paginatedKots.map((k) => DataRow(cells: [
                    DataCell(Text(k.kotId ?? '')), DataCell(Text(k.orderType ?? '')),
                    DataCell(Text(_sumNoOfItemDouble(k.items).toStringAsFixed(3))),
                    DataCell(SizedBox(width: 250, child: Text(k.items ?? '', overflow: TextOverflow.ellipsis))),
                    DataCell(_buildStatusBadge(k.kotStatus ?? '')),
                  ])),
                  DataRow(
                      color: WidgetStateProperty.all(const Color(0xFFF0F2FF)),
                      cells: [
                        const DataCell(Text("Total", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4154F1)))),
                        const DataCell(Text("")),
                        DataCell(Text(totalNoOfItem.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4154F1)))),
                        const DataCell(Text("")), const DataCell(Text("")),
                      ]
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color c = (status.toLowerCase().contains("billed")) ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPaginationFooter() {
    int totalPages = (totalRecords / pageSize).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Showing ${kotRecords.isEmpty ? 0 : ((currentPage - 1) * pageSize + 1)} - ${(currentPage * pageSize).clamp(0, kotRecords.length)} of $totalRecords", style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 13)),
          Row(children: _paginationBar(totalPages)),
        ],
      ),
    );
  }

  List<Widget> _paginationBar(int totalPages) {
    List<Widget> buttons = [];
    if (totalPages <= 1) return buttons;

    void addBtn(int page, String label) {
      buttons.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => setState(() => currentPage = page),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: currentPage == page ? const Color(0xFF4154F1) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(color: currentPage == page ? Colors.white : const Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
          ),
        ),
      ));
    }

    if (currentPage > 1) addBtn(currentPage - 1, "Prev");
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
        addBtn(i, i.toString());
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        buttons.add(const Text("..."));
      }
    }
    if (currentPage < totalPages) addBtn(currentPage + 1, "Next");
    return buttons;
  }
}