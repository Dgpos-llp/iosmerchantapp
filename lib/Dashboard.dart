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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_exporter_stub.dart' if (dart.library.html) 'file_exporter_web.dart' as web_exporter;

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

  // Animation controllers
  bool _isHoveringExport = false;
  bool _isHoveringRefresh = false;

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

  List<PieChartSectionData> get pieChartData {
    List<PieChartSectionData> sections = [];

    if (selectedBrand != null && selectedBrand != "All" && totalSalesResponses.isNotEmpty) {
      final entry = widget.dbToBrandMap.entries.firstWhere(
            (e) => e.value == selectedBrand,
        orElse: () => MapEntry('', ''),
      );
      final dbKey = entry.key.isNotEmpty ? entry.key : null;
      final report = dbKey != null ? totalSalesResponses[dbKey] : null;

      if (report != null) {
        final dineIn = double.tryParse(report.getField("dineInSales", fallback: "0")) ?? 0;
        final takeAway = double.tryParse(report.getField("takeAwaySales", fallback: "0")) ?? 0;
        final delivery = double.tryParse(report.getField("homeDeliverySales", fallback: "0")) ?? 0;
        final online = double.tryParse(report.getField("onlineSales", fallback: "0")) ?? 0;
        final counter = double.tryParse(report.getField("counterSales", fallback: "0")) ?? 0;

        final total = dineIn + takeAway + delivery + online + counter;

        if (total > 0) {
          if (dineIn > 0) {
            sections.add(
              PieChartSectionData(
                value: dineIn,
                title: '${((dineIn / total) * 100).toStringAsFixed(1)}%',
                color: Colors.blue,
                radius: 80,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }
          if (takeAway > 0) {
            sections.add(
              PieChartSectionData(
                value: takeAway,
                title: '${((takeAway / total) * 100).toStringAsFixed(1)}%',
                color: Colors.cyan,
                radius: 80,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }
          if (delivery > 0) {
            sections.add(
              PieChartSectionData(
                value: delivery,
                title: '${((delivery / total) * 100).toStringAsFixed(1)}%',
                color: Colors.green,
                radius: 80,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }
          if (online > 0) {
            sections.add(
              PieChartSectionData(
                value: online,
                title: '${((online / total) * 100).toStringAsFixed(1)}%',
                color: Colors.orange,
                radius: 80,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }
          if (counter > 0) {
            sections.add(
              PieChartSectionData(
                value: counter,
                title: '${((counter / total) * 100).toStringAsFixed(1)}%',
                color: Colors.purple,
                radius: 80,
                titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            );
          }
        }
      }
    }

    return sections;
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
          "icon": Icons.trending_up,
          "iconColor": Color(0xFF4154F1),
          "gradient": [const Color(0xFF4154F1), const Color(0xFF6B7AF5)],
        },
        {
          "title": "Dine In",
          "amount": formatAmount(dineIn),
          "orders": formatOrders(dineOrders),
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF2D9CDB),
          "gradient": [const Color(0xFF2D9CDB), const Color(0xFF5DADE2)],
        },
        {
          "title": "Take Away",
          "amount": formatAmount(takeAway),
          "orders": formatOrders(takeAwayOrders),
          "icon": Icons.takeout_dining,
          "iconColor": Color(0xFF9B51E0),
          "gradient": [const Color(0xFF9B51E0), const Color(0xFFBB6BD9)],
        },
        {
          "title": "Delivery",
          "amount": formatAmount(delivery),
          "orders": formatOrders(deliveryOrders),
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFF2994A),
          "gradient": [const Color(0xFFF2994A), const Color(0xFFF7B731)],
        },
        {
          "title": "Counter",
          "amount": formatAmount(counter),
          "orders": formatOrders(counterOrders),
          "icon": Icons.point_of_sale,
          "iconColor": Color(0xFF27AE60),
          "gradient": [const Color(0xFF27AE60), const Color(0xFF6FCF97)],
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
          "orders" : "",
          "icon": Icons.trending_up,
          "iconColor": Color(0xFF4154F1),
          "gradient": [const Color(0xFF4154F1), const Color(0xFF6B7AF5)],
        },
        {
          "title": "Dine In",
          "amount": safeAmount(report?.getField("dineInSales")),
          "orders" : "",
          "icon": Icons.restaurant,
          "iconColor": Color(0xFF2D9CDB),
          "gradient": [const Color(0xFF2D9CDB), const Color(0xFF5DADE2)],
        },
        {
          "title": "Take Away",
          "amount": safeAmount(report?.getField("takeAwaySales")),
          "orders" : "",
          "icon": Icons.takeout_dining,
          "iconColor": Color(0xFF9B51E0),
          "gradient": [const Color(0xFF9B51E0), const Color(0xFFBB6BD9)],
        },
        {
          "title": "Delivery",
          "amount": safeAmount(report?.getField("homeDeliverySales")),
          "orders" : "",
          "icon": Icons.delivery_dining,
          "iconColor": Color(0xFFF2994A),
          "gradient": [const Color(0xFFF2994A), const Color(0xFFF7B731)],
        },
        {
          "title": "Counter",
          "amount": safeAmount(report?.getField("counterSales")),
          "orders" : "",
          "icon": Icons.point_of_sale,
          "iconColor": Color(0xFF27AE60),
          "gradient": [const Color(0xFF27AE60), const Color(0xFF6FCF97)],
        },
      ];
    }
  }

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
          "iconColor": Color(0xFFE67E22),
          "gradient": [const Color(0xFFE67E22), const Color(0xFFF39C12)],
        },
        {
          "title": "Discounts",
          "amount": formatAmount(discount),
          "orders": "",
          "icon": Icons.discount,
          "iconColor": Color(0xFFE74C3C),
          "gradient": [const Color(0xFFE74C3C), const Color(0xFFE67E22)],
        },
        {
          "title": "Taxes",
          "amount": formatAmount(tax),
          "orders": "",
          "icon": Icons.account_balance,
          "iconColor": Color(0xFF8E44AD),
          "gradient": [const Color(0xFF8E44AD), const Color(0xFF9B59B6)],
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
          "iconColor": Color(0xFFE67E22),
          "gradient": [const Color(0xFFE67E22), const Color(0xFFF39C12)],
        },
        {
          "title": "Discounts",
          "amount": safeAmount(report?.getField("billDiscount")),
          "orders": "",
          "icon": Icons.discount,
          "iconColor": Color(0xFFE74C3C),
          "gradient": [const Color(0xFFE74C3C), const Color(0xFFE67E22)],
        },
        {
          "title": "Taxes",
          "amount": safeAmount(report?.getField("billTax", fallback: "0.000")),
          "orders": "",
          "icon": Icons.account_balance,
          "iconColor": Color(0xFF8E44AD),
          "gradient": [const Color(0xFF8E44AD), const Color(0xFF9B59B6)],
        },
      ];
    }
  }

  List<Map<String, dynamic>> get onlineOrderChannels {
    double onlineAmount = double.tryParse(settlementAmounts["Online"]?.toString() ?? '0') ?? 0;

    List<Map<String, dynamic>> channels = [];

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
      const Color(0xFF4154F1), const Color(0xFF2D9CDB), const Color(0xFF9B51E0),
      const Color(0xFFF2994A), const Color(0xFF27AE60), const Color(0xFFE74C3C),
      const Color(0xFF8E44AD), const Color(0xFF3498DB), const Color(0xFF1ABC9C),
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
  @override
  Widget build(BuildContext context) {
    final onlineTotals = onlineOrderTotals;
    final brandNames = widget.dbToBrandMap.values.toSet();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;

    // Use a smaller threshold for the header overlap specifically
    final bool isHeaderMobile = size.width < 700;
    // Keep your original logic for the body layout
    final bool isMobile = size.width < 1100;

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 70,
          automaticallyImplyLeading: false,
          // FIX 1: Forces the title to absolute center, ignoring leading/action widths
          centerTitle: true,
          title: const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C3E50),
            ),
          ),
          // FIX 2: Increased leadingWidth to accommodate both the sidebar toggle and selector
          leadingWidth: isHeaderMobile ? 80 : 380,
          leading: isHeaderMobile ? null : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FIX 3: 70px spacer provides clear room for the SidePanel menu button
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
                      value: selectedBrand,
                      hint: const Text(
                          "All Outlets",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF7F8C8D)),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                            value: "All",
                            child: Text("All Outlets", style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50)))
                        ),
                        ...brandNames.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                                brand,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))
                            )
                        )),
                      ],
                      onChanged: (value) async {
                        setState(() => selectedBrand = value);
                        await fetchTotalSales();
                        await fetchTimeslotSales();
                        await fetchOnlineOrders();
                      },
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                      widget.dbToBrandMap.values.first,
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))
                  ),
                ),
            ],
          ),
          actions: [
            if (!isHeaderMobile) ...[
              _buildActionButton(
                icon: Icons.download,
                label: "Export",
                onPressed: exportDashboardExcel,
                isHovering: _isHoveringExport,
                onHover: (value) => setState(() => _isHoveringExport = value),
              ),
              const SizedBox(width: 12),
            ],
            _buildDateRangeSelector(),
            const SizedBox(width: 12),
            _buildIconButton(
              icon: Icons.refresh,
              onPressed: () async {
                await fetchTotalSales();
                await fetchTimeslotSales();
                await fetchOnlineOrders();
              },
              isHovering: _isHoveringRefresh,
              onHover: (value) => setState(() => _isHoveringRefresh = value),
            ),
            const SizedBox(width: 16),
          ],
          bottom: isHeaderMobile
              ? PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBrand,
                          hint: const Text("All Outlets", overflow: TextOverflow.ellipsis),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: "All", child: Text("All Outlets")),
                            ...brandNames.map((brand) => DropdownMenuItem(
                                value: brand,
                                child: Text(brand, overflow: TextOverflow.ellipsis)
                            )),
                          ],
                          onChanged: (value) async {
                            setState(() => selectedBrand = value);
                            await fetchTotalSales();
                            await fetchTimeslotSales();
                            await fetchOnlineOrders();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildActionButton(
                    icon: Icons.download,
                    label: "Export",
                    onPressed: exportDashboardExcel,
                    isHovering: _isHoveringExport,
                    onHover: (value) => setState(() => _isHoveringExport = value),
                  ),
                ],
              ),
            ),
          )
              : null,
        ),
        body: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4154F1)),
          ),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: size.width < 600 ? 16 : 24,
                right: size.width < 600 ? 16 : 24,
                bottom: size.width < 600 ? 16 : 24,
                top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasOnlyOneDb || (selectedBrand != null && selectedBrand != "All")) ...[
                    _buildStatsGrid(context),
                    const SizedBox(height: 24),
                    if (isMobile) ...[
                      _buildPieChartSection(true),
                      const SizedBox(height: 24),
                      _buildChartSection(true),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: _buildPieChartSection(false)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildChartSection(false)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isMobile) ...[
                      _buildOnlineOrdersSection(true, onlineTotals),
                      const SizedBox(height: 24),
                      _buildPaymentBifurcationSection(true),
                    ] else ...[
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildOnlineOrdersSection(false, onlineTotals)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildPaymentBifurcationSection(false)),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (selectedBrand == null || selectedBrand == "All") ...[
                    _buildStatsGrid(context),
                    const SizedBox(height: 24),
                    _buildOutletwiseStatisticsTable(context, isMobile: size.width < 600),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isHovering,
    required Function(bool) onHover,
  }) {
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: isHovering ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
        child: OutlinedButton.icon(
          icon: Icon(icon, color: isHovering ? Colors.white : const Color(0xFF4154F1)),
          label: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isHovering ? Colors.white : const Color(0xFF4154F1),
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: isHovering ? const Color(0xFF4154F1) : Colors.white,
            side: BorderSide(
              color: isHovering ? const Color(0xFF4154F1) : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: onPressed,
        ),
      ),
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

  Widget _buildDateRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  fontWeight: FontWeight.w500,
                  color: quickDateLabel == label ? const Color(0xFF4154F1) : const Color(0xFF2C3E50),
                ),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 18, color: const Color(0xFF7F8C8D)),
              const SizedBox(width: 8),
              Text(
                quickDateLabel == "Custom Range" && selectedQuickDateRange != null
                    ? "${DateFormat('dd MMM').format(selectedQuickDateRange!.start)} - ${DateFormat('dd MMM').format(selectedQuickDateRange!.end)}"
                    : quickDateLabel == "Today"
                    ? DateFormat('dd MMM').format(DateTime.now())
                    : quickDateLabel,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF7F8C8D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isMobile) {
    final tabs = summaryTabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Container(
            width: isMobile ? 200 : 240,
            margin: EdgeInsets.only(right: isMobile ? 12 : 20),
            child: _buildModernCard(
              title: tab["title"],
              amount: (tab["amount"] as String).replaceAll("  ", ""),
              orders: tab["orders"],
              icon: tab["icon"],
              gradientColors: tab["gradient"] as List<Color>,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAdditionalSummaryCards(bool isMobile) {
    final tabs = additionalSummaryTabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          return Container(
            width: isMobile ? 200 : 240,
            margin: EdgeInsets.only(right: isMobile ? 12 : 20),
            child: _buildModernCard(
              title: tab["title"],
              amount: (tab["amount"] as String).replaceAll("  ", ""),
              orders: tab["orders"],
              icon: tab["icon"],
              gradientColors: tab["gradient"] as List<Color>,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildModernCard({
    required String title,
    required String amount,
    required String orders,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15), // Reduced padding to save space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distributes space evenly
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: Colors.white.withOpacity(0.5), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            // Use FittedBox to prevent the "22 pixel overflow"
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22, // Slightly smaller base size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (orders.isNotEmpty)
              Text(
                orders,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(bool isMobile) {
    return Container(
      height: 420, // Match with pie chart card height
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Sales Overview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: chartType,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
                      borderRadius: BorderRadius.circular(8),
                      isDense: true,
                      items: [
                        DropdownMenuItem(
                          value: "Bar Chart",
                          child: Row(
                            children: const [
                              Icon(Icons.bar_chart, size: 16, color: Color(0xFF7F8C8D)),
                              SizedBox(width: 4),
                              Text("Bar Chart"),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: "Line Chart",
                          child: Row(
                            children: const [
                              Icon(Icons.show_chart, size: 16, color: Color(0xFF7F8C8D)),
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
              ],
            ),
            const SizedBox(height: 16),
            _buildLegend(),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isLoadingTimeslotSales
                    ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4154F1)),
                  ),
                )
                    : (chartType == "Bar Chart"
                    ? _SalesBarChartWidget(data: barData, key: chartKey)
                    : SalesLineChartWidget(data: lineData, key: chartKey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(bool isMobile) {
    final pieData = pieChartData;
    // REMOVED: if (pieData.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sales Distribution",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: pieData.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      "No Sales Data Available",
                      style: TextStyle(color: Color(0xFF95A5A6), fontSize: 14),
                    ),
                  ],
                ),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sections: pieData,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildPieLegendItem("Dine In", Colors.blue),
                      _buildPieLegendItem("Take Away", Colors.cyan),
                      _buildPieLegendItem("Delivery", Colors.green),
                      _buildPieLegendItem("Online", Colors.orange),
                      _buildPieLegendItem("Counter", Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [_legendDot(Colors.blue), const SizedBox(width: 4), const Text("Dine In", style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)))]),
        Row(mainAxisSize: MainAxisSize.min, children: [_legendDot(Colors.cyan), const SizedBox(width: 4), const Text("Take Away", style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)))]),
        Row(mainAxisSize: MainAxisSize.min, children: [_legendDot(Colors.green), const SizedBox(width: 4), const Text("Delivery", style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)))]),
        Row(mainAxisSize: MainAxisSize.min, children: [_legendDot(Colors.orange), const SizedBox(width: 4), const Text("Online", style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)))]),
        Row(mainAxisSize: MainAxisSize.min, children: [_legendDot(Colors.purple), const SizedBox(width: 4), const Text("Counter", style: TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)))]),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildOnlineOrdersSection(bool isMobile, Map<String, dynamic> onlineTotals) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Online Orders",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatItem(
                          label: "Total Sales",
                          value: onlineTotals['amount'].toStringAsFixed(3)
                      ),
                      const SizedBox(height: 12),
                      _buildStatItem(
                          label: "Total Orders",
                          value: "${onlineTotals['orders']}"
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onlineOrderChannels.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: _buildCompactChannelCard(onlineOrderChannels.first),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChannelCard(Map<String, dynamic> channel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: channel["active"] ? const Color(0xFF4154F1) : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4154F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                // FIX 1: errorBuilder prevents the big red "Unable to load asset" box
                child: Image.asset(
                  channel["icon"],
                  width: 18,
                  height: 18,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.shopping_bag, size: 18, color: Color(0xFF4154F1)),
                ),
              ),
              const SizedBox(width: 6),
              // FIX 2: Flexible + Overflow prevents the right-side push
              Flexible(
                child: Text(
                  channel["name"],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // FIX 3: FittedBox shrinks the text size if the number is too long
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              channel["amount"].toString().trim(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7F8C8D),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBifurcationSection(bool isMobile) {
    final payments = paymentBifurcation; // Get the list of payment data

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Payment Bifurcation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            if (payments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.payments_outlined, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text(
                        "No Payment Data",
                        style: TextStyle(color: Color(0xFF95A5A6), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildPaymentProgressBar(isMobile),
              const SizedBox(height: 16),
              ...payments.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildPaymentItem(p),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentProgressBar(bool isMobile) {
    final payments = paymentBifurcation;
    if (payments.isEmpty) return const SizedBox.shrink();

    double totalWidth = isMobile ? 280 : 350;
    double barHeight = 24;

    // Extract values safely
    List<double> values = payments
        .map((p) => double.tryParse(p["value"].toString().replaceAll(" ", "").replaceAll(",", "").trim()) ?? 0)
        .toList();

    double total = values.fold(0.0, (a, b) => a + b);

    return Center(
      child: Container(
        width: totalWidth,
        height: barHeight,
        clipBehavior: Clip.antiAlias, // Ensures clean rounded corners for the segments
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barHeight / 2),
          color: const Color(0xFFF5F7FA),
        ),
        child: total == 0
            ? Container(color: Colors.grey[200]) // Show grey bar if amounts are all 0
            : Row(
          children: List.generate(payments.length, (i) {
            double segmentWidth = totalWidth * (values[i] / total);
            if (segmentWidth <= 0) return const SizedBox.shrink();

            return Container(
              width: segmentWidth,
              height: barHeight,
              color: payments[i]["color"],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: payment["color"],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              payment["label"],
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            payment["value"].toString().replaceAll("  ", ""),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;

    // Define horizontal padding based on Scaffold padding
    double padding = screenWidth < 600 ? 32 : 48;
    double availableWidth = screenWidth - padding;

    // Determine columns and height based on screen size
    int crossAxisCount;
    double targetHeight;

    if (screenWidth < 600) {
      crossAxisCount = 2; // Mobile
      targetHeight = 110;
    } else if (screenWidth < 1200) {
      crossAxisCount = 4; // Tablet/Small Desktop
      targetHeight = 120;
    } else {
      crossAxisCount = 5; // Large Desktop - Fits "Counter" in one row
      targetHeight = 130; // Increased height to prevent vertical overflow
    }

    // Calculate dynamic aspect ratio: Width / Height
    double cardWidth = (availableWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;
    double childAspectRatio = cardWidth / targetHeight;

    final List<List<Color>> gradientColors = [
      [const Color(0xFF4154F1), const Color(0xFF6B7AF5)],
      [const Color(0xFF2D9CDB), const Color(0xFF5DADE2)],
      [const Color(0xFF9B51E0), const Color(0xFFBB6BD9)],
      [const Color(0xFFF2994A), const Color(0xFFF7B731)],
      [const Color(0xFF27AE60), const Color(0xFF6FCF97)],
      [const Color(0xFFE67E22), const Color(0xFFF39C12)],
      [const Color(0xFFE74C3C), const Color(0xFFE67E22)],
      [const Color(0xFF8E44AD), const Color(0xFF9B59B6)],
      [const Color(0xFF3498DB), const Color(0xFF5DADE2)],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildModernCard(
          title: stat["title"]!,
          amount: (stat["amount"] as String).replaceAll("  ", ""),
          orders: stat["orders"] ?? "",
          icon: stat["icon"],
          gradientColors: gradientColors[index % gradientColors.length],
        );
      },
    );
  }
  List<Map<String, dynamic>> get stats {
    return [
      {"title": "Total Sales", "amount": "  ${getField("grandTotal", fallback: "0.000")}", "orders": "", "icon": Icons.trending_up},
      {"title": "Dine In", "amount": "  ${getField("dineInSales", fallback: "0.000")}", "orders": "", "icon": Icons.restaurant},
      {"title": "Take Away", "amount": "  ${getField("takeAwaySales", fallback: "0.000")}", "orders": "", "icon": Icons.takeout_dining},
      {"title": "Delivery", "amount": "  ${getField("homeDeliverySales", fallback: "0.000")}", "orders": "", "icon": Icons.delivery_dining},
      {"title": "Online", "amount": "  ${getField("onlineSales", fallback: "0.000")}", "orders": "", "icon": Icons.shopping_cart},
      {"title": "Counter", "amount": "  ${getField("counterSales", fallback: "0.000")}", "orders": "", "icon": Icons.point_of_sale},
      {"title": "Net Sales", "amount": "  ${getField("netTotal", fallback: "0.000")}", "orders": "", "icon": Icons.show_chart},
      {"title": "Discounts", "amount": "  ${getField("billDiscount", fallback: "0.000")}", "orders": "", "icon": Icons.discount},
      {"title": "Taxes", "amount": "  ${getField("billTax", fallback: "0.000")}", "orders": "", "icon": Icons.account_balance},
    ];
  }

  bool showOutletStatsTable = true;

  Widget _buildOutletwiseStatisticsTable(BuildContext context, {required bool isMobile}) {
    final outlets = <Map<String, String>>[];
    num totalOrders = 0, totalSales = 0, totalNetSales = 0, totalTax = 0,
        totalDiscount = 0, totalModified = 0, totalReprinted = 0,
        totalWaivedOff = 0, totalRoundOff = 0, totalCharges = 0;

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
    });

    final columns = ["Outlet Name", "Orders", "Sales", "Net Sales", "Tax", "Discount", "Modified", "Re-Printed", "Waived Off", "Round Off", "Charges"];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Expanded(child: Text("Outlet Wise Statistics", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF2C3E50)))),
                IconButton(
                  icon: Icon(showOutletStatsTable ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF7F8C8D)),
                  onPressed: () => setState(() => showOutletStatsTable = !showOutletStatsTable),
                ),
              ],
            ),
          ),
          if (showOutletStatsTable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 48),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
                  columnSpacing: 24,
                  horizontalMargin: 20,
                  columns: columns.map((key) => DataColumn(label: Text(key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))))).toList(),
                  rows: outlets.map((outlet) {
                    final isTotal = outlet["Outlet Name"] == "Total";
                    return DataRow(
                      color: isTotal ? MaterialStateProperty.all(const Color(0xFFF0F2FF)) : null,
                      cells: columns.map((key) => DataCell(Text(outlet[key] ?? '', style: TextStyle(fontSize: 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.w400, color: isTotal ? const Color(0xFF4154F1) : const Color(0xFF2C3E50))))).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
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

    final titleCell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowNum));
    titleCell.value = "Dashboard Report";
    titleCell.cellStyle = boldStyle;
    rowNum += 1;

    sheet.appendRow(["Date Range", dateRangeText]);
    rowNum += 1;

    if (selectedBrand == null || selectedBrand == "All") {
      sheet.appendRow(["Outlet(s): All Outlets"]);
    } else {
      sheet.appendRow(["Outlet:", selectedBrand!]);
    }
    rowNum += 1;
    sheet.appendRow([]);
    rowNum += 1;

    sheet.appendRow(["Title", "Amount", "Orders"]);
    for (final card in summaryTabs) {
      sheet.appendRow([card["title"] ?? "", (card["amount"] ?? "").toString().replaceAll("  ", ""), card["orders"] ?? ""]);
    }
    rowNum += summaryTabs.length + 2;

    sheet.appendRow(["Title", "Amount"]);
    for (final card in additionalSummaryTabs) {
      sheet.appendRow([card["title"] ?? "", (card["amount"] ?? "").toString().replaceAll("  ", "")]);
    }
    rowNum += additionalSummaryTabs.length + 2;

    if (selectedBrand == null || selectedBrand == "All") {
      sheet.appendRow([]);
      sheet.appendRow(["Outlet Name", "Orders", "Sales", "Net Sales", "Tax", "Discount"]);
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
      sheet.appendRow([channel["name"] ?? "", (channel["amount"] ?? "").toString().replaceAll("  ", ""), channel["orders"] ?? ""]);
    }
    rowNum += onlineOrderChannels.length + 2;

    final fileBytes = excelFile.encode();

    if (kIsWeb) {
      web_exporter.saveFileWeb(fileBytes!, 'DashBoard.xlsx');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Excel downloaded successfully'),
                backgroundColor: const Color(0xFF27AE60),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            )
        );
      }
    } else {
      // DESKTOP (Windows, Mac, Linux) AND ANDROID
      final String path = '${Directory.current.path}/DashboardExport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final file = File(path);
      await file.writeAsBytes(fileBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Excel exported to $path'),
                backgroundColor: const Color(0xFF27AE60),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
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
}

class _SalesBarChartWidget extends StatelessWidget {
  final List<ChartBarData> data;
  const _SalesBarChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text("No Data Available", style: TextStyle(color: Color(0xFF95A5A6), fontSize: 14)));
    double maxY = data.expand((d) => [d.dineIn, d.takeAway, d.delivery, d.online, d.counter]).fold(0, (a, b) => a > b ? a : b).toDouble();
    maxY = maxY > 0 ? maxY * 1.25 : 100;
    double groupWidth = 150;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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
                  BarChartRodData(toY: d.dineIn.toDouble(), width: 16, color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: d.takeAway.toDouble(), width: 16, color: Colors.cyan, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: d.delivery.toDouble(), width: 16, color: Colors.green, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: d.online.toDouble(), width: 16, color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: d.counter.toDouble(), width: 16, color: Colors.purple, borderRadius: BorderRadius.circular(4)),
                ],
                barsSpace: 8,
              );
            }),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1))),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (double value, meta) {
                int idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(data[idx].label, style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)), overflow: TextOverflow.ellipsis));
              })),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            barTouchData: BarTouchData(enabled: false),
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
    if (data.isEmpty) return const Center(child: Text("No Data Available", style: TextStyle(color: Color(0xFF95A5A6), fontSize: 14)));
    List<FlSpot> dineSpots = [], takeAwaySpots = [], deliverySpots = [], onlineSpots = [], counterSpots = [];
    for (int i = 0; i < data.length; i++) {
      dineSpots.add(FlSpot(i.toDouble(), data[i].dineIn.toDouble()));
      takeAwaySpots.add(FlSpot(i.toDouble(), data[i].takeAway.toDouble()));
      deliverySpots.add(FlSpot(i.toDouble(), data[i].delivery.toDouble()));
      onlineSpots.add(FlSpot(i.toDouble(), data[i].online.toDouble()));
      counterSpots.add(FlSpot(i.toDouble(), data[i].counter.toDouble()));
    }
    double maxY = [...dineSpots, ...takeAwaySpots, ...deliverySpots, ...onlineSpots, ...counterSpots].map((e) => e.y).fold(0.0, (a, b) => a > b ? a : b);
    if (maxY < 100) maxY = 100;
    int yStep = maxY > 10000 ? 5000 : 1000;
    maxY = (((maxY / yStep).ceil()) * yStep).toDouble();
    double chartWidth = max((data.length * 140).toDouble(), MediaQuery.of(context).size.width - 48);

    List<LineChartBarData> lines = [
      if (dineSpots.any((e) => e.y > 0)) LineChartBarData(spots: dineSpots, isCurved: true, color: Colors.blue, barWidth: 3, dotData: const FlDotData(show: false)),
      if (takeAwaySpots.any((e) => e.y > 0)) LineChartBarData(spots: takeAwaySpots, isCurved: true, color: Colors.cyan, barWidth: 3, dotData: const FlDotData(show: false)),
      if (deliverySpots.any((e) => e.y > 0)) LineChartBarData(spots: deliverySpots, isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: false)),
      if (onlineSpots.any((e) => e.y > 0)) LineChartBarData(spots: onlineSpots, isCurved: true, color: Colors.orange, barWidth: 3, dotData: const FlDotData(show: false)),
      if (counterSpots.any((e) => e.y > 0)) LineChartBarData(spots: counterSpots, isCurved: true, color: Colors.purple, barWidth: 3, dotData: const FlDotData(show: false)),
    ];
    if (lines.isEmpty) lines.add(LineChartBarData(spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), 0)), isCurved: true, color: Colors.blue, barWidth: 3));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: chartWidth,
        child: LineChart(
          LineChartData(
            lineBarsData: lines,
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: yStep.toDouble(), getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
            borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1))),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, interval: yStep.toDouble(), getTitlesWidget: (value, meta) {
                if (value % yStep != 0) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(right: 8.0), child: Text("${(value ~/ 1000)}k", style: const TextStyle(fontSize: 12, color: Color(0xFF95A5A6))));
              })),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (value, meta) {
                int idx = value.round();
                if (value != idx.toDouble() || idx < 0 || idx >= data.length) return const SizedBox();
                return Transform.rotate(angle: -0.5, child: Container(width: 100, padding: const EdgeInsets.only(left: 8), child: Text(data[idx].label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.left, style: const TextStyle(fontSize: 11, color: Color(0xFF95A5A6)))));
              })),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(enabled: true, handleBuiltInTouches: true),
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
  ChartLineData(this.label, this.dineIn, this.takeAway, this.delivery, this.online, this.counter);
}