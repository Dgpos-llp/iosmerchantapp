import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:merchant/KOTPage.dart';
import 'package:merchant/OnlineOrderRunningPage.dart';
import 'package:merchant/ReportPage.dart';
import 'package:merchant/RunningOrderPage.dart';
import 'package:merchant/main.dart';
import 'package:merchant/Dashboard.dart';

class SidePanel extends StatefulWidget {
  final Widget child;
  final Map<String, String> dbToBrandMap;

  const SidePanel({
    super.key,
    required this.child,
    required this.dbToBrandMap,
  });

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  bool isPanelOpen = false;

  final Map<String, bool> sectionStates = {
    "Daily Operations": true,
    "Menu": false,
    "CRM": false,
  };

  void togglePanel() => setState(() => isPanelOpen = !isPanelOpen);

  void toggleSection(String section) {
    setState(() => sectionStates[section] = !(sectionStates[section] ?? false));
  }

  void logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bool isWindows = Platform.isWindows;

    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          GestureDetector(
            onTap: () { if (isPanelOpen) togglePanel(); },
            child: widget.child,
          ),

          // Backdrop Overlay
          if (isPanelOpen)
            GestureDetector(
              onTap: togglePanel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withOpacity(0.4),
              ),
            ),

          // Side Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            left: isPanelOpen ? 0 : -280,
            top: 0,
            bottom: 0,
            child: Material(
              elevation: 16,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Container(
                width: 280,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            // In SidePanel.dart, find this section in _buildNavItem for Dashboard:
                            _buildNavItem(
                              icon: Icons.dashboard_rounded,
                              label: 'Dashboard',
                              isActive: true,
                              onTap: () {
                                togglePanel();
                                // FIX: Replace the named route navigation with direct widget navigation
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => Dashboard(dbToBrandMap: widget.dbToBrandMap),
                                  ),
                                );
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Divider(height: 30, thickness: 1),
                            ),
                            _buildCollapsibleSection(
                              title: "Daily Operations",
                              icon: Icons.storefront_rounded,
                              items: [
                                _buildSubNavItem(
                                  icon: Icons.timer_outlined,
                                  label: "Running Orders",
                                  onTap: () => _navigateTo(RunningOrderPage(dbToBrandMap: widget.dbToBrandMap)),
                                ),
                                _buildSubNavItem(
                                  icon: Icons.cloud_download_outlined,
                                  label: "Online Orders",
                                  onTap: () => _navigateTo(OnlineOrderRunningPage(dbToBrandMap: widget.dbToBrandMap)),
                                ),
                                _buildSubNavItem(
                                  icon: Icons.receipt_long_rounded,
                                  label: "KOT List",
                                  onTap: () => _navigateTo(KOTPage(dbToBrandMap: widget.dbToBrandMap)),
                                ),
                              ],
                            ),
                            _buildNavItem(
                              icon: Icons.bar_chart_rounded,
                              label: "Analytics Reports",
                              onTap: () => _navigateTo(ReportPage(dbToBrandMap: widget.dbToBrandMap)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.1,
                      child: Image.asset('assets/images/dposnewlogopn.png', width: 120),
                    ),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ),

          // Updated Floating Menu Button
          if (!isPanelOpen)
            Positioned(
              // FIX: Reduced top value to align perfectly with the AppBar title center
              // Windows: 15px (standard window title bar height)
              // Mobile: 15px (standard status bar offset + centering)
              top: isWindows && !isMobile ? 15 : 15,
              left: 16,
              child: SafeArea(
                child: FloatingActionButton.small(
                  onPressed: togglePanel,
                  backgroundColor: Colors.white,
                  elevation: 4,
                  // Use a container to ensure consistent sizing for centering
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.menu_rounded, color: Color(0xFF4154F1), size: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateTo(Widget page) {
    togglePanel();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4154F1), Color(0xFF6B7AF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Merchant App", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Store Manager", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, VoidCallback? onTap, bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isActive ? const Color(0xFF4154F1).withOpacity(0.1) : Colors.transparent,
        leading: Icon(icon, color: isActive ? const Color(0xFF4154F1) : const Color(0xFF7F8C8D)),
        title: Text(label, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? const Color(0xFF4154F1) : const Color(0xFF2C3E50))),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSubNavItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 12, top: 2, bottom: 2),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: Icon(icon, size: 20, color: const Color(0xFF7F8C8D)),
        title: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D))),
        onTap: onTap,
      ),
    );
  }

  Widget _buildCollapsibleSection({required String title, required IconData icon, required List<Widget> items}) {
    bool isOpen = sectionStates[title] ?? false;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: Icon(icon, color: const Color(0xFF7F8C8D)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
            trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
            onTap: () => toggleSection(title),
          ),
        ),
        if (isOpen) ...items,
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text("Sign Out"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          foregroundColor: Colors.red,
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}