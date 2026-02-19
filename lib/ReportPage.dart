import 'dart:io';

import 'package:flutter/material.dart';
import 'package:merchant/AllCancelKotReportPage.dart';
import 'package:merchant/AllMoveKotReportPage.dart';
import 'package:merchant/AllPaxWiseReportPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:merchant/AllBillwiseSalesReportPage.dart';
import 'package:merchant/AllRestaurantSalesReportPage.dart';
import 'package:merchant/AllItemwiseSalesReportPage.dart';
import 'package:merchant/AllTaxwiseSalesReportPage.dart';
import 'package:merchant/AllOnlineCancelOrderWiseReportPage.dart';
import 'package:merchant/AllKOTwiseReportPage.dart';
import 'package:merchant/AllDiscountwiseReportPage.dart';
import 'package:merchant/AllSettlementwiseReportPage.dart';
import 'package:merchant/AllOnlineOrderWiseReportPage.dart';
import 'package:merchant/AllTimeAuditReportPage.dart';
import 'package:merchant/AllCancellationReportPage.dart';
import 'package:merchant/AllItemConsumReportPage.dart';
import 'package:merchant/AllComplimentReportPage.dart';
import 'SidePanel.dart';

class ReportPage extends StatefulWidget {
  final Map<String, String> dbToBrandMap;
  const ReportPage({Key? key, required this.dbToBrandMap}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? selectedBrand = "All";
  String searchQuery = "";

  final List<ReportItem> allReports = [
    ReportItem(
      id: 1,
      name: "All Restaurant Sales Report",
      group: "All Restaurant Report",
      description: "Total combined sales across all outlets",
    ),
    ReportItem(
      id: 2,
      name: "Item wise",
      group: "All Restaurant Report",
      description: "Item sales by outlet in a row-wise format",
    ),
    ReportItem(
      id: 3,
      name: "Billwise",
      group: "All Restaurant Report",
      description: "All outlet invoices listed by bill",
    ),
    ReportItem(
      id: 4,
      name: "Pax Wise",
      group: "All Restaurant Report",
      description: "Guest sales summarized by biller",
    ),
    ReportItem(
      id: 5,
      name: "Tax Wise",
      group: "All Restaurant Report",
      description: "GST overview of sales and returns",
    ),
    ReportItem(
      id: 6,
      name: "OnlineOrder Cancellation ",
      group: "All Restaurant Report",
      description: "Online cancellations with reasons per outlet",
    ),
    ReportItem(
      id: 7,
      name: "KOT Pending ",
      group: "All Restaurant Report",
      description: "List of pending KOTs across outlets",
    ),
    ReportItem(
      id: 8,
      name: "Discount Wise",
      group: "All Restaurant Report",
      description: "Discounts applied by outlet and bill",
    ),
    ReportItem(
      id: 9,
      name: "Settlement Wise ",
      group: "All Restaurant Report",
      description: "Sales breakdown by payment method",
    ),
    ReportItem(
      id: 10,
      name: "Online Order ",
      group: "All Restaurant Report",
      description: "Summary of online order sales",
    ),
    ReportItem(
      id: 11,
      name: "TimeAudit ",
      group: "All Restaurant Report",
      description: "Activity logs with time-based insights",
    ),
    ReportItem(
      id: 12,
      name: "Cancellation Wise",
      group: "All Restaurant Report",
      description: "All cancelled orders with summary",
    ),
    ReportItem(
      id: 13,
      name: "Cancel kot ",
      group: "All Restaurant Report",
      description: "All cancelled KOT with summary",
    ),
    ReportItem(
      id: 14,
      name: "ItemConsumption ",
      group: "All Restaurant Report",
      description: "All ItemConsumption Report",
    ),
    ReportItem(
      id: 15,
      name: "Move Kot ",
      group: "All Restaurant Report",
      description: "All Moved KOT with summary",
    ), ReportItem(
      id: 16,
      name: "Compliment ",
      group: "All Restaurant Report",
      description: "All Complement bills ",
    ),
  ];

  Set<int> favorites = {};
  String selectedReportGroup = "All Restaurant Report";

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];
    setState(() {
      favorites = favList.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites.map((id) => id.toString()).toList());
  }

