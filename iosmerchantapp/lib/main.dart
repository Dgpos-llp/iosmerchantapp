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

  // --- API FUNCTIONS ---
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

    // FIX: Changed "totalsale" to "totalsales" to match your curl
    final dbParams = dbNames.map((db) => "DB=$db").join("&");
    final url = "${config.apiUrl}report/totalsale?startDate=$startDate&endDate=$endDate&$dbParams";

    try {
      final response = await http.get(Uri.parse(url), headers: getHeaders());
      print("📡 Status: ${response.statusCode} | Body: ${response.body}"); // Debug line

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

        // FIX 1: If the server returns a Map grouped by DB name
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((db, itemsJson) {
            if (itemsJson is List) {
              dbToItemwiseMap[db] = itemsJson.map((e) => ItemwiseReport.fromJson(e)).toList();
            }
          });
        }
        // FIX 2: If the server returns a direct List (as seen in your curl)
        else if (decoded is List) {
          // If it's a direct list, we associate it with the first DB name in your request
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
          print("📡 TAX API [$db] Body: ${response.body}"); // CHECK THIS PRINT

          if (decoded is List) {
            dbToTaxwiseMap[db] = decoded.map<TaxwiseReport>((e) => TaxwiseReport.fromJson(e)).toList();
          } else if (decoded is Map && decoded.containsKey('data')) {
            // Fallback if your API wraps the list in a 'data' key
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

// --- APP UI ---
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD5282B)),
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
    _logoAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _textAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(scale: _logoAnimation, child: Image.asset('assets/images/dposnewlogopn.png', width: 160, height: 160)),
            const SizedBox(height: 20),
            FadeTransition(opacity: _textAnimation, child: const Text('Smart POS for Smart Restaurants', style: TextStyle(fontSize: 16, color: Color(0xFF555555)))),
          ],
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

  Future<void> login(BuildContext context, WidgetRef ref) async {
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

        // FIX: Match by username only, because database password is encrypted/BCrypt
        final matchedUsers = users.where((u) => u.username.toLowerCase() == username.toLowerCase()).toList();

        if (matchedUsers.isNotEmpty) {
          print("✅ DEBUG: Mapping successful. DB count: ${matchedUsers.length}");
          final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
          ref.read(dbNamesProvider.notifier).state = dbNames;
          final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap)));
        } else {
          print("❌ DEBUG: Mapping Failed. Username '$username' not found in getAll results.");
          setState(() => errorMessage = "Invalid user mapping found.");
        }
      } else {
        print("❌ DEBUG: Auth Failed with code ${response.statusCode}");
        setState(() => errorMessage = "Invalid username or password.");
      }
    } catch (e) {
      print("🔥 DEBUG Error: $e");
      setState(() => errorMessage = "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: Center(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/dposnewlogopn.png', width: 200, height: 150),
                  Container(width: 550, child: Image.asset('assets/images/login.png', fit: BoxFit.fill, height: 500)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  width: 400, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Sign in", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      const SizedBox(height: 20),
                      TextField(controller: usernameController, decoration: InputDecoration(hintText: "Username", prefixIcon: const Icon(Icons.person, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100])),
                      const SizedBox(height: 16),
                      TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(hintText: "Password", prefixIcon: const Icon(Icons.lock, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100])),
                      const SizedBox(height: 24),
                      SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => login(context, ref), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD5282B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, color: Colors.white, size: 20), SizedBox(width: 10), Text("Sign in", style: TextStyle(fontSize: 16, color: Colors.white))]))),
                      if (errorMessage != null) ...[const SizedBox(height: 10), Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500))],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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

  Future<void> login(BuildContext context, WidgetRef ref) async {
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
        // FIX: Match by username only
        final matchedUsers = users.where((u) => u.username.toLowerCase() == username.toLowerCase()).toList();

        if (matchedUsers.isNotEmpty) {
          final dbNames = matchedUsers.map((user) => user.dbName).toSet().toList();
          ref.read(dbNamesProvider.notifier).state = dbNames;
          final dbToBrandMap = await UserData.fetchBrandNames(config, dbNames);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Dashboard(dbToBrandMap: dbToBrandMap)));
        }
      } else { setState(() => errorMessage = "Invalid username or password."); }
    } catch (e) { setState(() => errorMessage = "Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEDEB),
      body: SingleChildScrollView(
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 10, top: 20, child: Image.asset('assets/images/dposnewlogopn.png', width: 150, height: 150, fit: BoxFit.contain)),
              Align(alignment: Alignment.center, child: Container(margin: const EdgeInsets.only(top: 140, left: 0, right: 60), padding: const EdgeInsets.all(24), width: 320, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: double.infinity, height: 100, child: Image.asset('assets/images/mobiletop.png', fit: BoxFit.cover)),
                  const SizedBox(height: 16),
                  const Text("Sign in", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 16),
                  TextField(controller: usernameController, decoration: InputDecoration(hintText: "Username", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100])),
                  const SizedBox(height: 16),
                  TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(hintText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100])),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => login(context, ref), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD5282B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Sign in", style: TextStyle(fontSize: 16, color: Colors.white)))),
                  if (errorMessage != null) ...[const SizedBox(height: 10), Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500))],
                ]),
              )),
              Positioned(right: -30, top: 240, child: SizedBox(height: 350, child: Image.asset('assets/images/b.png', fit: BoxFit.contain))),
              Positioned(right: 10, top: 20, child: Image.asset('assets/images/c.png', width: 100, height: 100, fit: BoxFit.contain)),
              Positioned(right: 10, bottom: -200, child: ColorFiltered(colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.modulate), child: Image.asset('assets/images/d.png', width: 150, height: 150, fit: BoxFit.contain))),
            ],
          ),
        ),
      ),
    );
  }
}