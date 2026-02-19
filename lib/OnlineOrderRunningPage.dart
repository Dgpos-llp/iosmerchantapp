import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SidePanel.dart';
import 'OnlineOrderReport.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'main.dart' as app;

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
    final maxY = [
      ...zomato,
      ...swiggy,
      ...online,
    ].fold(0, (a, b) => a > b ? a : b);

    final double barWidth = isMobile ? 14 : 22;
    final double groupWidth = barWidth * 3 + (isMobile ? 12 : 20);

    return Container(
      height: isMobile ? 140 : 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.only(
        left: isMobile ? 8 : 22,
        right: isMobile ? 8 : 22,
        top: isMobile ? 6 : 18,
        bottom: isMobile ? 12 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chart
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
          // X Axis labels
          Padding(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((d) {
                return Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 13,
                        color: Colors.black,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Legend
          Padding(
            padding: EdgeInsets.only(top: isMobile ? 4 : 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendDot(color: const Color(0xFFC8102E)), // Zomato red
                SizedBox(width: isMobile ? 2 : 7),
                Text("Zomato", style: TextStyle(fontSize: isMobile ? 10 : 13)),
                SizedBox(width: isMobile ? 14 : 22),
                _legendDot(color: const Color(0xFFFF8C1A)), // Swiggy orange
                SizedBox(width: isMobile ? 2 : 7),
                Text("Swiggy", style: TextStyle(fontSize: isMobile ? 10 : 13)),
                SizedBox(width: isMobile ? 14 : 22),
                _legendDot(color: Colors.blue), // Online: blue
                SizedBox(width: isMobile ? 2 : 7),
                Text("Online", style: TextStyle(fontSize: isMobile ? 10 : 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot({required Color color}) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<String> days;
  final List<int> zomato, swiggy, online;
  final double barWidth, groupWidth, maxY;
  final bool isMobile;

  _BarChartPainter({
    required this.days,
    required this.zomato,
    required this.swiggy,
    required this.barWidth,
    required this.groupWidth,
    required this.maxY,
    required this.isMobile,
    required this.online,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height;
    final Paint axisPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;

    // Draw horizontal axis (bottom)
    canvas.drawLine(
      Offset(0, chartHeight - 1),
      Offset(size.width, chartHeight - 1),
      axisPaint,
    );

    // Draw horizontal grid lines (2 for 3 ticks)
    final gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;
    for (int i = 1; i <= 2; i++) {
      final y = chartHeight - (chartHeight * i / 3);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final double leftPad = isMobile ? 2 : 8;
    final barSpacing = isMobile ? 8.0 : 15.0;
    final groupSpace = (size.width - groupWidth * days.length) / (days.length + 1);

    double x = groupSpace / 2;

    for (int i = 0; i < days.length; i++) {
      // Zomato (red)
      _drawBar(
        canvas,
        x + leftPad,
        chartHeight,
        barWidth,
        zomato[i],
        maxY,
        const Color(0xFFC8102E),
      );
      // Swiggy (orange)
      _drawBar(
        canvas,
        x + barWidth + barSpacing + leftPad,
        chartHeight,
        barWidth,
        swiggy[i],
        maxY,
        const Color(0xFFFF8C1A),
      );

      _drawBar(canvas, x + 2 * (barWidth + barSpacing) + leftPad, chartHeight, barWidth, online[i], maxY, Colors.blue);

      x += groupWidth + groupSpace;
    }
  }

  void _drawBar(Canvas canvas, double x, double chartHeight, double width, int value, double maxY, Color color) {
    final barHeight = (value / maxY) * (chartHeight - (isMobile ? 16 : 32));
    final rect = Rect.fromLTWH(
      x,
      chartHeight - barHeight - 1,
      width,
      barHeight,
    );
    final paint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

// --- MAIN PAGE ---
class OnlineOrderRunningPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;

  const OnlineOrderRunningPage({super.key, required this.dbToBrandMap});

  @override
  State<OnlineOrderRunningPage> createState() => _OnlineOrderRunningPageState();
}

class _OnlineOrderRunningPageState extends State<OnlineOrderRunningPage>
    with SingleTickerProviderStateMixin {
  String? selectedBrand = "All";
  String? selectedRestaurant;
  String? selectedRecordType = "Last 2 days records";
  DateTimeRange? customDateRange;
  String? selectedStatus = "All";
  final TextEditingController orderNoController = TextEditingController();

  late TabController _tabController;
  bool showChart = false; // Chart/table toggle

  List<Map<String, dynamic>> onlineOrderRecords = [];
  List<Map<String, dynamic>> displayedRecords = [];
  bool isLoading = false;

  // Check if user has only one DB assigned
  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  // Get the single brand name if there's only one DB
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // If user has only one DB, set selectedBrand to that DB's brand
    if (hasOnlyOneDb) {
      selectedBrand = singleBrandName;
    }
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
    Map<String, List<int>> data = {
      "Zomato": List.filled(7, 0),
      "Swiggy": List.filled(7, 0),
      "Online": List.filled(7, 0),
    };
    for (var row in onlineOrderRecords) {
      final k = row['record'] as OnlineOrderReport;
      final date = k.orderDateTime;
      final label = "${date.day.toString().padLeft(2, '0')}-${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][date.month-1]}";
      int dayIdx = days.indexOf(label);
      if (dayIdx != -1) {
        if ((k.orderFrom ?? "").toLowerCase().contains("zomato")) data["Zomato"]![dayIdx]++;
        else if ((k.orderFrom ?? "").toLowerCase().contains("swiggy")) data["Swiggy"]![dayIdx]++;
        else if ((k.orderFrom ?? "").toLowerCase().contains("online")) data["Online"]![dayIdx]++;
      }
    }
    return data;
  }

  Future<void> fetchOnlineOrders() async {
    setState(() => isLoading = true);
    final config = await app.Config.loadFromAsset();
    List<String> dbNames;
    if (selectedBrand == null || selectedBrand == "All") {
      dbNames = widget.dbToBrandMap.keys.toList();
    } else {
      dbNames = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }
    DateTime startDate;
    DateTime endDate = DateTime.now();
    if (selectedRecordType == "Last 2 days records") {
      startDate = DateTime.now().subtract(const Duration(days: 1));
    } else if (selectedRecordType == "Last 7 days records") {
      startDate = DateTime.now().subtract(const Duration(days: 6));
    } else if (selectedRecordType == "Custom Date Range" && customDateRange != null) {
      startDate = customDateRange!.start;
      endDate = customDateRange!.end;
    } else {
      // "Today"
      startDate = DateTime.now();
    }

    final start = DateFormat('dd-MM-yyyy').format(startDate);
    final end = DateFormat('dd-MM-yyyy').format(endDate);
    final dbToOrders = await app.UserData.fetchOnlineOrdersForDbs(config, dbNames, start, end);

    // Flatten and attach dbName to each row
    List<Map<String, dynamic>> all = [];
    dbToOrders.forEach((db, list) {
      for (final k in list) {
        all.add({'dbName': db, 'record': k});
      }
    });

    setState(() {
      onlineOrderRecords = all;
      displayedRecords = all;
      isLoading = false;
    });
  }

  void applyFilters() {
    String? brand = selectedBrand;
    String? orderNo = orderNoController.text.trim();
    String? status = selectedStatus;
    String? restaurant = selectedRestaurant;
    setState(() {
      displayedRecords = onlineOrderRecords.where((row) {
        final k = row['record'] as OnlineOrderReport;
        bool match = true;
        if (brand != null && brand != "All") {
          final db = row['dbName'] as String;
          match &= widget.dbToBrandMap[db] == brand;
        }
        if (restaurant != null && restaurant.isNotEmpty) {
          final db = row['dbName'] as String;
          match &= ("$db - ${widget.dbToBrandMap[db]}" == restaurant);
        }
        if (orderNo != null && orderNo.isNotEmpty) {
          match &= k.onlineOrderId.contains(orderNo) || k.externalOrderId.contains(orderNo);
        }
        if (status != null && status != "All") {
          match &= _statusMatches(k.status, status);
        }
        return match;
      }).toList();
    });
  }

  bool _statusMatches(String value, String filter) {
    String status = value.toLowerCase();
    String filterValue = filter.toLowerCase();
    if (filterValue == "prepared") return status == "prepared" || status == "food ready";
    if (filterValue == "food ready") return status == "food ready";
    if (filterValue == "pick up") return status == "pick up";
    if (filterValue == "delivered") return status == "delivered";
    return status == filterValue;
  }

  void showAll() {
    setState(() {
      displayedRecords = onlineOrderRecords;
      selectedBrand = hasOnlyOneDb ? singleBrandName : "All";
      selectedStatus = "All";
      selectedRestaurant = null;
      orderNoController.clear();
      selectedRecordType = "Last 2 days records";
      customDateRange = null;
    });
  }

  Future<void> _handleRecordTypeChange(String? v) async {
    if (v == "Custom Date Range") {
      DateTime now = DateTime.now();
      DateTimeRange initialRange = customDateRange ??
          DateTimeRange(start: now.subtract(Duration(days: 6)), end: now);
      DateTimeRange? picked = await showDateRangePicker(
        context: context,
        initialDateRange: initialRange,
        firstDate: DateTime(2020),
        lastDate: now,
        builder: (context, child) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                minWidth: 320,
                maxHeight: 520,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: child!,
              ),
            ),
          );
        },
      );
      if (picked != null) {
        setState(() {
          selectedRecordType = v;
          customDateRange = picked;
        });
        await fetchOnlineOrders();
      }
    } else {
      setState(() {
        selectedRecordType = v;
        if (v != "Custom Date Range") customDateRange = null;
      });
      await fetchOnlineOrders();
    }
  }

  Future<void> exportToExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Online Order Report'];
    final headerStyle = excel.CellStyle(
      bold: true,
      fontFamily: excel.getFontFamily(excel.FontFamily.Calibri),
    );

    // Group data by brand name
    Map<String, List<OnlineOrderReport>> brandWiseData = {};
    for (var row in displayedRecords) {
      final dbName = row['dbName'] as String;
      final brand = widget.dbToBrandMap[dbName] ?? "Unknown";
      brandWiseData.putIfAbsent(brand, () => []).add(row['record']);
    }

    int rowIndex = 0;
    for (var entry in brandWiseData.entries) {
      // Brand Name Row
      sheet.appendRow([entry.key]);
      rowIndex++;
      // Header Row
      final headerRow = [
        'Order No.',
        'Outlet Name',
        'Order Type',
        'Customer',
        'Phone',
        'Date Time',
        'Gross Amount',
        'Net Amount',
        'Status',
        'Channel',
      ];
      sheet.appendRow(headerRow);
      for (int i = 0; i < headerRow.length; i++) {
        sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex))
          ..cellStyle = headerStyle;
      }
      rowIndex++;
      // Data rows
      for (var row in entry.value) {
        sheet.appendRow([
          row.onlineOrderId,
          row.restaurantName,
          row.orderType,
          row.customerName,
          row.phoneNumber,
          row.orderDateTime.toString(),
          row.grossAmount.toStringAsFixed(3), // Change here
          row.netAmount.toStringAsFixed(3),
          row.status,
          row.orderFrom,
        ]);
        rowIndex++;
      }
      rowIndex++; // Empty row between brands
      sheet.appendRow([]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/OnlineOrderReport.xlsx';
    final fileBytes = excelFile.encode();
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    OpenFile.open(filePath);
  }

  @override
  Widget build(BuildContext context) {
    final brandNames = widget.dbToBrandMap.values.toSet();
    final restaurantList = widget.dbToBrandMap.entries
        .map((e) => "${e.key} - ${e.value}")
        .toList();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    final chartData = barChartData;
    final simpleBarChart = SimpleBarChart(
      isMobile: isMobile,
      days: last7DaysLabels,
      zomato: chartData["Zomato"]!,
      swiggy: chartData["Swiggy"]!,
      online: chartData["Online"]!,
    );

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Scaffold(
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
                      // Only show outlet dropdown if there's more than one DB
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
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
                                overflow: TextOverflow.ellipsis,
                              ),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: "All",
                                  child: Text("All Outlets", style: TextStyle(fontWeight: FontWeight.normal)),
                                ),
                                ...brandNames.map(
                                      (brand) => DropdownMenuItem(
                                    value: brand,
                                    child: Text(
                                      brand,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) async {
                                setState(() {
                                  selectedBrand = value;
                                });
                                await fetchOnlineOrders();
                              },
                            ),
                          ),
                        )
                      else
                      // If only one DB, show just the outlet name without dropdown
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
                        onPressed: fetchOnlineOrders,
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
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                      const SizedBox(width: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 18,
                            vertical: isMobile ? 7 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                        icon: const Icon(Icons.help_outline, size: 18, color: Colors.black87),
                        label: Text(
                          "Aggregator Help Center",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.normal,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 24,
                        vertical: isMobile ? 10 : 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            elevation: 0,
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: isMobile ? 6 : 8,
                                      left: isMobile ? 5 : 10,
                                      bottom: isMobile ? 4 : 6),
                                  child: Text(
                                    "Online Orders Activity",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: isMobile ? 15 : 18,
                                        color: Colors.black),
                                  ),
                                ),
                                TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  indicatorColor: const Color(0xFFD5282B),
                                  labelColor: Colors.black,
                                  unselectedLabelColor: Colors.grey,
                                  labelStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 13 : 15,
                                  ),
                                  tabs: [
                                    _tabIconLabel(Icons.grid_view_rounded, "All"),
                                    _tabImageLabel("assets/images/zomato.png", "zomato"),
                                    _tabImageLabel("assets/images/SWIGGY.png", "Swiggy"),
                                    _tabIconLabel(Icons.cloud, "Online"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F8FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? 12 : 18,
                                  horizontal: isMobile ? 8 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () => setState(() => showChart = !showChart),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 6 : 10,
                                              vertical: isMobile ? 2 : 5),
                                          child: Row(
                                            children: [
                                              Icon(Icons.show_chart,
                                                  color: const Color(0xFF3498F3),
                                                  size: isMobile ? 22 : 30),
                                              SizedBox(width: isMobile ? 4 : 8),
                                              Text(
                                                "Last 7 Days Orders",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: isMobile ? 13 : 17,
                                                    color: Colors.black),
                                              ),
                                              SizedBox(width: isMobile ? 2 : 5),
                                              Text(
                                                showChart ? "(Hide Chart)" : "(View Chart)",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: isMobile ? 11 : 13,
                                                    color: Colors.grey),
                                              ),
                                              Icon(
                                                  showChart
                                                      ? Icons.arrow_drop_up
                                                      : Icons.arrow_drop_down,
                                                  color: Colors.grey),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (showChart)
                                    Padding(
                                      padding: EdgeInsets.only(top: isMobile ? 8 : 16, bottom: isMobile ? 8 : 16),
                                      child: simpleBarChart,
                                    ),
                                  // FILTERS ROW
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _filterDropdown(
                                          context,
                                          title: "Select Restaurant",
                                          value: selectedRestaurant,
                                          items: restaurantList,
                                          onChanged: (v) => setState(() => selectedRestaurant = v),
                                          width: isMobile ? 160 : 220,
                                        ),
                                        SizedBox(width: isMobile ? 8 : 16),
                                        _filterDropdown(
                                          context,
                                          title: "Record Type",
                                          value: selectedRecordType,
                                          items: [
                                            "Last 2 days records",
                                            "Last 7 days records",
                                            "Today",
                                            "Custom Date Range"
                                          ],
                                          onChanged: _handleRecordTypeChange,
                                          width: isMobile ? 140 : 200,
                                        ),
                                        SizedBox(width: isMobile ? 8 : 16),
                                        _filterDropdown(
                                          context,
                                          title: "Status",
                                          value: selectedStatus,
                                          items: [
                                            "All",
                                            "Food Ready",
                                            "Pick Up",
                                            "Delivered"
                                          ],
                                          onChanged: (v) => setState(() => selectedStatus = v),
                                          width: isMobile ? 120 : 150,
                                        ),
                                        SizedBox(width: isMobile ? 8 : 16),
                                        _filterTextField(context, "Order No.", orderNoController, width: isMobile ? 100 : 150),
                                        SizedBox(width: isMobile ? 8 : 16),
                                        SizedBox(
                                          height: 40,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD5282B),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                            ),
                                            onPressed: applyFilters,
                                            child: Text(
                                              "Search",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isMobile ? 12 : 15),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 16),
                                        SizedBox(
                                          height: 40,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                  color: Color(0xFFD5282B)),
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(7),
                                              ),
                                            ),
                                            onPressed: showAll,
                                            child: Text(
                                              "Show All",
                                              style: TextStyle(
                                                  color: const Color(0xFFD5282B),
                                                  fontSize: isMobile ? 12 : 15),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight: isMobile ? 200 : 300,
                                        maxHeight: isMobile ? 400 : 800),
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildOrderTable(isMobile: isMobile, channel: "All"),
                                        _buildOrderTable(isMobile: isMobile, channel: "Zomato"),
                                        _buildOrderTable(isMobile: isMobile, channel: "Swiggy"),
                                        _buildOrderTable(isMobile: isMobile, channel: "Online"),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Tab _tabIconLabel(IconData icon, String label) {
    return Tab(
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 5),
          Text(label, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Tab _tabImageLabel(String asset, String label) {
    return Tab(
      child: Row(
        children: [
          Image.asset(asset, width: 22, height: 22),
          const SizedBox(width: 5),
          Text(label, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _filterDropdown(
      BuildContext context, {
        required String title,
        required String? value,
        required List<String> items,
        required ValueChanged<String?> onChanged,
        double width = 150,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
              items: items
                  .map((r) => DropdownMenuItem(
                value: r,
                child: Text(
                  r,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterTextField(BuildContext context, String title, TextEditingController controller, {double width = 120}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "",
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderTable({required bool isMobile, required String channel}) {
    final rowsToShow = channel == "All"
        ? displayedRecords
        : displayedRecords.where((row) {
      final order = row['record'] as OnlineOrderReport;
      return order.orderFrom.toLowerCase().contains(channel.toLowerCase());
    }).toList();

    if (rowsToShow.isEmpty) {
      return Center(child: Text('No data for $channel'));
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            _tableCol("Order No.", isMobile),
            _tableCol("Outlet Name", isMobile),
            _tableCol("Order Type", isMobile),
            _tableCol("Customer", isMobile),
            _tableCol("Phone", isMobile),
            _tableCol("Date Time", isMobile),
            _tableCol("Gross", isMobile),
            _tableCol("Net", isMobile),
            _tableCol("Status", isMobile),
            _tableCol("Channel", isMobile),
          ],
          rows: rowsToShow.map((row) {
            final order = row['record'] as OnlineOrderReport;
            return DataRow(
              cells: [
                DataCell(Text(order.onlineOrderId)),
                DataCell(Text(order.restaurantName)),
                DataCell(Text(order.orderType)),
                DataCell(Text(order.customerName)),
                DataCell(Text(order.phoneNumber)),
                DataCell(Text(order.orderDateTime.toString())),
                DataCell(Text(order.grossAmount.toStringAsFixed(3))),
                DataCell(Text(order.netAmount.toStringAsFixed(3))),
                DataCell(Text(order.status)),
                DataCell(Text(order.orderFrom)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  DataColumn _tableCol(String label, bool isMobile) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10 : 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}