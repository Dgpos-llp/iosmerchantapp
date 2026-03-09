//no change
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:merchant/AllBillwiseSalesReportPage.dart';
import 'package:merchant/OnlineOrderReport.dart';
import 'package:merchant/TotalSalesReport.dart';
import 'package:merchant/KotSummaryReport.dart';
import 'Dashboard.dart';

// --- GLOBAL STATE ---
final dbNamesProvider = StateProvider<List<String>>((ref) => []);
final authTokenProvider = StateProvider<String?>((ref) => null);

class AuthManager {
  static String? token;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class Config {
  final String apiUrl;
  final String clientCode;

  Config({required this.apiUrl, required this.clientCode});

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      apiUrl: json['apiUrl'],
      clientCode: json['clientCode'],
    );
  }

  static Future<Config> loadFromAsset() async {
    final jsonString = await rootBundle.loadString('assets/config.json');
    final jsonMap = json.decode(jsonString);
    return Config.fromJson(jsonMap);
  }
}

class UserData {
  final int id;
  final String dbName;
  final int usercode;
  final String username;
  final String password;

  UserData({
    required this.id,
    required this.dbName,
    required this.usercode,
    required this.username,
    required this.password,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? 0,
      dbName: json['dbName'] ?? '',
      usercode: json['usercode'] ?? 0,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
    );
  }

  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (AuthManager.token != null) 'Authorization': 'Bearer ${AuthManager.token}',
    };
  }

  // --- API FUNCTIONS (ALL ORIGINAL CODE PRESERVED) ---
  static Future<List<UserData>> fetchUsers(Config config) async {
    final url = "${config.apiUrl}${config.clientCode}/getAll?DB=${config.clientCode}";
    final response = await http.get(Uri.parse(url), headers: getHeaders());
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((e) => UserData.fromJson(e)).toList();
    } else {
      throw Exception("Failed to fetch user data");
    }
  }

  static Future<Map<String, String>> fetchBrandNames(Config config, List<String> dbNames) async {
    final Map<String, String> dbToBrandMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}config/getAll?DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          String? brandName = (decoded is Map) ? decoded['brandName'] : decoded[0]['brandName'];
          if (brandName != null) dbToBrandMap[db] = brandName;
        }
      } catch (e) { print(e); }
    }
    return dbToBrandMap;
  }

  static Future<Map<String, TotalSalesReport>> fetchTotalSalesForDbs(
      Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, TotalSalesReport> dbToTotalSalesMap = {};

    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/totalsale?startDate=$startDate&endDate=$endDate&$dbParams";

    try {
      final response = await http.get(Uri.parse(url), headers: getHeaders());
      print("📡 Status: ${response.statusCode} | Body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          dbToTotalSalesMap[dbNames.first] = TotalSalesReport.fromJson(decoded);
        }
      }
    } catch (e) {
      print("🔥 API Error: $e");
    }
    return dbToTotalSalesMap;
  }

  static Future<List<TimeslotSales>> fetchTimeslotSalesForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/timeslotsale?startDate=$startDate&endDate=$endDate&$dbParams";
    try {
      final response = await http.get(Uri.parse(url), headers: getHeaders());
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded.map((e) => TimeslotSales.fromJson(e)).toList();
      }
    } catch (e) { print(e); }
    return [];
  }

  static Future<Map<String, List<KotSummaryReport>>> fetchKotSummaryForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/kotsummary?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToKotSummaryMap[db] = decoded.map<KotSummaryReport>((e) => KotSummaryReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToKotSummaryMap;
  }

  static Future<Map<String, List<CancelKotReport>>> fetchCancelKotForDbs(String apiUrl, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<CancelKotReport>> dbToCancelKotMap = {};
    for (final db in dbNames) {
      final url = "$apiUrl/report/cancelkot?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToCancelKotMap[db] = decoded.map<CancelKotReport>((e) => CancelKotReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToCancelKotMap;
  }

  static Future<Map<String, List<MoveKotReport>>> fetchMoveKotForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<MoveKotReport>> dbToMoveKotMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/movekot?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMoveKotMap[db] = decoded.map<MoveKotReport>((e) => MoveKotReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMoveKotMap;
  }

  static Future<Map<String, List<ItemConsumReport>>> fetchItemConsumForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<ItemConsumReport>> dbToItemConsumMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/itemconsum?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToItemConsumMap[db] = decoded.map<ItemConsumReport>((e) => ItemConsumReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToItemConsumMap;
  }

  static Future<Map<String, List<ItemwiseReport>>> fetchItemwiseForDbs(
      Config config, List<String> dbNames, String startDate, String endDate) async {

    final Map<String, List<ItemwiseReport>> dbToItemwiseMap = {};
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/itemwise?startDate=$startDate&endDate=$endDate&$dbParams";

    try {
      final response = await http.get(Uri.parse(url), headers: getHeaders());
      print("📡 DEBUG URL: $url");
      print("📡 DEBUG Status: ${response.statusCode}");
      print("📡 DEBUG Body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        if (decoded is Map<String, dynamic>) {
          decoded.forEach((db, itemsJson) {
            if (itemsJson is List) {
              dbToItemwiseMap[db] = itemsJson.map((e) => ItemwiseReport.fromJson(e)).toList();
            }
          });
        }
        else if (decoded is List) {
          final String primaryDb = dbNames.isNotEmpty ? dbNames.first : "ALL";
          dbToItemwiseMap[primaryDb] = decoded.map((e) => ItemwiseReport.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print("❌ API Error: $e");
    }
    return dbToItemwiseMap;
  }

  static Future<Map<String, List<ComplimentReport>>> fetchComplimentForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<ComplimentReport>> dbToComplimentMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/compliment?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToComplimentMap[db] = decoded.map<ComplimentReport>((e) => ComplimentReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToComplimentMap;
  }

  static Future<Map<String, List<BillwiseReport>>> fetchBillwiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<BillwiseReport>> dbToBillwiseMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/billwise?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToBillwiseMap[db] = decoded.map<BillwiseReport>((e) => BillwiseReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToBillwiseMap;
  }

  static Future<Map<String, List<OnlineOrderReport>>> fetchOnlineOrdersForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<OnlineOrderReport>> dbToOnlineOrdersMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/onlinesales?DB=$db&startDate=$startDate&endDate=$endDate";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToOnlineOrdersMap[db] = decoded.map<OnlineOrderReport>((e) => OnlineOrderReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToOnlineOrdersMap;
  }

  static Future<Map<String, List<TaxwiseReport>>> fetchTaxwiseForDbs(
      Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<TaxwiseReport>> dbToTaxwiseMap = {};

    for (final db in dbNames) {
      final url = "${config.apiUrl}report/taxwise?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: UserData.getHeaders());

        print("📡 TAX API [$db] Status: ${response.statusCode}");

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          print("📡 TAX API [$db] Body: ${response.body}");

          if (decoded is List) {
            dbToTaxwiseMap[db] = decoded.map<TaxwiseReport>((e) => TaxwiseReport.fromJson(e)).toList();
          } else if (decoded is Map && decoded.containsKey('data')) {
            final data = decoded['data'] as List;
            dbToTaxwiseMap[db] = data.map<TaxwiseReport>((e) => TaxwiseReport.fromJson(e)).toList();
          }
        }
      } catch (e) {
        print("❌ TAX API Error for $db: $e");
      }
    }
    return dbToTaxwiseMap;
  }

  static Future<Map<String, List<SettlementwiseReport>>> fetchSettlementwiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<SettlementwiseReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/settlementwise?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<SettlementwiseReport>((e) => SettlementwiseReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<DiscountwiseReport>>> fetchDiscountwiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<DiscountwiseReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/discountwise?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<DiscountwiseReport>((e) => DiscountwiseReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<OnlineCancelOrderReport>>> fetchOnlineCancelOrderwiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<OnlineCancelOrderReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/onlinecanceled?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<OnlineCancelOrderReport>((e) => OnlineCancelOrderReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<KOTAnalysisReport>>> fetchKOTAnalysisForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<KOTAnalysisReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/kotanalysis?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<KOTAnalysisReport>((e) => KOTAnalysisReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<CancelBillReport>>> fetchCancelBillForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<CancelBillReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/cancelbill?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<CancelBillReport>((e) => CancelBillReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<TimeAuditReport>>> fetchTimeAuditForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<TimeAuditReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/timeaudit?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<TimeAuditReport>((e) => TimeAuditReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<PaxWiseReport>>> fetchPaxWiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<PaxWiseReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/paxwise?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<PaxWiseReport>((e) => PaxWiseReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<Map<String, List<OnlineDaywiseReport>>> fetchOnlineDaywiseForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final Map<String, List<OnlineDaywiseReport>> dbToMap = {};
    for (final db in dbNames) {
      final url = "${config.apiUrl}report/onlinedaywiselist?startDate=$startDate&endDate=$endDate&DB=$db";
      try {
        final response = await http.get(Uri.parse(url), headers: getHeaders());
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) dbToMap[db] = decoded.map<OnlineDaywiseReport>((e) => OnlineDaywiseReport.fromJson(e)).toList();
        }
      } catch (e) { print(e); }
    }
    return dbToMap;
  }

  static Future<List<OrderSummaryReport>> fetchOrderSummaryForDbs(Config config, List<String> dbNames, String startDate, String endDate) async {
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/ordersummary?startDate=$startDate&endDate=$endDate&$dbParams";
    try {
      final response = await http.get(Uri.parse(url), headers: getHeaders());
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) return decoded.map<OrderSummaryReport>((e) => OrderSummaryReport.fromJson(e)).toList();
      }
    } catch (e) { print(e); }
    return [];
  }

  Map<String, List<KotSummaryReport>> dbToKotSummaryMap = {};
  List<KotSummaryReport> allOrders = [];
  List<KotSummaryReport> activeOrders = [];

  void fetchAllKOTOrders(Config config, List<String> dbNames, String startDate, String endDate) async {
    dbToKotSummaryMap = await UserData.fetchKotSummaryForDbs(config, dbNames, startDate, endDate);
    allOrders = dbToKotSummaryMap.values.expand((x) => x).toList();
    activeOrders = allOrders.where((o) => o.kotStatus == "active").toList();
  }
}

// --- MODERNIZED APP UI ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF4154F1),
          secondary: const Color(0xFFD5282B),
          surface: Colors.white,
          background: const Color(0xFFF8F9FC),
          error: const Color(0xFFE74C3C),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4154F1), width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..forward();
    _logoAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _textAnimation = CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOut));

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ResponsiveLoginPage()));
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Colors.white,
              const Color(0xFF4154F1).withOpacity(0.05),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _logoAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4154F1).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/dposnewlogopn.png',
                    width: 140,
                    height: 140,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeTransition(
                opacity: _textAnimation,
                child: Column(
                  children: [
                    Text(
                      'Smart POS',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'for Smart Restaurants',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF7F8C8D),
                        letterSpacing: 0.5,
                      ),
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

class ResponsiveLoginPage extends StatelessWidget {
  const ResponsiveLoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 600 ? const LoginPageMobile() : const LoginPageDesktop();
  }
}

class LoginPageDesktop extends ConsumerStatefulWidget {
  const LoginPageDesktop({super.key});
  @override
  ConsumerState<LoginPageDesktop> createState() => _LoginPageDesktopState();
}

class _LoginPageDesktopState extends ConsumerState<LoginPageDesktop> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Add FocusNodes for keyboard navigation
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Handle field submission
  void _fieldFocusChange(
      BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  Future<void> login(BuildContext context, WidgetRef ref) async {
    setState(() => _isLoading = true);
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final config = await Config.loadFromAsset();
    final loginUrl = "${config.apiUrl}login/userlogin?DB=credentials";

    print("🛠️ DEBUG: Starting Authentication for $username");

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userid": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String token = data['token'] ?? '';
        AuthManager.token = token;
        ref.read(authTokenProvider.notifier).state = token;

        print("✅ DEBUG: Token retrieved. Fetching User Mappings...");

        final users = await UserData.fetchUsers(config);

        final matchedUsers = users.where((u) => u.username.toLowerCase() == username.toLowerCase()).toList();

        if (matchedUsers.isNotEmpty) {
          print("✅ DEBUG: Mapping successful. DB count: ${matchedUsers.length}");
          final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
          ref.read(dbNamesProvider.notifier).state = dbNames;
          final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);

          if (mounted) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap))
            );
          }
        } else {
          print("❌ DEBUG: Mapping Failed. Username '$username' not found in getAll results.");
          setState(() {
            errorMessage = "Invalid user mapping found.";
            _isLoading = false;
          });
        }
      } else {
        print("❌ DEBUG: Auth Failed with code ${response.statusCode}");
        setState(() {
          errorMessage = "Invalid username or password.";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("🔥 DEBUG Error: $e");
      setState(() {
        errorMessage = "Connection error. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Left side - Branding
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Updated: Larger logo without background
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // Removed background color
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                          'assets/images/dposnewlogopn.png',
                          width: 120, // Increased from 80 to 120
                          height: 120, // Increased from 80 to 120
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'Welcome Back!!!',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2C3E50),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Manage your restaurants, track sales, and monitor operations all in one place.',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF7F8C8D),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          _buildFeatureChip(Icons.restaurant, 'Multi-outlet'),
                          const SizedBox(width: 12),
                          _buildFeatureChip(Icons.analytics, 'Real-time analytics'),
                          const SizedBox(width: 12),
                          _buildFeatureChip(Icons.receipt, 'Smart reporting'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 40),
              // Right side - Login Form
              Expanded(
                flex: 1,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFF4154F1).withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Enter your credentials to access your account",
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF7F8C8D),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Username field with Enter key navigation
                            Text(
                              "Username",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: usernameController,
                              focusNode: _usernameFocusNode,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: "Enter your username",
                                prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF7F8C8D), size: 20),
                              ),
                              onSubmitted: (_) => _fieldFocusChange(
                                  context, _usernameFocusNode, _passwordFocusNode),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 20),
                            // Password field with Enter key login
                            Text(
                              "Password",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: !_isPasswordVisible,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                hintText: "Enter your password",
                                prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF7F8C8D), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF7F8C8D),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              onSubmitted: (_) {
                                _passwordFocusNode.unfocus();
                                if (!_isLoading) {
                                  login(context, ref);
                                }
                              },
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 24),
                            // Error message
                            if (errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE74C3C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: const Color(0xFFE74C3C), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFE74C3C),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : () => login(context, ref),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4154F1),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                                    : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      "Sign In",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4154F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4154F1)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4154F1),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginPageMobile extends ConsumerStatefulWidget {
  const LoginPageMobile({super.key});
  @override
  ConsumerState<LoginPageMobile> createState() => _LoginPageMobileState();
}

