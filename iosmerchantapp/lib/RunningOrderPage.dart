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

  // Check if user has only one DB assigned
  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  // Get the single brand name if there's only one DB
  String? get singleBrandName => hasOnlyOneDb ? widget.dbToBrandMap.values.first : null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // If user has only one DB, set selectedBrand to that DB's brand
    if (hasOnlyOneDb) {
      selectedBrand = singleBrandName;
    } else {
      selectedBrand = "All";
    }
    fetchKotOrders();
    fetchOccupiedTables();
    fetchOrderSummary();
  }

  Future<void> fetchKotOrders() async {
    setState(() { isLoading = true; });
    final config = await app.Config.loadFromAsset();
    final dbNames = widget.dbToBrandMap.keys.toList();
    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);
    Map<String, List<KotSummaryReport>> dbToKotSummaryMap =
    await app.UserData.fetchKotSummaryForDbs(config, dbNames, dateStr, dateStr);
    List<KotSummaryReport> allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    List<KotSummaryReport> activeOrders = allOrders.where((o) => o.kotStatus == "active").toList();
    setState(() {
      orders = activeOrders;
      isLoading = false;
    });
  }

  Future<void> fetchOrderSummary() async {
    final config = await app.Config.loadFromAsset();
    final dbNames = selectedBrand == "All"
        ? widget.dbToBrandMap.keys.toList()
        : widget.dbToBrandMap.entries
        .where((e) => e.value == selectedBrand)
        .map((e) => e.key)
        .toList();

    final now = DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(now);

    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/ordersummary?startDate=$dateStr&endDate=$dateStr&$dbParams";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          setState(() {
            orderSummaryList = decoded.map<OrderSummaryReport>((e) => OrderSummaryReport.fromJson(e)).toList();
          });
        } else {
          setState(() { orderSummaryList = []; });
        }
      } else {
        setState(() { orderSummaryList = []; });
      }
    } catch (e) {
      setState(() { orderSummaryList = []; });
    }
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
            final tables = decoded
                .map<TableStatus>((e) => TableStatus.fromJson(e, db))
                .where((t) => t.status.toLowerCase() == "occupied")
                .toList();
            allOccupied.addAll(tables);
          }
        }
      } catch (e) {}
    }
    setState(() {
      occupiedTables = allOccupied;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandNames = widget.dbToBrandMap.values.toSet();
    final screenWidth = MediaQuery.of(context).size.width;
    List<KotSummaryReport> filteredOrders = orders.where((o) =>
    selectedBrand == "All" ||
        widget.dbToBrandMap[o.kotId] == selectedBrand
    ).toList();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 60,
                color: Colors.white,
                child: SingleChildScrollView(
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
                              onChanged: (value) {
                                setState(() {
                                  selectedBrand = value;
                                });
                                fetchOccupiedTables();
                                fetchOrderSummary();
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
                        label: const Text(
                          "",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onPressed: () {
                          fetchKotOrders();
                          fetchOccupiedTables();
                          fetchOrderSummary();
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
                          padding: const EdgeInsets.only(left: 160),
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            height: isMobile ? 32 : 40,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFD5282B),
                  unselectedLabelColor: Colors.black,
                  indicatorColor: const Color(0xFFD5282B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: "Running Orders"),
                    Tab(text: "Running Tables"),
                  ],
                ),
              ),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrdersTab(screenWidth, filteredOrders),
                    _buildTablesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersTab(double screenWidth, List<KotSummaryReport> orders) {
    final List<OrderSummaryReport> summary = orderSummaryList;
    final orderSum = summary.fold<int>(0, (a, b) => a + b.totalCount);
    final amountSum = summary.fold<double>(0.0, (a, b) => a + b.totalAmount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile
            ? 1
            : summary.length.clamp(1, 5); // allow more columns on desktop/tablet

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Orders", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                          Text("$orderSum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                        ],
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("₹", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                          Text(amountSum.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 20,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: summary.map((s) => _orderCard(
                  s.orderType,
                  s.totalCount,
                  s.totalAmount,
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderCard(String title, int orderCount, double amount, {String? subtitle}) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(
                  subtitle!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            const Text("Orders", style: TextStyle(color: Colors.grey, fontSize: 11)),
            Text(
              "$orderCount",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "₹ ${amount.toStringAsFixed(3)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablesTab() {
    final selectedDb = selectedBrand == "All"
        ? null
        : widget.dbToBrandMap.entries.firstWhere((e) => e.value == selectedBrand, orElse: () => MapEntry('', '')).key;
    List<TableStatus> filteredTables = selectedDb == null || selectedDb.isEmpty
        ? occupiedTables
        : occupiedTables.where((t) => t.db == selectedDb).toList();

    Map<String, List<TableStatus>> areaMap = {};
    for (final t in filteredTables) {
      areaMap.putIfAbsent(t.area, () => []).add(t);
    }
    return areaMap.isEmpty
        ? const Center(
      child: Text(
        "No Running Tables",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
    )
        : ListView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      children: areaMap.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD5282B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: entry.value
                  .map((t) => Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.09),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.tableName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      t.status,
                      style: TextStyle(
                        color: t.status.toLowerCase() == 'occupied'
                            ? Colors.red
                            : Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
        );
      }).toList(),
    );
  }
}