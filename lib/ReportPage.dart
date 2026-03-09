//no change
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- SUB-PAGE IMPORTS (Preserved) ---
import 'package:merchant/AllCancelKotReportPage.dart';
import 'package:merchant/AllMoveKotReportPage.dart';
import 'package:merchant/AllPaxWiseReportPage.dart';
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
  Set<int> favorites = {};
  String selectedReportGroup = "All Restaurant Report";
  final Color primaryColor = const Color(0xFF4154F1);

  final List<ReportItem> allReports = [
    ReportItem(id: 1, name: "All Restaurant Sales Report", group: "All Restaurant Report", description: "Total combined sales across all outlets"),
    ReportItem(id: 2, name: "Item wise", group: "All Restaurant Report", description: "Item sales by outlet in a row-wise format"),
    ReportItem(id: 3, name: "Billwise", group: "All Restaurant Report", description: "All outlet invoices listed by bill"),
    ReportItem(id: 4, name: "Pax Wise", group: "All Restaurant Report", description: "Guest sales summarized by biller"),
    ReportItem(id: 5, name: "Tax Wise", group: "All Restaurant Report", description: "GST overview of sales and returns"),
    ReportItem(id: 6, name: "OnlineOrder Cancellation ", group: "All Restaurant Report", description: "Online cancellations with reasons per outlet"),
    ReportItem(id: 7, name: "KOT Pending ", group: "All Restaurant Report", description: "List of pending KOTs across outlets"),
    ReportItem(id: 8, name: "Discount Wise", group: "All Restaurant Report", description: "Discounts applied by outlet and bill"),
    ReportItem(id: 9, name: "Settlement Wise ", group: "All Restaurant Report", description: "Sales breakdown by payment method"),
    ReportItem(id: 10, name: "Online Order ", group: "All Restaurant Report", description: "Summary of online order sales"),
    ReportItem(id: 11, name: "TimeAudit ", group: "All Restaurant Report", description: "Activity logs with time-based insights"),
    ReportItem(id: 12, name: "Cancellation Wise", group: "All Restaurant Report", description: "All cancelled orders with summary"),
    ReportItem(id: 13, name: "Cancel kot ", group: "All Restaurant Report", description: "All cancelled KOT with summary"),
    ReportItem(id: 14, name: "ItemConsumption ", group: "All Restaurant Report", description: "All ItemConsumption Report"),
    ReportItem(id: 15, name: "Move Kot ", group: "All Restaurant Report", description: "All Moved KOT with summary"),
    ReportItem(id: 16, name: "Compliment ", group: "All Restaurant Report", description: "All Complement bills "),
  ];

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

  void _toggleFavorite(int id) {
    setState(() {
      if (favorites.contains(id)) favorites.remove(id);
      else favorites.add(id);
    });
    _saveFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;
    final brandNames = widget.dbToBrandMap.values.toSet();

    final List<ReportItem> favoriteReports = allReports
        .where((r) => favorites.contains(r.id) && (searchQuery.isEmpty || r.name.toLowerCase().contains(searchQuery.toLowerCase())))
        .toList();

    final List<ReportItem> groupReports = allReports
        .where((r) => r.group == "All Restaurant Report" && (searchQuery.isEmpty || r.name.toLowerCase().contains(searchQuery.toLowerCase())))
        .toList();

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
          title: const Text("Analytics Reports", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          leadingWidth: isMobile ? 80 : 380,
          leading: isMobile ? null : _buildDesktopSelector(brandNames),
          actions: [
            _buildIconButton(Icons.refresh, () => setState(() {})),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            _buildCategoryTabs(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSearchField(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _buildMainContent(favoriteReports, groupReports, isMobile),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(List<ReportItem> favs, List<ReportItem> group, bool isMobile) {
    if (selectedReportGroup == "Favourite" && favs.isEmpty) {
      return _buildEmptyFavoriteState();
    }

    final displayedList = selectedReportGroup == "Favourite" ? favs : group;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedReportGroup == "All Restaurant Report" && favs.isNotEmpty && searchQuery.isEmpty) ...[
            _buildSectionHeader("Favorites", "Quick access"),
            const SizedBox(height: 16),
            _buildReportGrid(favs, isMobile),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader(selectedReportGroup, "Detailed data insights"),
          const SizedBox(height: 16),
          _buildReportGrid(displayedList, isMobile),
        ],
      ),
    );
  }

  Widget _buildReportGrid(List<ReportItem> reports, bool isMobile) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) => ReportTile(
        report: reports[index],
        isFavorite: favorites.contains(reports[index].id),
        onToggleFavorite: () => _toggleFavorite(reports[index].id),
        onTap: () => _navigateToReport(reports[index]),
        primaryColor: primaryColor,
      ),
    );
  }

  Widget _buildDesktopSelector(Set<String> brandNames) {
    return Row(children: [
      const SizedBox(width: 70),
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
              ...brandNames.map((b) => DropdownMenuItem(value: b, child: Text(b)))
            ],
            onChanged: (v) => setState(() => selectedBrand = v),
          ),
        ),
      ),
    ]);
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, color: const Color(0xFF7F8C8D), size: 20), onPressed: onTap),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Row(
        children: [
          _tabItem("All Restaurant Report", Icons.restaurant_menu),
          _tabItem("Favourite", Icons.star_rounded),
        ],
      ),
    );
  }

  Widget _tabItem(String title, IconData icon) {
    bool isSelected = selectedReportGroup == title;
    return InkWell(
      onTap: () => setState(() { selectedReportGroup = title; }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? primaryColor : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? primaryColor : const Color(0xFF7F8C8D)),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: isSelected ? primaryColor : const Color(0xFF7F8C8D), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: const InputDecoration(
          hintText: "Search for reports...",
          prefixIcon: Icon(Icons.search, color: Color(0xFF7F8C8D), size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D))),
      ],
    );
  }

  Widget _buildEmptyFavoriteState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded, size: 60, color: const Color(0xFFBDBDBD).withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text("No Favorites Yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF7F8C8D))),
          const SizedBox(height: 4),
          const Text("Mark reports with a star to see them here.", style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
        ],
      ),
    );
  }

  void _navigateToReport(ReportItem r) {
    Widget? page;
    switch (r.id) {
      case 1: page = AllRestaurantSalesReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 2: page = AllItemwiseSalesReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 3: page = AllBillwiseSalesReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 4: page = AllPaxWiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 5: page = AllTaxwiseSalesReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 6: page = AllOnlineCancelOrderWiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 7: page = AllKOTwiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 8: page = AllDiscountwiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 9: page = AllSettlementwiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 10: page = AllOnlineDaywiseReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 11: page = AllTimeAuditReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 12: page = AllCancelBillReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 13: page = AllCancelKotReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 14: page = AllItemConsumReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 15: page = AllMoveKotReportPage(dbToBrandMap: widget.dbToBrandMap); break;
      case 16: page = AllComplimentReportPage(dbToBrandMap: widget.dbToBrandMap); break;
    }
    if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
  }
}

class ReportTile extends StatefulWidget {
  final ReportItem report;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;
  final Color primaryColor;

  const ReportTile({
    super.key,
    required this.report,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  State<ReportTile> createState() => _ReportTileState();
}

class _ReportTileState extends State<ReportTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,

          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              _isHovered
                  ? BoxShadow(color: widget.primaryColor.withOpacity(0.2), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4))
                  : BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
            border: Border.all(
              color: _isHovered ? widget.primaryColor.withOpacity(0.5) : Colors.transparent,
              width: 1,
            ),
          ),
          transform: _isHovered ? Matrix4.translationValues(0, -5, 0) : Matrix4.identity(),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: widget.onToggleFavorite,
                  child: Icon(
                    widget.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: widget.isFavorite ? Colors.orange : const Color(0xFFBDBDBD),
                    size: 18, // Increased star size slightly
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Icon(
                        Icons.analytics_outlined,
                        size: 32, // Increased Icon size
                        color: widget.primaryColor
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.report.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13, // Increased font size
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                        height: 1.1, // Tighter line height to save space
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
  ReportItem({required this.id, required this.name, required this.group, required this.description});
}