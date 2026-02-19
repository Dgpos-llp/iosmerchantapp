import 'package:excel/excel.dart' as excel;
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'SidePanel.dart';
import 'main.dart';
import 'package:merchant/TotalSalesReport.dart';
import 'package:fl_chart/fl_chart.dart';

class Dashboard extends ConsumerStatefulWidget {
  final Map<String, String> dbToBrandMap;

  const Dashboard({super.key, required this.dbToBrandMap});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<Dashboard> {
  String? selectedBrand;
  DateTimeRange? selectedDateRange;
  String get selectedDate => selectedDateRange != null
      ? "${DateFormat('dd-MM-yyyy').format(selectedDateRange!.start)} to ${DateFormat('dd-MM-yyyy').format(selectedDateRange!.end)}"
      : DateFormat('dd-MM-yyyy').format(DateTime.now());
  Map<String, dynamic> apiResponses = {};
  Map<String, TotalSalesReport> totalSalesResponses = {};
  bool isLoading = false;
  String chartType = "Bar Chart";
  Key chartKey = UniqueKey();
  List<TimeslotSales> timeslotSalesList = [];
  bool isLoadingTimeslotSales = false;
  List<Map<String, dynamic>> onlineOrderRecords = [];
  bool isLoadingOnlineOrders = false;
  Map<String, dynamic> settlementAmounts = {};

  String formatAmount(double value) => "  ${value.toStringAsFixed(3)}";

  String safeAmount(String? value) {
    if (value == null || value.isEmpty) {
      return "  0.000";
    }
    try {
      final amount = double.parse(value);
      return "  ${amount.toStringAsFixed(3)}";
    } catch (e) {
      return "  0.000";
    }
  }

  bool get hasOnlyOneDb => widget.dbToBrandMap.length == 1;

  Future<void> fetchTimeslotSales() async {
    setState(() => isLoadingTimeslotSales = true);
    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    List<String> dbs;
    if (selectedBrand == null || selectedBrand == "All") {
      dbs = widget.dbToBrandMap.keys.toList();
    } else {
      dbs = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    timeslotSalesList = await UserData.fetchTimeslotSalesForDbs(
      config,
      dbs,
      startDate,
      endDate,
    );
    setState(() => isLoadingTimeslotSales = false);
  }

  Future<void> fetchOnlineOrders() async {
    setState(() => isLoadingOnlineOrders = true);
    final config = await Config.loadFromAsset();
    List<String> dbNames;
    if (selectedBrand == null || selectedBrand == "All") {
      dbNames = widget.dbToBrandMap.keys.toList();
    } else {
      dbNames = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    final dbToOrders = await UserData.fetchOnlineOrdersForDbs(config, dbNames, startDate, endDate);
    List<Map<String, dynamic>> all = [];
    dbToOrders.forEach((db, list) {
      for (final k in list) {
        all.add({'dbName': db, 'record': k});
      }
    });

    setState(() {
      onlineOrderRecords = all;
      isLoadingOnlineOrders = false;
    });
  }

  Map<String, dynamic> get onlineOrderTotals {
    int totalOrders = 0;
    double totalAmount = 0;

    for (var row in onlineOrderRecords) {
      final record = row['record'];
      if ((record.orderFrom ?? "").toLowerCase().contains("zomato") ||
          (record.orderFrom ?? "").toLowerCase().contains("swiggy") ||
          (record.orderFrom ?? "").toLowerCase().contains("online")) {
        totalOrders++;
        totalAmount += double.tryParse(record.grossAmount?.toString() ?? '0') ?? 0;
      }
    }
    return {
      "orders": totalOrders,
      "amount": totalAmount,
    };
  }

  List<ChartBarData> get barData {
    if (timeslotSalesList.isNotEmpty) {
      return timeslotSalesList.map((slot) => ChartBarData(
        slot.timeslot,
        slot.dineInSales.round(),
        slot.takeAwaySales.round(),
        slot.deliverySales.round(),
        slot.onlineSales.round(),
        slot.counterSales.round(),
      )).toList();
    } else if (selectedBrand != null && selectedBrand != "All" && totalSalesResponses.isNotEmpty) {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;
      if (report != null) {
        return [
          ChartBarData(
            "Total",
            double.tryParse(report.getField("dineInSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("takeAwaySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("homeDeliverySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("onlineSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("counterSales", fallback: "0"))?.round() ?? 0,
          ),
        ];
      }
    }
    return [];
  }

  List<ChartLineData> get lineData {
    if (timeslotSalesList.isNotEmpty) {
      return timeslotSalesList.map((slot) => ChartLineData(
        slot.timeslot,
        slot.dineInSales.round(),
        slot.takeAwaySales.round(),
        slot.deliverySales.round(),
        slot.onlineSales.round(),
        slot.counterSales.round(),
      )).toList();
    } else if (selectedBrand != null && selectedBrand != "All" && totalSalesResponses.isNotEmpty) {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;
      if (report != null) {
        return [
          ChartLineData(
            "Total",
            double.tryParse(report.getField("dineInSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("takeAwaySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("homeDeliverySales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("onlineSales", fallback: "0"))?.round() ?? 0,
            double.tryParse(report.getField("counterSales", fallback: "0"))?.round() ?? 0,
          ),
        ];
      }
    }
    return [];
  }

  String quickDateLabel = "Today";
  DateTimeRange? selectedQuickDateRange;

  void onQuickDateSelected(String label) async {
    DateTime now = DateTime.now();
    DateTime start, end;
    switch (label) {
      case "Today":
        start = end = DateTime(now.year, now.month, now.day);
        break;
      case "Yesterday":
        start = end = DateTime(now.year, now.month, now.day).subtract(Duration(days: 1));
        break;
      case "Last 7 Days":
        end = DateTime(now.year, now.month, now.day);
        start = end.subtract(Duration(days: 6));
        break;
      case "Last 30 Days":
        end = DateTime(now.year, now.month, now.day);
        start = end.subtract(Duration(days: 29));
        break;
      case "This Month":
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day);
        break;
      case "Last Month":
        DateTime firstDayThisMonth = DateTime(now.year, now.month, 1);
        DateTime lastDayLastMonth = firstDayThisMonth.subtract(Duration(days: 1));
        start = DateTime(lastDayLastMonth.year, lastDayLastMonth.month, 1);
        end = DateTime(lastDayLastMonth.year, lastDayLastMonth.month, lastDayLastMonth.day);
        break;
      case "Custom Range":
        DateTime now = DateTime.now();
        DateTimeRange initialRange = selectedQuickDateRange ?? DateTimeRange(start: now, end: now);
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
            quickDateLabel = "Custom Range";
            selectedQuickDateRange = picked;
            selectedDateRange = picked;
          });
          await fetchTotalSales();
          await fetchTimeslotSales();
          await fetchOnlineOrders();
        }
        return;
      default:
        return;
    }
    setState(() {
      quickDateLabel = label;
      selectedQuickDateRange = DateTimeRange(start: start, end: end);
      selectedDateRange = DateTimeRange(start: start, end: end);
    });
    await fetchTotalSales();
    await fetchTimeslotSales();
    await fetchOnlineOrders();
  }

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    selectedDateRange = DateTimeRange(start: today, end: today);

    if (hasOnlyOneDb) {
      selectedBrand = widget.dbToBrandMap.values.first;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchTotalSales();
      fetchTimeslotSales();
      fetchOnlineOrders();
    });
  }

  List<Map<String, dynamic>> get summaryTabs {
    String formatAmount(double value) => "  ${value.toStringAsFixed(3)}";
    String formatOrders(int value) => "$value Order${value == 1 ? "" : "s"}";

    if (selectedBrand == null || selectedBrand == "All") {
      double totalSales = 0, dineIn = 0, takeAway = 0, delivery = 0;
      int totalOrders = 0, dineOrders = 0, takeAwayOrders = 0, deliveryOrders = 0;
      double counter = 0;
      int counterOrders = 0;

      for (final report in totalSalesResponses.values) {
        totalSales   += double.tryParse(report.getField("grandTotal", fallback: "0.000")) ?? 0;
        dineIn       += double.tryParse(report.getField("dineInSales", fallback: "0.000")) ?? 0;
        takeAway     += double.tryParse(report.getField("takeAwaySales", fallback: "0.000")) ?? 0;
        delivery     += double.tryParse(report.getField("homeDeliverySales", fallback: "0.000")) ?? 0;
        counter += double.tryParse(report.getField("counterSales", fallback: "0.000")) ?? 0;
        counterOrders += int.tryParse(report.getField("counterOrders", fallback: "0")) ?? 0;
        totalOrders      += int.tryParse(report.getField("totalOrders", fallback: "0")) ?? 0;
        dineOrders       += int.tryParse(report.getField("dineInOrders", fallback: "0")) ?? 0;
        takeAwayOrders   += int.tryParse(report.getField("takeAwayOrders", fallback: "0")) ?? 0;
        deliveryOrders   += int.tryParse(report.getField("homeDeliveryOrders", fallback: "0")) ?? 0;
      }

      return [
        {
          "title": "Total Sales",
          "amount": formatAmount(totalSales),
          "orders": formatOrders(totalOrders),
          "icon": Icons.local_activity,
          "iconColor": Color(0xFFFCA2A2),
        },
        {
          "title": "Dine In",
          "amount": formatAmount(dineIn),
          "orders": formatOrders(dineOrders),
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF93E5F9),
        },
        {
          "title": "TAKE AWAY",
          "amount": formatAmount(takeAway),
          "orders": formatOrders(takeAwayOrders),
          "icon": Icons.local_drink,
          "iconColor": Color(0xFFEEE6FF),
        },
        {
          "title": "Delivery",
          "amount": formatAmount(delivery),
          "orders": formatOrders(deliveryOrders),
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFFFE6B9),
        },
        {
          "title": "Counter",
          "amount": formatAmount(counter),
          "orders": formatOrders(counterOrders),
          "icon": Icons.point_of_sale,
          "iconColor": const Color(0xFFF0C987),
        },
      ];
    } else {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;

      return [
        {
          "title": "Total Sales",
          "amount": safeAmount(report?.getField("grandTotal")),
          "orders": report?.getField("totalOrders") ?? "0 Orders",
          "icon": Icons.local_activity,
          "iconColor": Color(0xFFFCA2A2),
        },
        {
          "title": "Dine In",
          "amount": safeAmount(report?.getField("dineInSales")),
          "orders": report?.getField("dineInOrders") ?? "0 Orders",
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF93E5F9),
        },
        {
          "title": "Take Away",
          "amount": safeAmount(report?.getField("takeAwaySales")),
          "orders": report?.getField("takeAwayOrders") ?? "0 Orders",
          "icon": Icons.local_drink,
          "iconColor": Color(0xFFEEE6FF),
        },
        {
          "title": "Delivery",
          "amount": safeAmount(report?.getField("homeDeliverySales")),
          "orders": report?.getField("homeDeliveryOrders") ?? "0 Orders",
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFFFE6B9),
        },
        {
          "title": "Counter",
          "amount": safeAmount(report?.getField("counterSales")),
          "orders": report?.getField("counterOrders") ?? "0 Orders",
          "icon": Icons.point_of_sale,
          "iconColor": const Color(0xFFF0C987),
        },
      ];
    }
  }

  // New getter for additional summary tabs (Tax, Discount, Net Sales)
  List<Map<String, dynamic>> get additionalSummaryTabs {
    if (selectedBrand == null || selectedBrand == "All") {
      double netSales = 0, discount = 0, tax = 0;

      for (final report in totalSalesResponses.values) {
        netSales += double.tryParse(report.getField("netTotal", fallback: "0.000")) ?? 0;
        discount += double.tryParse(report.getField("billDiscount", fallback: "0.000")) ?? 0;
        tax += double.tryParse(report.getField("billTax", fallback: "0.000")) ?? 0;
      }

      return [
        {
          "title": "Net Sales",
          "amount": formatAmount(netSales),
          "orders": "",
          "icon": Icons.show_chart,
          "iconColor": Colors.orange[100],
        },
        {
          "title": "Discounts",
          "amount": formatAmount(discount),
          "orders": "",
          "icon": Icons.discount,
          "iconColor": Colors.green[100],
        },
        {
          "title": "Taxes",
          "amount": formatAmount(tax),
          "orders": "",
          "icon": Icons.account_balance,
          "iconColor": Colors.purple[100],
        },
      ];
    } else {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;

      return [
        {
          "title": "Net Sales",
          "amount": safeAmount(report?.getField("netTotal")),
          "orders": "",
          "icon": Icons.show_chart,
          "iconColor": Colors.orange[100],
        },
        {
          "title": "Discounts",
          "amount": safeAmount(report?.getField("billDiscount")),
          "orders": "",
          "icon": Icons.discount,
          "iconColor": Colors.green[100],
        },
        {
          "title": "Taxes",
          "amount": safeAmount(report?.getField("billTax", fallback: "0.000")),
          "orders": "",
          "icon": Icons.account_balance,
          "iconColor": Colors.purple[100],
        },
      ];
    }
  }

  List<Map<String, dynamic>> get onlineOrderChannels {
    //double zomatoAmount = double.tryParse(settlementAmounts["Zomato"]?.toString() ?? '0') ?? 0;
   // double swiggyAmount = double.tryParse(settlementAmounts["Swiggy"]?.toString() ?? '0') ?? 0;
    double onlineAmount = double.tryParse(settlementAmounts["Online"]?.toString() ?? '0') ?? 0;

    List<Map<String, dynamic>> channels = [];

 /*   if (zomatoAmount > 0) {
      channels.add({
        "icon": "assets/images/zomato.png",
        "name": "Zomato",
        "amount": "  ${zomatoAmount.toStringAsFixed(3)}",
        "orders": "Settlement",
        "active": true,
      });
    }

    if (swiggyAmount > 0) {
      channels.add({
        "icon": "assets/images/SWIGGY.png",
        "name": "Swiggy",
        "amount": "  ${swiggyAmount.toStringAsFixed(3)}",
        "orders": "Settlement",
        "active": true,
      });
    }*/

    if (onlineAmount > 0 || channels.isEmpty) {
      channels.add({
        "icon": "assets/images/online.png",
        "name": "Online",
        "amount": "  ${onlineAmount.toStringAsFixed(3)}",
        "orders": "Settlement",
        "active": onlineAmount > 0,
      });
    }

    return channels;
  }

  List<Map<String, dynamic>> get paymentBifurcation {
    List<Map<String, dynamic>> paymentData = [];
    List<Color> colors = [
      const Color(0xFF4886FF), Colors.amber, Colors.cyan,
      Colors.green, const Color(0xFFF44336), const Color(0xFFFFA726),
      Colors.purple, Colors.teal, Colors.indigo, Colors.pink,
    ];

    int colorIndex = 0;

    if (settlementAmounts.isNotEmpty) {
      settlementAmounts.forEach((mode, amount) {
        double amountValue = double.tryParse(amount.toString()) ?? 0.0;
        if (amountValue > 0) {
          paymentData.add({
            "color": colors[colorIndex % colors.length],
            "label": mode,
            "value": formatAmount(amountValue),
            "raw": amountValue,
          });
          colorIndex++;
        }
      });
    }

    double swiggyAmt = 0;
    double zomatoAmt = 0;

    for (var row in onlineOrderRecords) {
      final record = row['record'];
      final channel = (record.orderFrom ?? "").toLowerCase();
      final amount = double.tryParse(record.grossAmount?.toString() ?? '0') ?? 0;

      if (channel.contains('swiggy')) swiggyAmt += amount;
      if (channel.contains('zomato')) zomatoAmt += amount;
    }

    if (zomatoAmt > 0) {
      paymentData.add({
        "color": Colors.redAccent,
        "label": "Zomato",
        "value": formatAmount(zomatoAmt),
        "raw": zomatoAmt,
      });
    }

    if (swiggyAmt > 0) {
      paymentData.add({
        "color": Colors.orangeAccent,
        "label": "Swiggy",
        "value": formatAmount(swiggyAmt),
        "raw": swiggyAmt,
      });
    }

    return paymentData;
  }
  Future<void> fetchData({bool reset = false}) async {
    if (reset) {
      setState(() {
        apiResponses = {};
      });
    }
    setState(() {
      isLoading = true;
    });

    final config = await Config.loadFromAsset();
    final apiUrl = config.apiUrl;
    for (final dbName in widget.dbToBrandMap.keys) {
      final brandName = widget.dbToBrandMap[dbName];
      if (selectedBrand != null &&
          selectedBrand != "All" &&
          brandName != selectedBrand) {
        continue;
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> fetchTotalSales() async {
    setState(() {
      isLoading = true;
      totalSalesResponses = {};
      String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
      String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);
    });

    final config = await Config.loadFromAsset();
    String startDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.start);
    String endDate = DateFormat('dd-MM-yyyy').format(selectedDateRange!.end);

    List<String> dbs;
    if (selectedBrand == null || selectedBrand == "All") {
      dbs = widget.dbToBrandMap.keys.toList();
    } else {
      dbs = widget.dbToBrandMap.entries
          .where((entry) => entry.value == selectedBrand)
          .map((entry) => entry.key)
          .toList();
    }

    totalSalesResponses = await UserData.fetchTotalSalesForDbs(
      config,
      dbs,
      startDate,
      endDate,
    );

    if (totalSalesResponses.isNotEmpty) {
      TotalSalesReport? firstReport = totalSalesResponses.values.first;
      if (firstReport != null) {
        setState(() {
          settlementAmounts = firstReport.settlementAmounts ?? {};
        });
      }
    }

    print("🌐 Fetching total sales for DBs: ${dbs.join(',')}");
    print("📅 Date range: $startDate to $endDate");
    print("📝 Total Sales Responses: $totalSalesResponses");

    setState(() {
      isLoading = false;
    });
  }

  String getField(String key, {String fallback = "0.000"}) {
    if (selectedBrand == null || selectedBrand == "All") {
      if (totalSalesResponses.isEmpty) return fallback;
      final report = totalSalesResponses.entries.isNotEmpty ? totalSalesResponses.entries.first.value : null;
      if (report == null) return fallback;
      return report.getField(key, fallback: fallback);
    } else {
      final dbKey = widget.dbToBrandMap.entries.firstWhere((e) => e.value == selectedBrand).key;
      final report = totalSalesResponses[dbKey];
      if (report == null) return fallback;
      return report.getField(key, fallback: fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineTotals = onlineOrderTotals;
    final brandNames = widget.dbToBrandMap.values.toSet();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isMobile = size.width < 600;

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
            toolbarHeight: 60,
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
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.normal),
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: "All",
                              child: Text("All Outlets", style: TextStyle(fontWeight: FontWeight.normal)),
                            ),
                            ...brandNames.map((brand) => DropdownMenuItem(
                              value: brand,
                              child: Text(
                                brand,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.normal),
                              ),
                            )),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              selectedBrand = value;
                            });
                            await fetchTotalSales();
                            await fetchTimeslotSales();
                            await fetchOnlineOrders();
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
                        widget.dbToBrandMap.values.first,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (Platform.isWindows && !isMobile)
                    Padding(
                      padding: const EdgeInsets.only(left: 950, top: 10),
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
                      padding: const EdgeInsets.only(left: 190),
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
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child:SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 0),
                      child: Text(
                        "Dashboard",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD5282B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download, color: Colors.black),
                      label: const Text(
                        "Export",
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.normal),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      ),
                      onPressed: () {
                        exportDashboardExcel();
                      },
                    ),
                    const SizedBox(width: 5),
                    PopupMenuButton<String>(
                      offset: const Offset(0, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: Colors.white,
                      padding: EdgeInsets.zero,
                      onSelected: onQuickDateSelected,
                      itemBuilder: (context) => [
                        for (final label in [
                          "Today", "Yesterday", "Last 7 Days", "Last 30 Days",
                          "This Month", "Last Month", "Custom Range"
                        ])
                          PopupMenuItem<String>(
                            value: label,
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                              ),
                            ),
                          ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                  ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                  : quickDateLabel == "Today"
                                  ? DateFormat('dd MMM').format(DateTime.now())
                                  : quickDateLabel,
                              style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 15),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.black),
                      label: const Text(
                        "",
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.black,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontWeight: FontWeight.normal),
                        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 10),
                      ),
                      onPressed: () async {
                        await fetchTotalSales();
                        await fetchTimeslotSales();
                        await fetchOnlineOrders();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double width = constraints.maxWidth;
                      final int gridCol = width > 1200
                          ? 4
                          : width > 900
                          ? 3
                          : width > 600
                          ? 2
                          : 1;
                      final double aspect = width < 400
                          ? 1.4
                          : width < 600
                          ? 1.7
                          : 2.1;
                      return SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 8 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasOnlyOneDb || (selectedBrand != null && selectedBrand != "All"))
                              Padding(
                                padding: EdgeInsets.only(bottom: isMobile ? 10 : 18),
                                child: buildSummaryTabs(isMobile),
                              ),
                            if (hasOnlyOneDb || (selectedBrand != null && selectedBrand != "All"))
                              Padding(
                                padding: EdgeInsets.only(bottom: isMobile ? 10 : 18),
                                child: buildAdditionalSummaryTabs(isMobile),
                              ),
                            if (selectedBrand != null && selectedBrand != "All")
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18.0),
                                child: Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 1,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 10 : 24,
                                        vertical: isMobile ? 12 : 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              const Text(
                                                "Sales",
                                                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                margin: const EdgeInsets.only(right: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: chartType,
                                                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                    borderRadius: BorderRadius.circular(8),
                                                    isDense: true,
                                                    items: [
                                                      DropdownMenuItem(
                                                        value: "Bar Chart",
                                                        child: Row(
                                                          children: const [
                                                            Icon(Icons.bar_chart, size: 18, color: Colors.black54),
                                                            SizedBox(width: 4),
                                                            Text("Bar Chart"),
                                                          ],
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: "Line Chart",
                                                        child: Row(
                                                          children: const [
                                                            Icon(Icons.show_chart, size: 18, color: Colors.black54),
                                                            SizedBox(width: 4),
                                                            Text("Line Chart"),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                    onChanged: (v) => setState(() => chartType = v!),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                margin: const EdgeInsets.only(right: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                          ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                          : quickDateLabel == "Today"
                                                          ? DateFormat('dd MMM').format(DateTime.now())
                                                          : quickDateLabel,
                                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                offset: const Offset(0, 45),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                color: Colors.white,
                                                padding: EdgeInsets.zero,
                                                onSelected: onQuickDateSelected,
                                                itemBuilder: (context) => [
                                                  for (final label in [
                                                    "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                                  ])
                                                    PopupMenuItem<String>(
                                                      value: label,
                                                      child: Text(
                                                        label,
                                                        style: TextStyle(
                                                          fontWeight: quickDateLabel == label ? FontWeight.normal : FontWeight.normal,
                                                          color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                                child: const Icon(Icons.date_range, color: Colors.black54),
                                              ),
                                              IconButton(
                                                visualDensity: VisualDensity.compact,
                                                icon: const Icon(Icons.refresh, size: 20, color: Colors.black54),
                                                onPressed: () {
                                                  setState(() {
                                                    chartKey = UniqueKey();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 7.0),
                                          child: Row(
                                            children: [
                                              _legendDot(Colors.blue),
                                              const SizedBox(width: 4),
                                              const Text("Dine In", style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 14),
                                              _legendDot(Colors.cyan),
                                              const SizedBox(width: 4),
                                              const Text("Take Away", style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 14),
                                              _legendDot(Colors.green),
                                              const SizedBox(width: 4),
                                              const Text("Delivery", style: TextStyle(fontSize: 13)),
                                              const SizedBox(width: 14),
                                              _legendDot(Colors.orange),
                                              const SizedBox(width: 4),
                                              const Text("Online", style: TextStyle(fontSize: 13)),
                                              _legendDot(Colors.purple),
                                              const SizedBox(width: 4),
                                              const Text("Counter", style: TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 250),
                                          child: isLoadingTimeslotSales
                                              ? const Center(child: CircularProgressIndicator())
                                              : (chartType == "Bar Chart"
                                              ? _SalesBarChartWidget(data: barData, key: chartKey)
                                              : SalesLineChartWidget(data: lineData, key: chartKey)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (selectedBrand != null && selectedBrand != "All")
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18.0),
                                child: Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 1,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 10 : 24,
                                        vertical: isMobile ? 14 : 22),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text("Online Ordersss", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18)),
                                            const Spacer(),
                                            PopupMenuButton<String>(
                                              offset: const Offset(0, 45),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              color: Colors.white,
                                              padding: EdgeInsets.zero,
                                              onSelected: onQuickDateSelected,
                                              itemBuilder: (context) => [
                                                for (final label in [
                                                  "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                                ])
                                                  PopupMenuItem<String>(
                                                    value: label,
                                                    child: Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontWeight: quickDateLabel == label ? FontWeight.normal : FontWeight.normal,
                                                        color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                          ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                          : quickDateLabel == "Today"
                                                          ? DateFormat('dd MMM').format(DateTime.now())
                                                          : quickDateLabel,
                                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.refresh, color: Colors.black54),
                                              onPressed: () {},
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text("Total Sales", style: TextStyle(fontWeight: FontWeight.normal, fontSize: isMobile ? 14 : 17)),
                                            ),
                                            Expanded(
                                              child: Text("Total Orders", style: TextStyle(fontWeight: FontWeight.normal, fontSize: isMobile ? 14 : 17)),
                                            ),
                                            const Spacer(),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "  ${onlineTotals['amount'].toStringAsFixed(3)}",
                                                style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.normal),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                "${onlineTotals['orders']}",
                                                style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.normal),
                                              ),
                                            ),
                                            const Spacer(),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: isMobile ? 100 : 140,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: onlineOrderChannels.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                                            itemBuilder: (context, index) {
                                              final channel = onlineOrderChannels[index];
                                              return Container(
                                                width: isMobile ? 180 : 220,
                                                padding: EdgeInsets.all(isMobile ? 10 : 18),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: channel["active"] ? Colors.grey[300]! : Colors.grey[200]!
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Image.asset(channel["icon"], width: 24, height: 24),
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: Text(
                                                            channel["name"],
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.normal,
                                                              fontSize: isMobile ? 15 : 17,
                                                              color: Colors.black87,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                        channel["amount"],
                                                        style: TextStyle(
                                                            fontSize: isMobile ? 17 : 20,
                                                            fontWeight: FontWeight.normal
                                                        )
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (selectedBrand != null && selectedBrand != "All")
                              Padding(
                                padding: const EdgeInsets.only(bottom: 18.0),
                                child: Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 1,
                                  color: Colors.white,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 10 : 24,
                                      vertical: isMobile ? 14 : 20,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: 40,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                const Text(
                                                  "Payment Bifurcation",
                                                  style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                PopupMenuButton<String>(
                                                  offset: const Offset(0, 45),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  color: Colors.white,
                                                  padding: EdgeInsets.zero,
                                                  onSelected: onQuickDateSelected,
                                                  itemBuilder: (context) => [
                                                    for (final label in [
                                                      "Today", "Yesterday", "Last 7 Days", "Last 30 Days", "This Month", "Last Month", "Custom Range"
                                                    ])
                                                      PopupMenuItem<String>(
                                                        value: label,
                                                        child: Text(
                                                          label,
                                                          style: TextStyle(
                                                            fontWeight: quickDateLabel == label ? FontWeight.normal : FontWeight.normal,
                                                            color: quickDateLabel == label ? Colors.black : Colors.grey[700],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: Colors.grey.shade300),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                                                              ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                                                              : quickDateLabel == "Today"
                                                              ? DateFormat('dd MMM').format(DateTime.now())
                                                              : quickDateLabel,
                                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black54),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.refresh, color: Colors.black54),
                                                  onPressed: () {},
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        LayoutBuilder(
                                          builder: (context, box) {
                                            double totalWidth = min(320.0, box.maxWidth - 20);
                                            double barHeight = isMobile ? 24 : 28;
                                            List<double> values = paymentBifurcation
                                                .map((p) => double.tryParse(p["value"].toString().replaceAll(" ", "").replaceAll(",", "").trim()) ?? 0)
                                                .toList();
                                            double total = values.fold(0.0, (a, b) => a + b);
                                            List<double> widths = total > 0
                                                ? values.map((v) => totalWidth * (v / total)).toList()
                                                : List.filled(values.length, totalWidth / values.length);
                                            int maxIdx = values.indexOf(values.reduce(max));
                                            String percentText = total > 0 ? "100%" : "";
                                            return Center(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                    width: totalWidth,
                                                    height: barHeight,
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(barHeight / 2),
                                                      color: Colors.grey[100],
                                                    ),
                                                    child: Row(
                                                      children: List.generate(paymentBifurcation.length, (i) {
                                                        return Container(
                                                          width: widths[i],
                                                          height: barHeight,
                                                          decoration: BoxDecoration(
                                                            color: paymentBifurcation[i]["color"],
                                                            borderRadius: BorderRadius.horizontal(
                                                              left: i == 0 ? Radius.circular(barHeight / 2) : Radius.zero,
                                                              right: i == paymentBifurcation.length - 1 ? Radius.circular(barHeight / 2) : Radius.zero,
                                                            ),
                                                          ),
                                                          child: (i == maxIdx && total > 0)
                                                              ? Center(
                                                            child: Text(
                                                              percentText,
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.normal,
                                                              ),
                                                            ),
                                                          )
                                                              : null,
                                                        );
                                                      }),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: paymentBifurcation.map((p) {
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 3.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      color: p["color"],
                                                      borderRadius: BorderRadius.circular(3),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      p["label"],
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: isMobile ? 14 : 15,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    p["value"],
                                                    style: TextStyle(fontWeight: FontWeight.normal, fontSize: isMobile ? 14 : 16),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (selectedBrand == null || selectedBrand == "All") ...[
                              buildStatsGrid(context, stats),
                              const SizedBox(height: 20),
                              _buildOutletwiseStatisticsTable(context, isMobile: isMobile),
                              const SizedBox(height: 20),
                              if (totalSalesResponses.isNotEmpty)
                                Card(
                                  color: Colors.white,
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      /* children: [
                                        const Text("Total Sales API Result", style: TextStyle(fontWeight: FontWeight.normal, fontSize: 16)),
                                        for (final entry in totalSalesResponses.entries)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: Text("${entry.key}: ${entry.value.totalSales}"),
                                          ),
                                      ],*/
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSummaryTabs(bool isMobile) {
    final tabs = summaryTabs;
    if (tabs.isEmpty) return SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Container(
            width: isMobile ? 180 : 220,
            margin: EdgeInsets.only(right: isMobile ? 10 : 18),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 18, vertical: isMobile ? 14 : 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tab["title"],
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: isMobile ? 13 : 17,
                                  color: Colors.black87)),
                          const SizedBox(height: 10),
                          Text(tab["amount"],
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: isMobile ? 18 : 22,
                                  color: Colors.black87)),
                          const SizedBox(height: 3),
                          Text(tab["orders"],
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: isMobile ? 13 : 14,
                                  color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: tab["iconColor"] as Color?,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(isMobile ? 10 : 16),
                      child: tab["isImage"] == true
                          ? Image.asset(
                        tab["iconPath"],
                        width: isMobile ? 28 : 38,
                        height: isMobile ? 28 : 38,
                      )
                          : Icon(tab["icon"], color: Colors.black54, size: isMobile ? 28 : 38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // New method to build additional summary tabs (Tax, Discount, Net Sales)
  Widget buildAdditionalSummaryTabs(bool isMobile) {
    final tabs = additionalSummaryTabs;
    if (tabs.isEmpty) return SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Container(
            width: isMobile ? 180 : 220,
            margin: EdgeInsets.only(right: isMobile ? 10 : 18),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 18, vertical: isMobile ? 14 : 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tab["title"],
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: isMobile ? 13 : 17,
                                  color: Colors.black87)),
                          const SizedBox(height: 10),
                          Text(tab["amount"],
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: isMobile ? 18 : 22,
                                  color: Colors.black87)),
                          const SizedBox(height: 3),
                          Text(tab["orders"],
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: isMobile ? 13 : 14,
                                  color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: tab["iconColor"] as Color?,
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(isMobile ? 10 : 16),
                      child: tab["isImage"] == true
                          ? Image.asset(
                        tab["iconPath"],
                        width: isMobile ? 28 : 38,
                        height: isMobile ? 28 : 38,
                      )
                          : Icon(tab["icon"], color: Colors.black54, size: isMobile ? 28 : 38),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Map<String, dynamic>> get stats {
    int swiggyOrders = 0, zomatoOrders = 0;
    double swiggyAmount = 0, zomatoAmount = 0;

    if (selectedBrand == null || selectedBrand == "All") {
      for (var row in onlineOrderRecords) {
        final record = row['record'];
        final channel = (record.orderFrom ?? "").toLowerCase();
        final amount = double.tryParse(record.grossAmount?.toString() ?? '0') ?? 0;
        if (channel.contains('swiggy')) {
          swiggyOrders++;
          swiggyAmount += amount;
        } else if (channel.contains('zomato')) {
          zomatoOrders++;
          zomatoAmount += amount;
        }
      }
    }

    List<Map<String, dynamic>> list = [
      {
        "title": "Total Sales",
        "amount": "  ${getField("grandTotal", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.bar_chart,
        "iconColor": const Color(0xFFFCA2A2),
      },
      {
        "title": "Dine In",
        "amount": "  ${getField("dineInSales", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.restaurant,
        "iconColor": const Color(0xFF93E5F9),
      },
      {
        "title": "Take Away",
        "amount": "  ${getField("takeAwaySales", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.local_drink,
        "iconColor": const Color(0xFFEEE6FF),
      },
      {
        "title": "Delivery",
        "amount": "  ${getField("homeDeliverySales", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.delivery_dining,
        "iconColor": const Color(0xFFFFE6B9),
      },
      {
        "title": "Online",
        "amount": "  ${getField("onlineSales", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.shopping_cart,
        "iconColor": Colors.blue[100],
      },
      {
        "title": "Counter",
        "amount": "  ${getField("counterSales", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.point_of_sale,
        "iconColor": const Color(0xFFF0C987),
      },
      {
        "title": "Net Sales",
        "amount": "  ${getField("netTotal", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.show_chart,
        "iconColor": Colors.orange[100],
      },
      {
        "title": "Discounts",
        "amount": "  ${getField("billDiscount", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.discount,
        "iconColor": Colors.green[100],
      },
      {
        "title": "Taxes",
        "amount": "  ${getField("billTax", fallback: "0.000")}",
        "orders": "",
        "icon": Icons.account_balance,
        "iconColor": Colors.purple[100],
      },
    ];

/*
    if (selectedBrand == null || selectedBrand == "All") {
      list.addAll([
        {
          "title": "Swiggy",
          "amount": "  ${swiggyAmount.toStringAsFixed(3)}",
          "orders": "$swiggyOrders Orders",
          "icon": Icons.online_prediction,
          "isImage": true,
          "iconColor": Colors.orange[200],
        },
        {
          "title": "Zomato",
          "amount": "  ${zomatoAmount.toStringAsFixed(3)}",
          "orders": "$zomatoOrders Orders",
          "icon": Icons.food_bank_outlined,
          "isImage": true,
          "iconColor": Colors.red[200],
        },
      ]);
    }
*/

    return list;
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 12, height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  bool showOutletStatsTable = true;

  Widget _buildOutletwiseStatisticsTable(BuildContext context, {required bool isMobile}) {
    final outlets = <Map<String, String>>[];
    num totalOrders = 0;
    num totalSales = 0;
    num totalNetSales = 0;
    num totalTax = 0;
    num totalDiscount = 0;
    num totalModified = 0;
    num totalReprinted = 0;
    num totalWaivedOff = 0;
    num totalRoundOff = 0;
    num totalCharges = 0;

    widget.dbToBrandMap.forEach((dbKey, outletName) {
      final report = totalSalesResponses[dbKey];
      final outletOrders = num.tryParse(report?.getField("occupiedTableCount", fallback: "0") ?? "0") ?? 0;
      final outletSales = num.tryParse(report?.getField("grandTotal", fallback: "0.000") ?? "0.000") ?? 0;
      final outletNetSales = num.tryParse(report?.getField("netTotal", fallback: "0.000") ?? "0.000") ?? 0;
      final outletTax = num.tryParse(report?.getField("billTax", fallback: "0.000") ?? "0.000") ?? 0;
      final outletDiscount = num.tryParse(report?.getField("billDiscount", fallback: "0.000") ?? "0.000") ?? 0;
      final outletModified = num.tryParse(report?.getField("modifiedCount", fallback: "0") ?? "0") ?? 0;
      final outletReprinted = num.tryParse(report?.getField("reprintCount", fallback: "0") ?? "0") ?? 0;
      final outletWaivedOff = num.tryParse(report?.getField("waivedOff", fallback: "0.000") ?? "0.000") ?? 0;
      final outletRoundOff = num.tryParse(report?.getField("roundOff", fallback: "0.000") ?? "0.000") ?? 0;
      final outletCharges = num.tryParse(report?.getField("charges", fallback: "0.000") ?? "0.000") ?? 0;

      totalOrders += outletOrders;
      totalSales += outletSales;
      totalNetSales += outletNetSales;
      totalTax += outletTax;
      totalDiscount += outletDiscount;
      totalModified += outletModified;
      totalReprinted += outletReprinted;
      totalWaivedOff += outletWaivedOff;
      totalRoundOff += outletRoundOff;
      totalCharges += outletCharges;

      outlets.add({
        "Outlet Name": outletName,
        "Orders": outletOrders.toStringAsFixed(0),
        "Sales": outletSales.toStringAsFixed(3),
        "Net Sales": outletNetSales.toStringAsFixed(3),
        "Tax": outletTax.toStringAsFixed(3),
        "Discount": outletDiscount.toStringAsFixed(3),
        "Modified": outletModified.toStringAsFixed(0),
        "Re-Printed": outletReprinted.toStringAsFixed(0),
        "Waived Off": outletWaivedOff.toStringAsFixed(3),
        "Round Off": outletRoundOff.toStringAsFixed(3),
        "Charges": outletCharges.toStringAsFixed(3),
        "": "",
      });
    });
    outlets.insert(0, {
      "Outlet Name": "Total",
      "Orders": totalOrders.toStringAsFixed(0),
      "Sales": totalSales.toStringAsFixed(3),
      "Net Sales": totalNetSales.toStringAsFixed(3),
      "Tax": totalTax.toStringAsFixed(3),
      "Discount": totalDiscount.toStringAsFixed(3),
      "Modified": totalModified.toStringAsFixed(0),
      "Re-Printed": totalReprinted.toStringAsFixed(0),
      "Waived Off": totalWaivedOff.toStringAsFixed(3),
      "Round Off": totalRoundOff.toStringAsFixed(3),
      "Charges": totalCharges.toStringAsFixed(3),
      "": "",
    });

    final columns = [
      "Outlet Name",
      "Orders",
      "Sales",
      "Net Sales",
      "Tax",
      "Discount",
      "Modified",
      "Re-Printed",
      "Waived Off",
      "Round Off",
      "Charges",
      "",
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Outlet Wise Statistics",
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    showOutletStatsTable ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  tooltip: showOutletStatsTable ? "Collapse" : "Expand",
                  onPressed: () {
                    setState(() {
                      showOutletStatsTable = !showOutletStatsTable;
                    });
                  },
                ),
              ],
            ),
          ),
          if (showOutletStatsTable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: isMobile ? 800 : 1050),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFEAF3FF)),
                  columnSpacing: isMobile ? 12 : 20,
                  headingRowHeight: isMobile ? 38 : 44,
                  dataRowHeight: isMobile ? 38 : 48,
                  showCheckboxColumn: false,
                  columns: columns.map((key) {
                    return DataColumn(
                      label: Row(
                        children: [
                          Text(
                            key,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.normal,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (key != "" && key != "Outlet Name")
                            const Icon(Icons.unfold_more, size: 16, color: Color(0xFFB0BEC5)),
                        ],
                      ),
                    );
                  }).toList(),
                  rows: outlets.map((outlet) {
                    final isTotal = outlet["Outlet Name"] == "Total";
                    return DataRow(
                      cells: columns.map((key) {
                        final isMenu = key == "";
                        final value = outlet[key] ?? '';
                        Widget cellWidget;

                        if (isMenu) {
                          cellWidget = IconButton(
                            icon: const Icon(Icons.more_vert, size: 22, color: Colors.grey),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        } else if (key == "Outlet Name" && value != "Total") {
                          cellWidget = Row(
                            children: [
                              Flexible(
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    fontWeight: isTotal ? FontWeight.normal : FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.open_in_new, size: 16, color: Color(0xFF90A4AE)),
                            ],
                          );
                        } else {
                          cellWidget = Text(
                            value,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: isTotal ? FontWeight.normal : FontWeight.normal,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }

                        return DataCell(
                          Container(
                            width: isMobile ? 90 : 120,
                            child: cellWidget,
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget buildStatsGrid(BuildContext context, List<Map<String, dynamic>> stats) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final crossAxisCount = isMobile ? 2 : 4;
    final aspectRatio = isMobile ? 1.1 : 2.1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: isMobile ? 6 : 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: isMobile ? 8 : 14,
          mainAxisSpacing: isMobile ? 8 : 14,
          childAspectRatio: aspectRatio,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 10 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          stat["title"]!,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.normal,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Icon(stat["icon"], color: stat["iconColor"], size: isMobile ? 20 : 24),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    stat["amount"]!,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((stat["orders"] ?? "").toString().isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: isMobile ? 2 : 4),
                      child: Text(
                        stat["orders"]!,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> exportDashboardExcel() async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Sheet1'];
    final boldStyle = excel.CellStyle(bold: true);

    int rowNum = 0;
    final dateFormat = DateFormat('dd-MM-yyyy');
    final dateRangeText = selectedDateRange != null
        ? "${dateFormat.format(selectedDateRange!.start)} to ${dateFormat.format(selectedDateRange!.end)}"
        : dateFormat.format(DateTime.now());

    // Report Title
    final titleCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
    titleCell.value = "Dashboard Report";
    titleCell.cellStyle = boldStyle;
    rowNum += 1;

    // Date Range
    sheet.appendRow(["Date Range", dateRangeText]);
    rowNum += 1;

    // Outlet(s) Info
    if (selectedBrand == null || selectedBrand == "All") {
      sheet.appendRow(["Outlet(s): All Outlets"]);
    } else {
      sheet.appendRow(["Outlet:", selectedBrand!]);
    }
    rowNum += 1;
    sheet.appendRow([]);
    rowNum += 1;

    // ---- SUMMARY CARDS ----
    sheet.appendRow(["Title", "Amount", "Orders"]);
    for (final card in summaryTabs) {
      sheet.appendRow([
        card["title"] ?? "",
        (card["amount"] ?? "").toString().replaceAll("  ", ""),
        card["orders"] ?? ""
      ]);
    }
    rowNum += summaryTabs.length + 2;

    // ---- ADDITIONAL SUMMARY CARDS (Tax, Discount, Net Sales) ----
    sheet.appendRow(["Title", "Amount"]);
    for (final card in additionalSummaryTabs) {
      sheet.appendRow([
        card["title"] ?? "",
        (card["amount"] ?? "").toString().replaceAll("  ", "")
      ]);
    }
    rowNum += additionalSummaryTabs.length + 2;

    // ---- OUTLETWISE TABLE (only for All Outlets) ----
    if (selectedBrand == null || selectedBrand == "All") {
      sheet.appendRow([]);
      sheet.appendRow([
        "Outlet Name", "Orders", "Sales", "Net Sales", "Tax", "Discount"
      ]);
      widget.dbToBrandMap.forEach((dbKey, outletName) {
        final report = totalSalesResponses[dbKey];
        sheet.appendRow([
          outletName,
          report?.getField("occupiedTableCount", fallback: "0") ?? "0",
          double.tryParse(report?.getField("grandTotal") ?? "0")?.toStringAsFixed(3) ?? "0.000",
          double.tryParse(report?.getField("netTotal") ?? "0")?.toStringAsFixed(3) ?? "0.000",
          double.tryParse(report?.getField("billTax") ?? "0")?.toStringAsFixed(3) ?? "0.000",
          double.tryParse(report?.getField("billDiscount") ?? "0")?.toStringAsFixed(3) ?? "0.000",
        ]);
      });
      rowNum += widget.dbToBrandMap.length + 2;
    }

    sheet.appendRow([]);
    sheet.appendRow(["Online Channel", "Amount", "Orders"]);
    for (final channel in onlineOrderChannels) {
      sheet.appendRow([
        channel["name"] ?? "",
        (channel["amount"] ?? "").toString().replaceAll("  ", ""),
        channel["orders"] ?? ""
      ]);
    }
    rowNum += onlineOrderChannels.length + 2;

    // ---- SAVE FILE ----
    final fileBytes = excelFile.encode();
    final String path = '${Directory.current.path}/DashboardExport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excel exported to $path')));
    }
    // Optionally open the file after export (Windows/Mac/Linux)
    try {
      if (Platform.isWindows) {
        await Process.run('start', [path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

}

class _SalesBarChartWidget extends StatelessWidget {
  final List<ChartBarData> data;
  const _SalesBarChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    if (data.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text("No Data")));
    }

    double maxY = data
        .expand((d) => [d.dineIn, d.takeAway, d.delivery, d.online])
        .fold(0, (a, b) => a > b ? a : b)
        .toDouble();
    maxY = maxY > 0 ? maxY * 1.25 : 100;
    double groupWidth = 150;

    return SizedBox(
      height: 250,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: groupWidth * data.length,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barGroups: List.generate(data.length, (i) {
                final d = data[i];
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: d.dineIn.toDouble(),
                      width: 16,
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.takeAway.toDouble(),
                      width: 16,
                      color: Colors.cyan,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.delivery.toDouble(),
                      width: 16,
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.online.toDouble(),
                      width: 16,
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: d.counter.toDouble(),
                      width: 16,
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                  barsSpace: 6,
                  showingTooltipIndicators: [],
                );
              }),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.black26, width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, meta) {
                      int idx = value.toInt();
                      if (idx < 0 || idx >= data.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[idx].label,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ),
    );
  }
}

class SalesLineChartWidget extends StatelessWidget {
  final List<ChartLineData> data;
  const SalesLineChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    if (data.isEmpty) {
      return const SizedBox(height: 180, child: Center(child: Text("No Data")));
    }

    List<FlSpot> dineSpots = [];
    List<FlSpot> takeAwaySpots = [];
    List<FlSpot> deliverySpots = [];
    List<FlSpot> onlineSpots = [];
    List<FlSpot> counterSpots = [];
    for (int i = 0; i < data.length; i++) {
      dineSpots.add(FlSpot(i.toDouble(), data[i].dineIn.toDouble()));
      takeAwaySpots.add(FlSpot(i.toDouble(), data[i].takeAway.toDouble()));
      deliverySpots.add(FlSpot(i.toDouble(), data[i].delivery.toDouble()));
      onlineSpots.add(FlSpot(i.toDouble(), data[i].online.toDouble()));
      counterSpots.add(FlSpot(i.toDouble(), data[i].counter.toDouble()));
    }

    double maxY = [
      ...dineSpots, ...takeAwaySpots, ...deliverySpots, ...onlineSpots,
    ].map((e) => e.y).fold(0.0, (a, b) => a > b ? a : b);
    if (maxY < 100) maxY = 100;
    int yStep = maxY > 10000 ? 5000 : 1000;
    maxY = (((maxY / yStep).ceil()) * yStep).toDouble();

    double chartWidth = (data.length * 140).toDouble();
    if (chartWidth < MediaQuery.of(context).size.width) {
      chartWidth = MediaQuery.of(context).size.width - 48;
    }

    List<LineChartBarData> lines = [
      if (dineSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: dineSpots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (takeAwaySpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: takeAwaySpots,
          isCurved: true,
          color: Colors.cyan,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (deliverySpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: deliverySpots,
          isCurved: true,
          color: const Color(0xFF63B32D),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (onlineSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: onlineSpots,
          isCurved: true,
          color: Colors.orange,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      if (counterSpots.any((e) => e.y > 0))
        LineChartBarData(
          spots: counterSpots,
          isCurved: true,
          color: Colors.purple,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    if (lines.isEmpty) {
      lines.add(
        LineChartBarData(
          spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), 0)),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return SizedBox(
      height: 320,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: chartWidth,
          child: LineChart(
            LineChartData(
              lineBarsData: lines,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yStep.toDouble(),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: const Color(0xFFE0E0E0),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.black26, width: 1),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yStep.toDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value % yStep != 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          "${(value ~/ 1000)}k",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    getTitlesWidget: (value, meta) {
                      int idx = value.round();
                      if (value != idx.toDouble() || idx < 0 || idx >= data.length) return const SizedBox();
                      String label = data[idx].label;

                      return Transform.rotate(
                        angle: -0.5,
                        child: SizedBox(
                          width: 100,
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (barData, spotIndexes) {
                  return spotIndexes.map((spotIdx) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: Colors.transparent),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, idx) {
                          return FlDotCirclePainter(
                            radius: 8,
                            color: bar.color ?? Colors.blue,
                            strokeWidth: 3,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Colors.white,
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(10),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];
                    final idx = touchedSpots.first.x.toInt();
                    if (idx < 0 || idx >= data.length) return [];
                    final d = data[idx];
                    List<String> lines = [];
                    lines.add('${d.label}');
                    if (d.dineIn > 0) lines.add('Dine In :   ${d.dineIn}');
                    if (d.takeAway > 0) lines.add('TAKE AWAY :   ${d.takeAway}');
                    if (d.delivery > 0) lines.add('Delivery :   ${d.delivery}');
                    if (d.online > 0) lines.add('Online :   ${d.online}');
                    lines.add('Total :   ${d.dineIn + d.takeAway + d.delivery + d.online}');
                    return [
                      LineTooltipItem(
                        lines.join('\n'),
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChartBarData {
  final String label;
  final int dineIn;
  final int takeAway;
  final int delivery;
  final int online;
  final int counter;

  ChartBarData(this.label, this.dineIn, this.takeAway, this.delivery, this.online, this.counter);
}

class ChartLineData {
  final String label;
  final int dineIn;
  final int takeAway;
  final int delivery;
  final int online;
  final int counter;
  ChartLineData(this.label, this.dineIn, this.takeAway, this.delivery, this.online,this.counter);
}


class CalendarDateRangePicker extends StatelessWidget {
  final DateTimeRange initialRange;
  final void Function(DateTimeRange range) onRangeSelected;

  const CalendarDateRangePicker({super.key, required this.initialRange, required this.onRangeSelected});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: 300,
      child: CalendarDatePicker(
        initialDate: initialRange.start,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        onDateChanged: (date) {
        },
      ),
    );
  }
}