import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'package:merchant/SidePanel.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'main.dart' as app; // For UserData

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
  final TextEditingController custNameController = TextEditingController();
  final TextEditingController custPhoneController = TextEditingController();

  // Order types & status as per your requirements
  final List<String> orderTypes = [
    "All",
    "Dine",
    "Take Away",
    "Home Delivery",
    "Counter",
    "Online"
  ];
  final List<String> statuses = ["All", "Active", "Billed"];

  List<Map<String, dynamic>> kotRecords = [];
  bool isLoading = false;
  int currentPage = 1;
  int pageSize = 10;
  int totalRecords = 0;

  final ScrollController _horizontalScroll = ScrollController();
  final _verticalScroll = ScrollController();

  String? currentBrandName = "";

  // Check if user has only one DB assigned
  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  // Get the single brand name if there's only one DB
  String? get singleBrandName =>
      hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    // If user has only one DB, set selectedBrand to that DB's brand
    if (hasOnlyOneDb) {
      selectedBrand = singleBrandName;
    }
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

    List<String> dbNames;
    if (selectedBrand == null || selectedBrand == "All") {
      dbNames = widget.dbToBrandMap.keys.toList();
      currentBrandName = "All";
    } else {
      dbNames = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
      currentBrandName = selectedBrand ?? "";
    }

    final start = DateFormat('dd-MM-yyyy').format(startDate);
    final end = DateFormat('dd-MM-yyyy').format(endDate);

    Map<String, List<dynamic>> dbToKotSummaryMap =
    await app.UserData.fetchKotSummaryForDbs(config, dbNames, start, end);

    List<Map<String, dynamic>> all = [];
    dbToKotSummaryMap.forEach((db, list) {
      for (final k in list) {
        all.add({'dbName': db, 'record': k});
      }
    });

    final kotId = kotIdController.text.trim();
    final custName = custNameController.text.trim().toLowerCase();
    final custPhone = custPhoneController.text.trim();

    List<Map<String, dynamic>> filtered = all.where((m) {
      final k = m['record'] as KotSummaryReport;
      bool match = true;
      if (kotId.isNotEmpty) {
        match &= (k.kotId?.toLowerCase().contains(kotId.toLowerCase()) ?? false);
      }
      if (custName.isNotEmpty) {
        match &= (k.customerName?.toLowerCase().contains(custName) ?? false);
      }
      if (custPhone.isNotEmpty) {
        match &= (k.customerPhone?.contains(custPhone) ?? false);
      }
      if (selectedOrderType != "All") {
        match &= (k.orderType?.toLowerCase() == selectedOrderType.toLowerCase());
      }
      if (selectedStatus != "All") {
        if (selectedStatus == "Active") {
          match &= (k.kotStatus?.toLowerCase() == "active" ||
              k.kotStatus?.toLowerCase() == "open");
        } else if (selectedStatus == "Billed") {
          match &= (k.kotStatus?.toLowerCase() == "billed" ||
              k.kotStatus?.toLowerCase() == "used in bill");
        } else {
          match &= (k.kotStatus?.toLowerCase() == selectedStatus.toLowerCase());
        }
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

  void handleSearch() {
    fetchKotSummary();
  }

  void handleShowAll() {
    kotIdController.clear();
    custNameController.clear();
    custPhoneController.clear();
    setState(() {
      selectedOrderType = "All";
      selectedStatus = "All";
      selectedBrand = hasOnlyOneDb ? singleBrandName : "All";
    });
    fetchKotSummary();
  }

  void goToPage(int page) {
    setState(() {
      currentPage = page;
    });
  }

  Future<void> exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['KOT Summary Report'];
    final headerStyle = excel.CellStyle(
      bold: true,
      fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    );

    Map<String, List<KotSummaryReport>> brandWiseData = {};
    for (var row in kotRecords) {
      final dbName = row['dbName'] as String;
      final brand = widget.dbToBrandMap[dbName] ?? "Unknown";
      brandWiseData.putIfAbsent(brand, () => []).add(row['record']);
    }

    int rowIndex = 0;
    for (var entry in brandWiseData.entries) {
      sheet.appendRow([entry.key]);
      rowIndex++;
      final headerRow = [
        'KOT ID',
        'Order Type',
        'No. Of Item',
        'Items',
        'Status',
      ];
      sheet.appendRow(headerRow);
      for (int i = 0; i < headerRow.length; i++) {
        sheet
            .cell(excel.CellIndex.indexByColumnRow(
            columnIndex: i, rowIndex: rowIndex))
            .cellStyle = headerStyle;
      }
      rowIndex++;
      for (var row in entry.value) {
        sheet.appendRow([
          row.kotId ?? '',
          row.orderType ?? '',
          // Formatting to 3 decimal places for Excel export
          _sumNoOfItemDouble(row.items).toStringAsFixed(3),
          _itemsForRow(row.items),
          row.kotStatus ?? '',
        ]);
        rowIndex++;
      }
      rowIndex++;
      sheet.appendRow([]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/KOTSummaryReport.xlsx';
    final fileBytes = excelFile.encode();
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    OpenFile.open(filePath);
  }

  static String _itemsForRow(String? itemsStr) {
    if (itemsStr == null || itemsStr.trim().isEmpty) return '';
    return itemsStr;
  }

  static double _sumNoOfItemDouble(String? itemsStr) {
    if (itemsStr == null || itemsStr.trim().isEmpty) return 0.0;
    final List<String> items = itemsStr
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    double sum = 0.0;
    for (var item in items) {
      final match = RegExp(r'^(.*?)(?:\s*[xX](\d+(\.\d+)?))?$').firstMatch(item);
      if (match != null) {
        final count = double.tryParse(match.group(2) ?? '1.0') ?? 1.0;
        sum += count;
      } else {
        sum += 1.0;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (totalRecords / pageSize).ceil();
    final brandNames = widget.dbToBrandMap.values.toSet();
    final isMobile = MediaQuery.of(context).size.width < 600;

    double headerHeight = 54;
    double rowHeight = 48;

    final paginatedKots =
    paginatedRecords.map((m) => m['record'] as KotSummaryReport).toList();

    final columns = [
      _Col('KOT ID', (KotSummaryReport k) => k.kotId ?? ''),
      _Col('Order Type', (KotSummaryReport k) => k.orderType ?? ''),
      // Formatting to 3 decimal places for UI display
      _Col('No. Of Item',
              (KotSummaryReport k) => _sumNoOfItemDouble(k.items).toStringAsFixed(3)),
      _Col('Items', (KotSummaryReport k) => _itemsForRow(k.items)),
      _Col('Status', (KotSummaryReport k) => k.kotStatus ?? ''),
    ];

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
                          value: selectedBrand,
                          hint: const Text(
                            "All Outlets",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.normal),
                            overflow: TextOverflow.ellipsis,
                          ),
                          icon: const Icon(Icons.arrow_drop_down,
                              color: Colors.black),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: "All",
                              child: Text("All Outlets",
                                  style:
                                  TextStyle(fontWeight: FontWeight.normal)),
                            ),
                            ...brandNames.map((brand) => DropdownMenuItem(
                              value: brand,
                              child: Text(
                                brand,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.normal),
                              ),
                            )),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              selectedBrand = value;
                            });
                            await fetchKotSummary();
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(left: 50, right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontWeight: FontWeight.normal),
                    ),
                    icon: const Icon(Icons.refresh,
                        size: 18, color: Colors.black87),
                    label: const Text(""),
                    onPressed: () async {
                      await fetchKotSummary();
                    },
                  ),
                  if (Platform.isWindows && !isMobile)
                    Padding(
                      padding: const EdgeInsets.only(left: 900, top: 10),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          height: 40,
                        ),
                      ),
                    )
                  else
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
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: isMobile ? 10 : 0),
                    child: const Text(
                      "KOT",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD5282B),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, color: Colors.black87),
                    label: const Text(
                      "Export to Excel",
                      style: TextStyle(color: Colors.black87),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 20,
                        vertical: isMobile ? 8 : 12,
                      ),
                      textStyle: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    onPressed: exportToExcel,
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF3F3F3),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _labeledField(
                          "Start Date",
                          _datePickerField(startDate,
                                  (d) => setState(() => startDate = d),
                              width: 120),
                        ),
                        const SizedBox(width: 18),
                        _labeledField(
                          "End Date",
                          _datePickerField(
                              endDate, (d) => setState(() => endDate = d),
                              width: 120),
                        ),
                        const SizedBox(width: 18),
                        _labeledField(
                          "Kot ID",
                          _inputField(kotIdController, width: 100),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _labeledField(
                          "Order Type",
                          _dropdownField(
                              orderTypes,
                              selectedOrderType,
                                  (v) => setState(() => selectedOrderType = v!),
                              width: 160),
                        ),
                        const SizedBox(width: 18),
                        _labeledField(
                          "Status",
                          _dropdownField(
                              statuses,
                              selectedStatus,
                                  (v) => setState(() => selectedStatus = v!),
                              width: 160),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: handleSearch,
                        child: const Text("Search"),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: handleShowAll,
                        child: const Text("Show All"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (selectedBrand != null && selectedBrand != "All")
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(
                  child: Text(
                    selectedBrand ?? "",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double tableWidth = constraints.maxWidth;
                  int colCount = columns.length;
                  double colWidth = tableWidth / colCount;
                  if (colWidth < 160) colWidth = 160;
                  double usedTableWidth = colWidth * colCount;
                  final paginatedRows = paginatedKots;

                  return Scrollbar(
                    controller: _horizontalScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScroll,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: usedTableWidth,
                        child: Column(
                          children: [
                            _buildHeaderRow(columns, colWidth, headerHeight),
                            Expanded(
                              child: Scrollbar(
                                controller: _verticalScroll,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller: _verticalScroll,
                                  itemCount: paginatedRows.length,
                                  itemExtent: rowHeight,
                                  physics: const ClampingScrollPhysics(),
                                  itemBuilder: (context, i) {
                                    final k = paginatedRows[i];
                                    return Row(
                                      children: columns.map((col) {
                                        return Container(
                                          width: colWidth,
                                          height: rowHeight,
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: i % 2 == 0
                                                ? Colors.white
                                                : const Color(0xFFF8F9FB),
                                            border: Border(
                                              right: BorderSide(
                                                  color: Colors.grey.shade200),
                                              bottom: BorderSide(
                                                  color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Text(
                                            col.value(k).toString(),
                                            overflow: col.title == 'Items'
                                                ? TextOverflow.ellipsis
                                                : TextOverflow.visible,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                color: Colors.black87),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ),
                            ),
                            _buildTotalRow(columns, paginatedRows, colWidth,
                                headerHeight),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              color: Colors.redAccent.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: [
                    Text(
                      "Showing ${kotRecords.isEmpty ? 0 : ((currentPage - 1) * pageSize + 1)}"
                          " to ${(currentPage * pageSize).clamp(0, kotRecords.length)}"
                          " of $totalRecords records",
                      style: const TextStyle(
                          fontWeight: FontWeight.normal, color: Colors.black87),
                    ),
                    const SizedBox(width: 12),
                    ..._paginationBar(totalPages),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(List<_Col> columns, double colWidth, double height) {
    return Container(
      color: const Color(0xFFF8F9FB),
      child: Row(
        children: columns.map((col) {
          return Container(
            width: colWidth,
            height: height,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Text(col.title,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, color: Colors.black87)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotalRow(List<_Col> columns, List<KotSummaryReport> rows,
      double colWidth, double rowHeight) {
    double totalNoOfItem = 0.0;
    for (final k in rows) {
      totalNoOfItem += _sumNoOfItemDouble(k.items);
    }
    return Container(
      height: rowHeight,
      color: const Color(0xFFFFFDD0),
      child: Row(
        children: columns.map((col) {
          String value = '';
          if (col.title == 'KOT ID') {
            value = 'Total';
          } else if (col.title == 'No. Of Item') {
            // Formatting total count to 3 decimal places
            value = totalNoOfItem.toStringAsFixed(3);
          }
          return Container(
            width: colWidth,
            height: rowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.normal)),
          );
        }).toList(),
      ),
    );
  }

  Widget _labeledField(String label, Widget input) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.normal, fontSize: 14)),
          const SizedBox(height: 3),
          input,
        ],
      ),
    );
  }

  Widget _datePickerField(DateTime date, Function(DateTime) onSelect,
      {double width = 120, bool isEndDate = false}) {
    return SizedBox(
      width: width,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: DateFormat('dd MMM yyyy').format(date),
        ),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
        onTap: () async {
          final res = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (res != null) {
            if (isEndDate) {
              onSelect(DateTime(res.year, res.month, res.day, 23, 59, 59));
            } else {
              onSelect(DateTime(res.year, res.month, res.day, 0, 0, 0));
            }
            fetchKotSummary();
          }
        },
      ),
    );
  }

  Widget _inputField(TextEditingController controller, {double width = 120}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
      ),
    );
  }

  Widget _dropdownField(List<String> options, String value,
      ValueChanged<String?> onChanged,
      {double width = 120}) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        value: value,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        ),
        items: options
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  List<Widget> _paginationBar(int totalPages) {
    List<Widget> buttons = [];
    if (totalPages <= 1) return buttons;
    buttons.add(_paginationBtn("1", 1));
    if (currentPage > 2) {
      buttons.add(const SizedBox(width: 6));
      if (currentPage > 3) {
        buttons.add(const Text("..."));
      }
    }
    for (int i = currentPage - 1; i <= currentPage + 1; i++) {
      if (i > 1 && i <= totalPages) {
        buttons.add(_paginationBtn("$i", i));
      }
    }
    if (currentPage < totalPages - 1) {
      if (currentPage < totalPages - 2) {
        buttons.add(const Text("..."));
      }
      buttons.add(_paginationBtn("$totalPages", totalPages));
    }
    if (currentPage < totalPages) {
      buttons.add(const SizedBox(width: 6));
      buttons.add(
        _paginationBtn("Next", currentPage + 1,
            enabled: currentPage < totalPages),
      );
    }
    if (currentPage < totalPages) {
      buttons.add(const SizedBox(width: 6));
      buttons.add(
        _paginationBtn("Last", totalPages, enabled: currentPage < totalPages),
      );
    }
    return buttons;
  }

  Widget _paginationBtn(String label, int page, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
          currentPage == page && label != "Next" && label != "Last"
              ? Colors.redAccent
              : Colors.white,
          foregroundColor:
          currentPage == page && label != "Next" && label != "Last"
              ? Colors.white
              : Colors.black,
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          elevation: 0,
        ),
        onPressed: enabled
            ? () {
          setState(() {
            currentPage = page;
          });
        }
            : null,
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.normal,
                color: currentPage == page && label != "Next" && label != "Last"
                    ? Colors.white
                    : Colors.black)),
      ),
    );
  }
}

class _Col {
  final String title;
  final String Function(KotSummaryReport) value;
  _Col(this.title, this.value);
}