class _LoginPageMobileState extends ConsumerState<LoginPageMobile> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  String? errorMessage;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Add FocusNodes for keyboard navigation
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Handle field submission
  void _fieldFocusChange(
      BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  Future<void> login(BuildContext context, WidgetRef ref) async {
    setState(() => _isLoading = true);
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final config = await Config.loadFromAsset();
    final loginUrl = "${config.apiUrl}login/userlogin?DB=credentials";

    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"userid": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AuthManager.token = data['token'];
        ref.read(authTokenProvider.notifier).state = data['token'];

        final users = await UserData.fetchUsers(config);
        final matchedUsers = users.where((u) => u.username.toLowerCase() == username.toLowerCase()).toList();

        if (matchedUsers.isNotEmpty) {
          final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
          ref.read(dbNamesProvider.notifier).state = dbNames;
          final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);

          if (mounted) {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap))
            );
          }
        } else {
          setState(() {
            errorMessage = "Invalid user mapping found.";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Invalid username or password.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Connection error. Please try again.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Updated: Larger logo without background
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    // Removed background color and shadow
                    // color: Colors.white,
                    // shape: BoxShape.circle,
                    // boxShadow: [...],
                  ),
                  child: Image.asset(
                    'assets/images/dposnewlogopn.png',
                    width: 120, // Increased from 80 to 120
                    height: 120, // Increased from 80 to 120
                  ),
                ),
                const SizedBox(height: 30),
                // Title
                const Text(
                  "Welcome Back!!!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to continue",
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF7F8C8D),
                  ),
                ),
                const SizedBox(height: 40),
                // Login Form
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Username field with Enter key navigation
                      TextField(
                        controller: usernameController,
                        focusNode: _usernameFocusNode,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: "Username",
                          prefixIcon: Icon(Icons.person_outline, color: const Color(0xFF7F8C8D), size: 20),
                        ),
                        onSubmitted: (_) => _fieldFocusChange(
                            context, _usernameFocusNode, _passwordFocusNode),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      // Password field with Enter key login
                      TextField(
                        controller: passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: !_isPasswordVisible,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: Icon(Icons.lock_outline, color: const Color(0xFF7F8C8D), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF7F8C8D),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                        ),
                        onSubmitted: (_) {
                          _passwordFocusNode.unfocus();
                          if (!_isLoading) {
                            login(context, ref);
                          }
                        },
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),
                      // Error message
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE74C3C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: const Color(0xFFE74C3C), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFE74C3C),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => login(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4154F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            "Sign In",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}