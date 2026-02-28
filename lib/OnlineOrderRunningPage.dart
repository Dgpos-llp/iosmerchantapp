import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SidePanel.dart';
import 'OnlineOrderReport.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'main.dart' as app;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

// --- CHART COMPONENT ---
class SimpleBarChart extends StatelessWidget {
  final bool isMobile;
  final List<String> days;
  final List<int> zomato;
  final List<int> swiggy;
  final List<int> online;
  const SimpleBarChart({
    super.key,
    required this.isMobile,
    required this.days,
    required this.zomato,
    required this.swiggy,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [...zomato, ...swiggy, ...online].fold(0, (a, b) => a > b ? a : b);
    final double barWidth = isMobile ? 14 : 22;
    final double groupWidth = barWidth * 3 + (isMobile ? 12 : 20);

    return Container(
      height: isMobile ? 160 : 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = constraints.maxHeight - (isMobile ? 20 : 40);
                return CustomPaint(
                  size: Size(constraints.maxWidth, chartHeight),
                  painter: _BarChartPainter(
                    days: days,
                    zomato: zomato,
                    swiggy: swiggy,
                    online: online,
                    barWidth: barWidth,
                    groupWidth: groupWidth,
                    maxY: maxY > 0 ? maxY.toDouble() : 1,
                    isMobile: isMobile,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((d) => Expanded(
                  child: Center(child: Text(d, style: TextStyle(fontSize: isMobile ? 10 : 12, color: const Color(0xFF7F8C8D))))
              )).toList(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFFC8102E)), const SizedBox(width: 4), Text("Zomato", style: TextStyle(fontSize: isMobile ? 10 : 12)),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFFFF8C1A)), const SizedBox(width: 4), Text("Swiggy", style: TextStyle(fontSize: isMobile ? 10 : 12)),
              const SizedBox(width: 16),
              _legendDot(const Color(0xFF4154F1)), const SizedBox(width: 4), Text("Online", style: TextStyle(fontSize: isMobile ? 10 : 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _BarChartPainter extends CustomPainter {
  final List<String> days;
  final List<int> zomato, swiggy, online;
  final double barWidth, groupWidth, maxY;
  final bool isMobile;

  _BarChartPainter({required this.days, required this.zomato, required this.swiggy, required this.barWidth, required this.groupWidth, required this.maxY, required this.isMobile, required this.online});

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height;
    final gridPaint = Paint()..color = const Color(0xFFF5F7FA)..strokeWidth = 1;
    for (int i = 1; i <= 3; i++) {
      final y = chartHeight - (chartHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final barSpacing = isMobile ? 4.0 : 8.0;
    final groupSpace = (size.width - (groupWidth * days.length)) / (days.length + 1);
    double x = groupSpace;
    for (int i = 0; i < days.length; i++) {
      _drawBar(canvas, x, chartHeight, barWidth, zomato[i], maxY, const Color(0xFFC8102E));
      _drawBar(canvas, x + barWidth + barSpacing, chartHeight, barWidth, swiggy[i], maxY, const Color(0xFFFF8C1A));
      _drawBar(canvas, x + 2 * (barWidth + barSpacing), chartHeight, barWidth, online[i], maxY, const Color(0xFF4154F1));
      x += groupWidth + groupSpace;
    }
  }

  void _drawBar(Canvas canvas, double x, double chartHeight, double width, int value, double maxY, Color color) {
    final barHeight = (value / maxY) * (chartHeight - 10);
    final rect = Rect.fromLTWH(x, chartHeight - barHeight, width, barHeight);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = color);
  }

  @override bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

// --- MAIN PAGE ---
class OnlineOrderRunningPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const OnlineOrderRunningPage({super.key, required this.dbToBrandMap});

  @override
  State<OnlineOrderRunningPage> createState() => _OnlineOrderRunningPageState();
}

class _OnlineOrderRunningPageState extends State<OnlineOrderRunningPage> with SingleTickerProviderStateMixin {
  String? selectedBrand = "All";
  String? selectedRestaurant;
  String? selectedRecordType = "Last 2 days records";
  DateTimeRange? customDateRange;
  String? selectedStatus = "All";
  final TextEditingController orderNoController = TextEditingController();
  late TabController _tabController;
  bool showChart = true;
  List<Map<String, dynamic>> onlineOrderRecords = [];
  List<Map<String, dynamic>> displayedRecords = [];
  bool isLoading = false;

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (hasOnlyOneDb) selectedBrand = widget.dbToBrandMap.values.first;
    fetchOnlineOrders();
  }

  List<String> get last7DaysLabels {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return "${d.day.toString().padLeft(2, '0')}-${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.month-1]}";
    });
  }

  Map<String, List<int>> get barChartData {
    List<String> days = last7DaysLabels;
    Map<String, List<int>> data = {"Zomato": List.filled(7, 0), "Swiggy": List.filled(7, 0), "Online": List.filled(7, 0)};
    for (var row in onlineOrderRecords) {
      final k = row['record'] as OnlineOrderReport;
      final label = "${k.orderDateTime.day.toString().padLeft(2, '0')}-${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][k.orderDateTime.month-1]}";
      int idx = days.indexOf(label);
      if (idx != -1) {
        if (k.orderFrom.toLowerCase().contains("zomato")) data["Zomato"]![idx]++;
        else if (k.orderFrom.toLowerCase().contains("swiggy")) data["Swiggy"]![idx]++;
        else if (k.orderFrom.toLowerCase().contains("online")) data["Online"]![idx]++;
      }
    }
    return data;
  }

  Future<void> fetchOnlineOrders() async {
    setState(() => isLoading = true);
    final config = await app.Config.loadFromAsset();
    List<String> dbNames = (selectedBrand == "All" || selectedBrand == null)
        ? widget.dbToBrandMap.keys.toList()
        : widget.dbToBrandMap.entries.where((e) => e.value == selectedBrand).map((e) => e.key).toList();

    DateTime start, end = DateTime.now();
    if (selectedRecordType == "Last 2 days records") start = DateTime.now().subtract(const Duration(days: 1));
    else if (selectedRecordType == "Last 7 days records") start = DateTime.now().subtract(const Duration(days: 6));
    else if (selectedRecordType == "Custom Date Range" && customDateRange != null) { start = customDateRange!.start; end = customDateRange!.end; }
    else start = DateTime.now();

    final dbToOrders = await app.UserData.fetchOnlineOrdersForDbs(config, dbNames, DateFormat('dd-MM-yyyy').format(start), DateFormat('dd-MM-yyyy').format(end));
    List<Map<String, dynamic>> all = [];
    dbToOrders.forEach((db, list) { for (final k in list) all.add({'dbName': db, 'record': k}); });

    setState(() { onlineOrderRecords = all; displayedRecords = all; isLoading = false; });
  }

  Future<void> exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Online Order Report'];
    final headerStyle = excel.CellStyle(bold: true);

    Map<String, List<OnlineOrderReport>> brandWiseData = {};
    for (var row in displayedRecords) {
      final brand = widget.dbToBrandMap[row['dbName']] ?? "Unknown";
      brandWiseData.putIfAbsent(brand, () => []).add(row['record']);
    }

    int rowIndex = 0;
    for (var entry in brandWiseData.entries) {
      sheet.appendRow([entry.key]); rowIndex++;
      final headerRow = ['Order No.', 'Outlet', 'Type', 'Customer', 'Phone', 'Date', 'Gross', 'Net', 'Status', 'Channel'];
      sheet.appendRow(headerRow);
      for (int i = 0; i < headerRow.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex)).cellStyle = headerStyle;
      }
      rowIndex++;
      for (var row in entry.value) {
        sheet.appendRow([row.onlineOrderId, row.restaurantName, row.orderType, row.customerName, row.phoneNumber, row.orderDateTime.toString(), row.grossAmount, row.netAmount, row.status, row.orderFrom]);
        rowIndex++;
      }
      sheet.appendRow([]); rowIndex++;
    }