  void _toggleFavorite(int id) async {
    setState(() {
      if (favorites.contains(id)) {
        favorites.remove(id);
      } else {
        favorites.add(id);
      }
    });
    _saveFavorites();
  }

  @override

  Widget build(BuildContext context) {
    final brandNames = widget.dbToBrandMap.values.toSet();
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isAndroidSideMenuMini = Theme.of(context).platform == TargetPlatform.android && width < height;

    final List<ReportItem> groupReports = allReports
        .where((r) => r.group == selectedReportGroup &&
        (searchQuery.isEmpty ||
            r.name.toLowerCase().contains(searchQuery.toLowerCase())))
        .toList();

    final List<ReportItem> favoriteReports = allReports
        .where((r) => favorites.contains(r.id))
        .where((r) =>
    searchQuery.isEmpty ||
        r.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    final isMobile = width < 600;

    return SidePanel(
      dbToBrandMap: widget.dbToBrandMap,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
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
                  // Brand Dropdown (left, margin 50)
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
                          ...brandNames.map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.normal),
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedBrand = value;
                          });
                        },
                      ),
                    ),
                  ),
                  // Refresh Button (icon only)
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
                    onPressed: () {
                      setState(() {}); // or call a refresh method if needed
                    },
                  ),
                  // Logo (rightmost)

                  if (Platform.isWindows && !isMobile)
                    Padding(
                      padding: const EdgeInsets.only(left: 900, top: 10), // 5cm ≈ 190px
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
        body: LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return Column(
            children: [

              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isAndroidSideMenuMini ? 56 : (isMobile ? 180 : 290),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => setState(() => selectedReportGroup = "Favourite"),
                            child: Container(
                              padding: EdgeInsets.only(
                                  left: isAndroidSideMenuMini ? 0 : 24,
                                  top: 26,
                                  bottom: 12),
                              decoration: BoxDecoration(
                                border: selectedReportGroup == "Favourite"
                                    ? const Border(
                                    left: BorderSide(
                                        color: Color(0xFFD5282B), width: 3))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isAndroidSideMenuMini ? 0 : 0),
                                    child: Icon(Icons.star_border,
                                        color: selectedReportGroup == "Favourite"
                                            ? const Color(0xFFD5282B)
                                            : Colors.black54),
                                  ),
                                  if (!isAndroidSideMenuMini) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      "Favourite",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: selectedReportGroup == "Favourite"
                                            ? const Color(0xFFD5282B)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => selectedReportGroup = "All Restaurant Report"),
                            child: Container(
                              padding: EdgeInsets.only(
                                  left: isAndroidSideMenuMini ? 0 : 24,
                                  top: 8,
                                  bottom: 8),
                              decoration: BoxDecoration(
                                border: selectedReportGroup == "All Restaurant Report"
                                    ? const Border(
                                    left: BorderSide(
                                        color: Color(0xFFD5282B), width: 3))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isAndroidSideMenuMini ? 0 : 0),
                                    child: Icon(Icons.restaurant_menu, color: Colors.black54),
                                  ),
                                  if (!isAndroidSideMenuMini) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      "All Restaurant Report",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: selectedReportGroup == "All Restaurant Report"
                                            ? const Color(0xFFD5282B)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            color: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F8FE),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Search for reports here...",
                                        hintStyle: TextStyle(color: Colors.grey),
                                        prefixIcon:
                                        Icon(Icons.search, size: 20, color: Colors.grey),
                                      ),
                                      onChanged: (value) {
                                        setState(() => searchQuery = value);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    if (selectedReportGroup == "All Restaurant Report" &&
                                        favoriteReports.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4, bottom: 0),
                                              child: Text(
                                                "Favourite",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color: Colors.black87),
                                              ),
                                            ),
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4, bottom: 6),
                                              child: Text(
                                                "All reports which are marked as favorites to refer frequently",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 14,
                                                    color: Colors.black54),
                                              ),
                                            ),
                                            SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Row(
                                                children: favoriteReports
                                                    .map(
                                                      (r) => Container(
                                                    margin:
                                                    const EdgeInsets.only(right: 12),
                                                    width: isMobile ? 350 : 420,
                                                    child: _reportCard(r,
                                                        isFavorite: true, compact: true),
                                                  ),
                                                )
                                                    .toList(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (selectedReportGroup == "All Restaurant Report") ...[
                                      const Padding(
                                        padding:
                                        EdgeInsets.only(top: 8, left: 4, bottom: 7),
                                        child: Text(
                                          "All Restaurant Report",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                              color: Colors.black87),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4, bottom: 18),
                                        child: Text(
                                          "Get insights to all your restaurant & sales related activities",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 15,
                                              color: Colors.black54),
                                        ),
                                      ),
                                      LayoutBuilder(
                                        builder: (context, gridConstraints) {
                                          int crossAxisCount = 2;
                                          double childAspectRatio = 2.6;
                                          double crossAxisSpacing = 18;
                                          double mainAxisSpacing = 17;

                                          if (isMobile) {
                                            crossAxisCount = 1;
                                            childAspectRatio = 2.7;
                                          } else if (gridConstraints.maxWidth < 1200) {
                                            crossAxisCount = 2;
                                            childAspectRatio = 2.4;
                                          } else {
                                            crossAxisCount = 2;
                                            childAspectRatio = 2.8;
                                          }

                                          return Padding(
                                            padding: EdgeInsets.only(
                                              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                                            ),
                                            child: GridView.count(
                                              crossAxisCount: crossAxisCount,
                                              crossAxisSpacing: crossAxisSpacing,
                                              mainAxisSpacing: mainAxisSpacing,
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              childAspectRatio: childAspectRatio,
                                              children: groupReports
                                                  .where((r) => !favorites.contains(r.id))
                                                  .map((r) =>
                                                  _reportCard(r, isFavorite: false))
                                                  .toList(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    if (selectedReportGroup == "Favourite") ...[
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 32),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 32, horizontal: 26),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: favoriteReports.isEmpty
                                            ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.folder_special_outlined,
                                                size: 64, color: Colors.pink[200]),
                                            const SizedBox(height: 16),
                                            const Text(
                                              "There Are No Favorite Report",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                  color: Colors.black87),
                                            ),
                                            const SizedBox(height: 7),
                                            const Text(
                                              "Add Reports to Favorite by selecting the star mark",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 15,
                                                  color: Colors.black54),
                                            ),
                                          ],
                                        )
                                            : Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: favoriteReports
                                              .map((r) => _reportCard(r,
                                              isFavorite: true))
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

