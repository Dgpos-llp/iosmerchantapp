//no change
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:merchant/KotSummaryReport.dart';
import 'SidePanel.dart';
import 'main.dart' as app;

class OrderSummaryReport {
  final String orderType;
  final int totalCount;
  final double totalAmount;

  OrderSummaryReport({
    required this.orderType,
    required this.totalCount,
    required this.totalAmount,
  });

  factory OrderSummaryReport.fromJson(Map<String, dynamic> json) {
    return OrderSummaryReport(
      orderType: json['orderType'] ?? '',
      totalCount: json['totalCount'] ?? 0,
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }
}

class TableStatus {
  final String tableName;
  final String status;
  final String area;
  final String db;

  TableStatus({
    required this.tableName,
    required this.status,
    required this.area,
    required this.db,
  });

  factory TableStatus.fromJson(Map<String, dynamic> json, String db) {
    return TableStatus(
      tableName: json['tableName'] ?? '',
      status: json['status'] ?? '',
      area: json['area'] ?? '',
      db: db,
    );
  }
}

class RunningOrderPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const RunningOrderPage({super.key, this.dbToBrandMap = const {}});

  @override
  State<RunningOrderPage> createState() => _RunningOrderPageState();
}

class _RunningOrderPageState extends State<RunningOrderPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? selectedBrand;
  List<KotSummaryReport> orders = [];
  bool isLoading = false;
  List<TableStatus> occupiedTables = [];
  List<OrderSummaryReport> orderSummaryList = [];

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    selectedBrand = hasOnlyOneDb ? widget.dbToBrandMap.values.first : "All";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllData();
    });
  }

  Future<void> _refreshAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchKotOrders(),
      fetchOccupiedTables(),
      fetchOrderSummary(),
    ]);
    setState(() => isLoading = false);
  }

  Future<void> fetchKotOrders() async {
    final config = await app.Config.loadFromAsset();
    final dbNames = widget.dbToBrandMap.keys.toList();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    Map<String, List<KotSummaryReport>> dbToKotSummaryMap =
    await app.UserData.fetchKotSummaryForDbs(config, dbNames, dateStr, dateStr);
    List<KotSummaryReport> allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    orders = allOrders.where((o) => o.kotStatus == "active").toList();
  }

  Future<void> fetchOrderSummary() async {
    final config = await app.Config.loadFromAsset();
    List<String> dbNames = (selectedBrand == null || selectedBrand == "All")
        ? widget.dbToBrandMap.keys.toList()
        : widget.dbToBrandMap.entries.where((e) => e.value == selectedBrand).map((e) => e.key).toList();

    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/ordersummary?startDate=$dateStr&endDate=$dateStr&$dbParams";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          orderSummaryList = decoded.map<OrderSummaryReport>((e) => OrderSummaryReport.fromJson(e)).toList();
        }
      }
    } catch (e) {}
  }

  Future<void> fetchOccupiedTables() async {
    List<TableStatus> allOccupied = [];
    final config = await app.Config.loadFromAsset();
    for (final db in widget.dbToBrandMap.keys) {
      final url = "${config.apiUrl}table/getAll?DB=$db";
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            final tables = decoded.map<TableStatus>((e) => TableStatus.fromJson(e, db))
                .where((t) => t.status.toLowerCase() == "occupied").toList();
            allOccupied.addAll(tables);
          }
        }
      } catch (e) {}
    }
    occupiedTables = allOccupied;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
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
          title: const Text("Running Status", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : _buildDesktopSelector(brandNames),
          actions: [
            _buildIconButton(icon: Icons.refresh, onPressed: _refreshAllData),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4154F1),
                unselectedLabelColor: const Color(0xFF7F8C8D),
                indicatorColor: const Color(0xFF4154F1),
                indicatorWeight: 3,
                tabs: const [Tab(text: "Live Analytics"), Tab(text: "Table Layout")],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4154F1)))
                  : TabBarView(
                controller: _tabController,
                children: [_buildOrdersTab(size), _buildTablesTab(size.width)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSelector(Set<String> brandNames) {
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
                value: selectedBrand,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D)),
                items: [
                  const DropdownMenuItem(value: "All", child: Text("All Outlets")),
                  ...brandNames.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))),
                ],
                onChanged: (value) {
                  setState(() => selectedBrand = value);
                  _refreshAllData();
                },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(widget.dbToBrandMap.values.first, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
          ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF7F8C8D)), onPressed: onPressed),
    );
  }

  Widget _buildOrdersTab(Size size) {
    final orderSum = orderSummaryList.fold<int>(0, (a, b) => a + b.totalCount);
    final amountSum = orderSummaryList.fold<double>(0.0, (a, b) => a + b.totalAmount);
    final isMobile = size.width < 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COMPACT TOP BOXES
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildCompactHeaderBox(
                    title: "Orders",
                    value: "$orderSum",
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF4154F1),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCompactHeaderBox(
                    title: "Amount",
                    value: amountSum.toStringAsFixed(3),
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF27AE60),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text("Live Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 2.5 : 1.3,
            ),
            itemCount: orderSummaryList.length,
            itemBuilder: (context, index) => _buildBreakdownCard(orderSummaryList[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderBox({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(OrderSummaryReport s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(s.orderType.toUpperCase(), style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text("${s.totalCount}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
          const Divider(height: 20),
          Text("₹ ${s.totalAmount.toStringAsFixed(3)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4154F1))),
        ],
      ),
    );
  }

  Widget _buildTablesTab(double width) {
    final selectedDb = selectedBrand == "All" ? null : widget.dbToBrandMap.entries.firstWhere((e) => e.value == selectedBrand, orElse: () => MapEntry('', '')).key;
    List<TableStatus> filteredTables = selectedDb == null || selectedDb.isEmpty ? occupiedTables : occupiedTables.where((t) => t.db == selectedDb).toList();
    Map<String, List<TableStatus>> areaMap = {};
    for (final t in filteredTables) { areaMap.putIfAbsent(t.area, () => []).add(t); }

    if (areaMap.isEmpty) return const Center(child: Text("No occupied tables", style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 16)));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: areaMap.length,
      itemBuilder: (context, index) {
        String areaName = areaMap.keys.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(areaName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: areaMap[areaName]!.map((t) => _buildTableCard(t)).toList()),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildTableCard(TableStatus t) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.2))),
      child: Column(
        children: [
          const Icon(Icons.chair, color: Color(0xFFE74C3C), size: 20),
          const SizedBox(height: 4),
          Text(t.tableName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2C3E50))),
          const Text("OCCUPIED", style: TextStyle(color: Color(0xFFE74C3C), fontSize: 8, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}