    final fileBytes = excelFile.encode();

    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'OnlineOrderRunning.xlsx');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel downloaded successfully')),
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/OnlineOrderReport.xlsx';
      final file = File(filePath)..writeAsBytesSync(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel saved to $filePath')),
        );
      }

      // Only try to open the file on desktop platforms
      if (!kIsWeb) {
        try {
          await OpenFile.open(filePath);
        } catch (_) {}
      }
    }
  }

  Future<void> _handleRecordTypeChange(String? v) async {
    if (v == "Custom Date Range") {
      DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: customDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now()),
      );
      if (picked != null) { setState(() { selectedRecordType = v; customDateRange = picked; }); fetchOnlineOrders(); }
    } else {
      setState(() { selectedRecordType = v; customDateRange = null; }); fetchOnlineOrders();
    }
  }

  void applyFilters() {
    setState(() {
      displayedRecords = onlineOrderRecords.where((row) {
        final k = row['record'] as OnlineOrderReport;
        bool match = true;
        if (selectedBrand != "All" && selectedBrand != null) match &= widget.dbToBrandMap[row['dbName']] == selectedBrand;
        if (selectedRestaurant != null) match &= ("${row['dbName']} - ${widget.dbToBrandMap[row['dbName']]}" == selectedRestaurant);
        if (orderNoController.text.isNotEmpty) match &= (k.onlineOrderId.contains(orderNoController.text) || k.externalOrderId.contains(orderNoController.text));
        if (selectedStatus != "All") match &= k.status.toLowerCase().contains(selectedStatus!.toLowerCase());
        return match;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isHeaderMobile = size.width < 700;
    final bool isMobile = size.width < 700;
    final brandNames = widget.dbToBrandMap.values.toSet();
    final restaurantList = widget.dbToBrandMap.entries.map((e) => "${e.key} - ${e.value}").toList();

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
          title: const Text("Online Orders", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandNames),
          actions: [
            _buildIconButton(Icons.download, exportToExcel),
            _buildIconButton(Icons.refresh, fetchOnlineOrders),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            _buildChannelFilterBar(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4154F1)))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildSummaryRow(),
                    const SizedBox(height: 24),
                    if (showChart) ...[
                      SimpleBarChart(isMobile: isMobile, days: last7DaysLabels, zomato: barChartData["Zomato"]!, swiggy: barChartData["Swiggy"]!, online: barChartData["Online"]!),
                      const SizedBox(height: 24),
                    ],
                    _buildFilterSection(isMobile, restaurantList),
                    const SizedBox(height: 24),
                    _buildTableContainer(size.width),
                  ],
                ),
              ),
            ),
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
              onChanged: (v) { setState(() => selectedBrand = v); fetchOnlineOrders(); },
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

  Widget _buildChannelFilterBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF4154F1),
        unselectedLabelColor: const Color(0xFF7F8C8D),
        indicatorColor: const Color(0xFF4154F1),
        indicatorWeight: 3,
        tabs: const [Tab(text: "All Orders"), Tab(text: "Zomato"), Tab(text: "Swiggy"), Tab(text: "Direct Online")],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final data = barChartData;
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(child: _buildCompactStat("Zomato", "${data["Zomato"]!.fold(0, (a, b) => a + b)}", const Color(0xFFC8102E))),
          const SizedBox(width: 16),
          Expanded(child: _buildCompactStat("Swiggy", "${data["Swiggy"]!.fold(0, (a, b) => a + b)}", const Color(0xFFFF8C1A))),
          const SizedBox(width: 16),
          Expanded(child: _buildCompactStat("Direct Online", "${data["Online"]!.fold(0, (a, b) => a + b)}", const Color(0xFF4154F1))),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // FIXED FILTER SECTION - This is the main fix for the overflow error
  Widget _buildFilterSection(bool isMobile, List<String> restaurantList) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("Filters", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
              onPressed: () => setState(() => showChart = !showChart),
              icon: Icon(showChart ? Icons.visibility_off : Icons.visibility),
              label: Text(showChart ? "Hide Chart" : "Show Chart")
          ),
        ]),
        const SizedBox(height: 16),

        // FIXED: Replaced Wrap with Row inside SingleChildScrollView for proper horizontal scrolling
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate approximate total width needed
            double totalWidth = 180 * 4 + 16 * 4 + 120; // 4 dropdowns (180 each) + 4 spacings (16 each) + button (approx 120)

            if (constraints.maxWidth < totalWidth) {
              // Not enough space - use horizontal scrolling
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildModernDropdown("Select Restaurant", selectedRestaurant, restaurantList, (v) => setState(() => selectedRestaurant = v)),
                    const SizedBox(width: 16),
                    _buildModernDropdown("Record Type", selectedRecordType, ["Last 2 days records", "Last 7 days records", "Today", "Custom Date Range"], _handleRecordTypeChange),
                    const SizedBox(width: 16),
                    _buildModernDropdown("Status", selectedStatus, ["All", "Food Ready", "Pick Up", "Delivered"], (v) => setState(() => selectedStatus = v)),
                    const SizedBox(width: 16),
                    _buildModernTextField("Order ID", orderNoController),
                    const SizedBox(width: 16),
                    ElevatedButton(
                        onPressed: applyFilters,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4154F1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                        ),
                        child: const Text("Search", style: TextStyle(color: Colors.white))
                    ),
                  ],
                ),
              );
            } else {
              // Enough space - use Wrap for natural layout
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _buildModernDropdown("Select Restaurant", selectedRestaurant, restaurantList, (v) => setState(() => selectedRestaurant = v)),
                  _buildModernDropdown("Record Type", selectedRecordType, ["Last 2 days records", "Last 7 days records", "Today", "Custom Date Range"], _handleRecordTypeChange),
                  _buildModernDropdown("Status", selectedStatus, ["All", "Food Ready", "Pick Up", "Delivered"], (v) => setState(() => selectedStatus = v)),
                  _buildModernTextField("Order ID", orderNoController),
                  ElevatedButton(
                      onPressed: applyFilters,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4154F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                      ),
                      child: const Text("Search", style: TextStyle(color: Colors.white))
                  ),
                ],
              );
            }
          },
        ),
      ]),
    );
  }

  Widget _buildModernDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
      const SizedBox(height: 8),
      Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10)
          ),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  hint: Text(label, style: const TextStyle(fontSize: 12)),
                  items: items.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                  )).toList(),
                  onChanged: onChanged
              )
          )
      ),
    ]);
  }

  Widget _buildModernTextField(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
      const SizedBox(height: 8),
      SizedBox(
          width: 180,
          height: 48,
          child: TextField(
              controller: controller,
              decoration: InputDecoration(
                  hintText: "ID",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0))
                  )
              )
          )
      ),
    ]);
  }

  Widget _buildTableContainer(double screenWidth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Order Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: screenWidth - 48),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
              columns: const [
                DataColumn(label: Text("Order ID")),
                DataColumn(label: Text("Channel")),
                DataColumn(label: Text("Outlet")),
                DataColumn(label: Text("Date")),
                DataColumn(label: Text("Amount")),
                DataColumn(label: Text("Status"))
              ],
              rows: displayedRecords.take(50).map((row) {
                final k = row['record'] as OnlineOrderReport;
                return DataRow(cells: [
                  DataCell(Text(k.onlineOrderId)),
                  DataCell(Text(k.orderFrom)),
                  DataCell(Text(k.restaurantName)),
                  DataCell(Text(DateFormat('dd MMM, hh:mm a').format(k.orderDateTime))),
                  DataCell(Text("₹${k.grossAmount.toStringAsFixed(2)}")),
                  DataCell(_buildStatusBadge(k.status))
                ]);
              }).toList(),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color c = Colors.grey;
    if (status.toLowerCase().contains("delivered")) c = Colors.green;
    else if (status.toLowerCase().contains("ready")) c = Colors.orange;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(
            status.toUpperCase(),
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)
        )
    );
  }
}