// ... (imports and class definitions remain unchanged)

  // Replace _reportCard with the following version:
  Widget _reportCard(ReportItem r, {required bool isFavorite, bool compact = false}) {
    void _navigateToReport() {
      if (r.id == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllRestaurantSalesReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllItemwiseSalesReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 3) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllBillwiseSalesReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 4) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllPaxWiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 5) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllTaxwiseSalesReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 6) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllOnlineCancelOrderWiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 7) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllKOTwiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 8) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllDiscountwiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 9) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllSettlementwiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 10) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllOnlineDaywiseReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 11) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllTimeAuditReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 12) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllCancelBillReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      } if (r.id == 13) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllCancelKotReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
      if (r.id == 14) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllItemConsumReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }if (r.id == 15) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllMoveKotReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }if (r.id == 16) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AllComplimentReportPage(
              dbToBrandMap: widget.dbToBrandMap,
            ),
          ),
        );
      }
    }

    return InkWell(
      onTap: _navigateToReport,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!)),
        margin: const EdgeInsets.all(0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 9 : 16,
            horizontal: compact ? 12 : 18,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 12),
                child: Icon(Icons.receipt_long,
                    color: Colors.pink[200], size: 28),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black87),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              _toggleFavorite(r.id);
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                isFavorite ? Icons.star : Icons.star_border,
                                color: isFavorite
                                    ? const Color(0xFFD5282B)
                                    : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 0),
                        child: Text(
                          r.description,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // ---- Move "View Details" a little higher -----
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 10), // ADDED bottom padding
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD5282B),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                            ),
                            onPressed: _navigateToReport,
                            child: const Text("View Details"),
                          ),
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
    );
  }
}

class ReportItem {
  final int id;
  final String name;
  final String group;
  final String description;

  ReportItem({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
  });
}