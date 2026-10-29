import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'services/db_helper.dart';

// ⭐ नवीन — PDF Export साठी
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init bypassed on Windows: $e');
  }
  runApp(const RationTrackerApp());
}

class RationTrackerApp extends StatelessWidget {
  const RationTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'सेवा सहकारी संस्था मर्या. चनई - रेशन ट्रॅकर',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 1. SPLASH SCREEN (स्वागत स्क्रीन)
// ==========================================
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF), Color(0xFF2C3E50)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.local_grocery_store_rounded,
                    size: 70,
                    color: Colors.amberAccent,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Icon(
                      Icons.verified_rounded,
                      size: 30,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '⚡ MAHARASHTRA E-RATION SERVICES',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'AEPDS सेवा सहकारी संस्था म. चनई',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '🌾 पारदर्शक, गतिमान आणि १००% अचूक डिजिटल रेशन व्यवस्थापन प्रणाली',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 35),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 8,
                shadowColor: Colors.amber.withOpacity(0.5),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 22),
              label: const Text(
                'डॅशबोर्डमध्ये प्रवेश करा (Open App)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '© 2026 Ration Distribution System | All Rights Reserved',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class ShopColors {
  static const List<List<Color>> palette = [
    [Color(0xFF6C5CE7), Color(0xFF8E7CF7)],
    [Color(0xFF00B894), Color(0xFF55EFC4)],
    [Color(0xFFE17055), Color(0xFFFAB1A0)],
    [Color(0xFF0984E3), Color(0xFF74B9FF)],
    [Color(0xFFD63031), Color(0xFFFF7675)],
    [Color(0xFFE84393), Color(0xFFFD79A8)],
  ];

  static List<Color> forShop(String? shopNo) {
    if (shopNo == null || shopNo.isEmpty) return palette[0];
    final idx = shopNo.hashCode.abs() % palette.length;
    return palette[idx];
  }
}

class _ColSpec {
  final String label;
  final double width;
  final Color? labelColor;
  final String? sortKey;
  const _ColSpec(this.label, this.width, {this.labelColor, this.sortKey});
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}

// ==========================================
// 2. HOME SCREEN (मुख्य डॅशबोर्ड)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _allotmentRecords = [];
  List<Map<String, dynamic>> _transactionRecords = [];
  List<Map<String, dynamic>> _remainingRecords = [];
  List<Map<String, dynamic>> _outsiderRecords = []; // ⭐ बाहेरचे लाभार्थी (नवीन tab)
  Map<String, dynamic> _reconData = {}; // ⭐ हिशेब पडताळणी (बाहेरचे tab वर)
  List<Map<String, dynamic>> _dupRecords = []; // ⭐ जादा पावत्या (नवीन tab)
  int _householdCount = 0;
  int _totalMembers = 0;
  String _searchQuery = '';
  String? _selectedShop;
  String? _selectedPeriod;
  final List<String> _shopNumbers = ['104', '106'];
  List<String> _periods = [];
  late TabController _tabController;

  bool _isCardView = false;
  bool _showSmartFilters = false;

  // ⚡ ऑटो-सिंक इंजिन (Auto-Sync Variables)
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = true; // कायमस्वरूपी ON!
  bool _isAutoSyncing = false;
  DateTime? _lastSyncTime;

  // ⭐ बदल: ४५ सेकंदांऐवजी २ मिनिटं (१२० सेकंद). हवं तर हा आकडा बदला.
  final int _syncIntervalSeconds = 120;

  String get _syncIntervalLabel => _syncIntervalSeconds % 60 == 0
      ? '${_syncIntervalSeconds ~/ 60} मिनिटांनी'
      : '$_syncIntervalSeconds सेकंदांनी';

  // ⭐ पोर्टलचा HTML मागच्यासारखाच असेल तर import वगळण्यासाठी (दुकान+महिना → hash)
  final Map<String, int> _lastHtmlHash = {};

  // ⭐ सर्च बॉक्समध्ये प्रत्येक अक्षराला स्क्रीन रिबिल्ड होऊ नये म्हणून debounce
  Timer? _searchDebounce;

  // स्मार्ट फिल्टर्स
  String _filterScheme = 'सर्व';
  bool _filterOnlyWheat = false;
  bool _filterOnlyRice = false;
  bool _filterOnlySugar = false;
  bool _filterOnlySaree = false;
  String _filterUnit = 'सर्व';

  // कॉलम सॉर्टिंग
  String _sortColumn = 'srNo';
  bool _sortAscending = true;

  // Vertical scroll controllers
  final ScrollController _allotVController = ScrollController();
  final ScrollController _txnVController = ScrollController();
  final ScrollController _remVController = ScrollController();
  final ScrollController _outVController = ScrollController();
  final ScrollController _dupVController = ScrollController();

  // Horizontal scroll controllers
  final ScrollController _allotHController = ScrollController();
  final ScrollController _txnHController = ScrollController();
  final ScrollController _remHController = ScrollController();
  final ScrollController _outHController = ScrollController();
  final ScrollController _dupHController = ScrollController();

  final ScrollController _allotHHeaderController = ScrollController();
  final ScrollController _txnHHeaderController = ScrollController();
  final ScrollController _remHHeaderController = ScrollController();
  final ScrollController _outHHeaderController = ScrollController();
  final ScrollController _dupHHeaderController = ScrollController();

  final ScrollController _allotHFooterController = ScrollController();
  final ScrollController _txnHFooterController = ScrollController();
  final ScrollController _remHFooterController = ScrollController();
  final ScrollController _outHFooterController = ScrollController();
  final ScrollController _dupHFooterController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 0);
    _loadPeriods();
    _loadData();

    // ⭐ ॲप सुरू होताच ऑटो-सिंक बॅकग्राउंड टाइमर सुरू करा
    // (पहिली प्रत्यक्ष सिंक ॲप उघडल्यावर ३० सेकंदांनी होते — स्टार्टअप वेगवान राहावा म्हणून)
    _startAutoSyncLoop();

    _allotHController.addListener(() {
      if (!_allotHController.hasClients) return;
      final offset = _allotHController.offset;
      if (_allotHHeaderController.hasClients) _allotHHeaderController.jumpTo(offset);
      if (_allotHFooterController.hasClients) _allotHFooterController.jumpTo(offset);
    });
    _txnHController.addListener(() {
      if (!_txnHController.hasClients) return;
      final offset = _txnHController.offset;
      if (_txnHHeaderController.hasClients) _txnHHeaderController.jumpTo(offset);
      if (_txnHFooterController.hasClients) _txnHFooterController.jumpTo(offset);
    });
    _remHController.addListener(() {
      if (!_remHController.hasClients) return;
      final offset = _remHController.offset;
      if (_remHHeaderController.hasClients) _remHHeaderController.jumpTo(offset);
      if (_remHFooterController.hasClients) _remHFooterController.jumpTo(offset);
    });
    _outHController.addListener(() {
      if (!_outHController.hasClients) return;
      final offset = _outHController.offset;
      if (_outHHeaderController.hasClients) _outHHeaderController.jumpTo(offset);
      if (_outHFooterController.hasClients) _outHFooterController.jumpTo(offset);
    });
    _dupHController.addListener(() {
      if (!_dupHController.hasClients) return;
      final offset = _dupHController.offset;
      if (_dupHHeaderController.hasClients) _dupHHeaderController.jumpTo(offset);
      if (_dupHFooterController.hasClients) _dupHFooterController.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _searchDebounce?.cancel();
    _tabController.dispose();
    _allotVController.dispose();
    _allotHController.dispose();
    _allotHHeaderController.dispose();
    _allotHFooterController.dispose();
    _txnVController.dispose();
    _txnHController.dispose();
    _txnHHeaderController.dispose();
    _txnHFooterController.dispose();
    _remVController.dispose();
    _remHController.dispose();
    _remHHeaderController.dispose();
    _remHFooterController.dispose();
    _outVController.dispose();
    _outHController.dispose();
    _outHHeaderController.dispose();
    _outHFooterController.dispose();
    _dupVController.dispose();
    _dupHController.dispose();
    _dupHHeaderController.dispose();
    _dupHFooterController.dispose();
    super.dispose();
  }

  // =========================================================
  // ⚡ ऑटो-सिंक टाइमर लूप (Auto-Sync Loop)
  // =========================================================
  void _startAutoSyncLoop() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(Duration(seconds: _syncIntervalSeconds), (timer) async {
      if (_isAutoSyncEnabled && !_isAutoSyncing) {
        await _fetchAndSyncPortalDirectly(silent: true);
      }
    });

    // ⭐ ॲप उघडल्यावर पहिली सिंक ३० सेकंदांनंतर सुरू होते, म्हणजे स्क्रीन दिसेपर्यंत
    // सरकारी सर्व्हरची (epos.mahafood.gov.in) वाट बघत बसावं लागत नाही.
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isAutoSyncEnabled && !_isAutoSyncing) {
        _fetchAndSyncPortalDirectly(silent: true);
      }
    });
  }

  // =========================================================
  // 📅 चालू महिन्याचं नाव — उदा. "September 2026"
  // ⭐ बग-फिक्स: आधी "सर्व महिने" निवडलेलं असताना _periods.first (= January 2026)
  // वापरला जायचा, त्यामुळे सिंक चुकीच्या महिन्याचा डेटा खेचायचं.
  // =========================================================
  String _currentPeriodName() {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${names[now.month - 1]} ${now.year}';
  }

  // =========================================================
  // 📅 Period ("September 2026") वरून महिना क्रमांक काढणे
  // =========================================================
  int _monthNumberFromPeriod(String period) {
    const months = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
    };
    final lower = period.toLowerCase();
    for (final entry in months.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return DateTime.now().month; // fallback: चालू महिना
  }

  int _yearFromPeriod(String period) {
    final match = RegExp(r'(20\d{2})').firstMatch(period);
    if (match != null) return int.tryParse(match.group(1)!) ?? DateTime.now().year;
    return DateTime.now().year;
  }

  // =========================================================
  // 🌐 थेट सरकारी वेबसाईटवरून डेटा खेचणे (हात न लावता!)
  // POST request + Form Data (fps_id, dist_code, month, year)
  // ⭐ बदल: चुकीचा महिना फिक्स, HTML बदलला नसेल तर import वगळणे, प्रत्येक
  // दुकानाची स्वतंत्र try/catch (एकाला एरर आली तरी दुसरं चालतं), client नेहमी बंद.
  // =========================================================
  Future<void> _fetchAndSyncPortalDirectly({bool silent = false}) async {
    if (_isAutoSyncing) return;
    if (mounted) setState(() => _isAutoSyncing = true);

    int totalNewRecords = 0;
    final activePeriod = _selectedPeriod ?? _currentPeriodName();
    final monthNum = _monthNumberFromPeriod(activePeriod);
    final yearNum = _yearFromPeriod(activePeriod);

    final client = HttpClient();

    try {
      // सरकारी SSL प्रमाणपत्र एरर बायपास करणे
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      client.connectionTimeout = const Duration(seconds: 15);

      // खरा दुकानांचा dist_code + fps_id नकाशा (DevTools मधून मिळालेला)
      final fullShopCodes = [
        {'code': '152300400104', 'short': '104', 'dist': '1523'},
        {'code': '152300400106', 'short': '106', 'dist': '1523'},
      ];

      const postUrl = 'https://epos.mahafood.gov.in/FPS_Trans_Details.jsp';

      for (final s in fullShopCodes) {
        final fpsId = s['code']!;
        final shortShop = s['short']!;
        final distCode = s['dist']!;   

        String? htmlResponse;
        try {
          final request = await client.postUrl(Uri.parse(postUrl));
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/x-www-form-urlencoded',
          );

          // फॉर्म डेटा — DevTools मध्ये दिसलेल्या फील्ड्सप्रमाणे तंतोतंत
          final body = 'dist_code=$distCode&fps_id=$fpsId&month=$monthNum&year=$yearNum';
          request.write(body);

          final response = await request.close().timeout(const Duration(seconds: 15));
          if (response.statusCode == 200) {
            htmlResponse = await response.transform(const Utf8Decoder(allowMalformed: true)).join();
          } else {
            debugPrint('Sync ($shortShop): HTTP ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Sync ($shortShop) POST error: $e');
        }

        if (htmlResponse == null || htmlResponse.isEmpty) continue;

        // ⭐ HTML मागच्या वेळेसारखाच असेल तर काहीच नवीन नाही — import वगळा
        final hashKey = '${shortShop}_$activePeriod';
        final newHash = htmlResponse.hashCode;
        if (_lastHtmlHash[hashKey] == newHash) {
          debugPrint('Sync ($shortShop): पोर्टलवर बदल नाही, import वगळला.');
          continue;
        }

        try {
          final csvContent = _convertHtmlTableToCsv(htmlResponse);
          if (csvContent.trim().isNotEmpty) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final tempFile = File('${Directory.systemTemp.path}/auto_portal_${shortShop}_$now.csv');
            await tempFile.writeAsString(csvContent);

            int importedCount = 0;
            try {
              importedCount = await DatabaseHelper.instance.importCsvData(
                tempFile.path,
                overrideShopNo: shortShop,
                overridePeriod: activePeriod,
              );
            } finally {
              await tempFile.delete().catchError((_) => tempFile);
            }

            totalNewRecords += importedCount;
            _lastHtmlHash[hashKey] = newHash;
            debugPrint('Sync ($shortShop): $importedCount नवीन व्यवहार साठवले.');
          } else {
            debugPrint('Sync ($shortShop): CSV रिकामा आला — टेबल सापडलं नाही.');
          }
        } catch (e) {
          debugPrint('Sync ($shortShop) import error: $e');
        }
      }

      _lastSyncTime = DateTime.now();

      // जर खरोखर नवीन व्यवहार मिळाले, तरच स्क्रीन आपोआप रिफ्रेश करा!
      if (totalNewRecords > 0) {
        await _loadPeriods();
        await _loadData();

        if (mounted && !silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF00B894),
              content: Text('🔔 $totalNewRecords नवीन व्यवहार आपोआप सिंक झाले! शिल्लक यादी अपडेट झाली.'),
            ),
          );
        }
      } else if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            content: Text('ℹ️ सिंक पूर्ण झाला, पण नवीन व्यवहार सापडले नाहीत.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Auto-Sync Error: $e');
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() => _isAutoSyncing = false);
      }
    }
  }

  // =========================================================
  // HTML टेबलचे आपोआप CSV मध्ये रूपांतर करणे
  // =========================================================
  String _convertHtmlTableToCsv(String html) {
    final rowsList = <List<dynamic>>[];
    final rowRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', multiLine: true, caseSensitive: false, dotAll: true);
    final cellRegex = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', multiLine: true, caseSensitive: false, dotAll: true);
    final tagRegex = RegExp(r'<[^>]+>');

    final rows = rowRegex.allMatches(html);
    for (final r in rows) {
      final rowContent = r.group(1) ?? '';
      final cells = cellRegex.allMatches(rowContent);
      if (cells.isEmpty) continue;

      final rowValues = <String>[];
      for (final c in cells) {
        String val = c.group(1) ?? '';
        val = val.replaceAll(tagRegex, ' ');
        val = val
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&#39;', "'")
            .replaceAll('&quot;', '"');
        val = val.replaceAll(RegExp(r'\s+'), ' ').trim();
        rowValues.add(val);
      }

      if (rowValues.every((v) => v.isEmpty)) continue;
      // "Total" बेरीज-रांग वगळणे (ती व्यवहार नाही)
      if (rowValues.first.toLowerCase() == 'total') continue;
      rowsList.add(rowValues);
    }

    if (rowsList.isEmpty) return '';
    return const ListToCsvConverter().convert(rowsList);
  }

  static const List<String> _defaultPeriods = [
    'January 2026', 'February 2026', 'March 2026', 'April 2026',
    'May 2026', 'June 2026', 'July 2026', 'August 2026',
    'September 2026', 'October 2026', 'November 2026', 'December 2026',
  ];

  String _cleanRc(dynamic raw) {
    if (raw == null) return '';
    String s = raw.toString().trim();
    if (s.endsWith('.00')) s = s.substring(0, s.length - 3);
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _loadPeriods() async {
    try {
      final fetched = await DatabaseHelper.instance.fetchPeriods();
      final merged = <String>{..._defaultPeriods, ...fetched}.toList();
      if (mounted) {
        setState(() {
          _periods = merged;
          if (_selectedPeriod != null && !merged.contains(_selectedPeriod)) {
            _selectedPeriod = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading periods: $e');
    }
  }

  // ⭐ डेटा आता DatabaseHelper च्या cache मधून येतो — allotment आणि transaction
  // प्रत्येकी एकदाच वाचली जाते, आणि दुकान/महिना बदलल्यावर नेटवर्क कॉल होत नाही.
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        DatabaseHelper.instance.fetchAllotmentByShop(
          _selectedShop,
          query: _searchQuery,
          period: _selectedPeriod,
        ),
        DatabaseHelper.instance.fetchTransactionsByShop(
          _selectedShop,
          query: _searchQuery,
          period: _selectedPeriod,
        ),
        DatabaseHelper.instance.fetchRemainingRecords(
          _selectedShop,
          period: _selectedPeriod,
          query: _searchQuery,
        ),
      ]);

      final allotment = results[0] as List<Map<String, dynamic>>;
      final transactions = results[1] as List<Map<String, dynamic>>;
      final remaining = results[2] as List<Map<String, dynamic>>;

      // ⭐ बाहेरचे लाभार्थी — दोन्ही दुकानांची पूर्ण वाटप यादी वापरून (मुख्य दुकान/सर्च फिल्टरवर अवलंबून नाही)
      List<Map<String, dynamic>> outsiders = [];
      Map<String, dynamic> recon = {};
      List<Map<String, dynamic>> dups = [];
      try {
        List<Map<String, dynamic>> fullAllot = allotment;
        List<Map<String, dynamic>> fullTxn = transactions;
        List<Map<String, dynamic>> fullRem = remaining;
        if (_selectedShop != null || _searchQuery.isNotEmpty) {
          fullAllot = await DatabaseHelper.instance.fetchAllotmentByShop(null, query: '', period: _selectedPeriod);
          fullTxn = await DatabaseHelper.instance.fetchTransactionsByShop(null, query: '', period: _selectedPeriod);
          fullRem = await DatabaseHelper.instance.fetchRemainingRecords(null, period: _selectedPeriod, query: '');
        }
        outsiders = _computeOutsiders(fullAllot, fullTxn);
        recon = _computeReconciliation(fullAllot, fullRem, fullTxn);
        dups = _computeDuplicateReceipts(fullAllot, fullTxn);
      } catch (e) {
        debugPrint('Outsiders load error: $e');
      }

      final cardSet = <String>{};
      int membersTotal = 0;
      for (final r in allotment) {
        final rc = r['ration_card_no']?.toString().trim() ?? '';
        if (rc.isNotEmpty) cardSet.add(rc);
        final u = r['units'];
        membersTotal += (u is num) ? u.toInt() : (int.tryParse(u?.toString() ?? '') ?? 0);
      }

      if (mounted) {
        setState(() {
          _allotmentRecords = allotment;
          _transactionRecords = transactions;
          _remainingRecords = remaining;
          _outsiderRecords = outsiders;
          _reconData = recon;
          _dupRecords = dups;
          _householdCount = cardSet.length;
          _totalMembers = membersTotal;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  void _toggleSort(String columnKey) {
    setState(() {
      if (_sortColumn == columnKey) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = columnKey;
        _sortAscending = true;
      }
    });
  }

  // ==========================================
  // ⭐ अचूक फिल्टर + डिडुप्लिकेशन
  // ==========================================
  List<Map<String, dynamic>> _getFilteredList(
    List<Map<String, dynamic>> originalList, {
    bool isTransaction = false,
  }) {
    if (originalList.isEmpty) return [];
    final seenKeys = <String>{};
    List<Map<String, dynamic>> filtered = [];

    for (final item in originalList) {
      final rawShop = item['shop_no']?.toString().trim() ?? '';
      final is104 = rawShop.contains('104');
      final is106 = rawShop.contains('106');

      if (!is104 && !is106) continue;

      final actualShop = is104 ? '104' : '106';

      if (_selectedShop != null && actualShop != _selectedShop) {
        continue;
      }

      final rc = _cleanRc(item['ration_card_no']);
      if (rc.isEmpty) continue;

      if (!isTransaction) {
        final key = '${actualShop}_$rc';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);
      } else {
        final receipt = item['receipt_no']?.toString().trim() ?? '';
        final date = item['txn_date']?.toString().trim() ?? '';
        final key = receipt.isNotEmpty ? '${actualShop}_$receipt' : '${actualShop}_${rc}_$date';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);
      }

      if (_filterScheme != 'सर्व') {
        final scheme = item['scheme']?.toString().toUpperCase().trim() ?? '';
        if (_filterScheme == 'NPH') {
          if (!scheme.contains('NPH') &&
              !scheme.contains('विना') &&
              !scheme.contains('APL') &&
              !scheme.contains('केशरी')) {
            continue;
          }
        } else if (_filterScheme == 'PHH') {
          if (!scheme.contains('PHH') && !scheme.contains('प्राधान्य')) continue;
        } else if (_filterScheme == 'AAY') {
          if (!scheme.contains('AAY') && !scheme.contains('अंत्योदय')) continue;
        }
      }

      if (_filterOnlyWheat) {
        num wheat = num.tryParse(item['wheat']?.toString() ?? '') ?? 0;
        if (wheat <= 0) continue;
      }

      if (_filterOnlyRice) {
        num rice = num.tryParse(item['rice']?.toString() ?? '') ?? 0;
        if (rice <= 0) continue;
      }

      if (_filterOnlySugar) {
        num sugar = (num.tryParse(item['sugar_curr']?.toString() ?? '') ?? 0) +
            (num.tryParse(item['sugar']?.toString() ?? '') ?? 0) +
            (num.tryParse(item['sugar_prev']?.toString() ?? '') ?? 0);
        if (sugar <= 0) continue;
      }

      if (_filterOnlySaree) {
        num saree = num.tryParse(item['saree']?.toString() ?? '') ?? 0;
        if (isTransaction && saree > 10) saree = 0;
        if (saree <= 0) continue;
      }

      if (_filterUnit != 'सर्व') {
        int u = int.tryParse(item['units']?.toString() ?? '') ?? 0;
        int target = int.tryParse(_filterUnit) ?? 0;
        if (u != target) continue;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (item['name']?.toString() ?? '').toLowerCase();
        final cardNo = rc.toLowerCase();
        if (!name.contains(q) && !cardNo.contains(q)) continue;
      }

      filtered.add(item);
    }

    filtered.sort((a, b) {
      int comparison = 0;
      if (_sortColumn == 'name') {
        String nameA = a['name']?.toString().trim() ?? '';
        String nameB = b['name']?.toString().trim() ?? '';
        comparison = nameA.compareTo(nameB);
      } else if (_sortColumn == 'units') {
        int uA = int.tryParse(a['units']?.toString() ?? '') ?? 0;
        int uB = int.tryParse(b['units']?.toString() ?? '') ?? 0;
        comparison = uA.compareTo(uB);
      } else if (_sortColumn == 'wheat') {
        num wA = num.tryParse(a['wheat']?.toString() ?? '') ?? 0;
        num wB = num.tryParse(b['wheat']?.toString() ?? '') ?? 0;
        comparison = wA.compareTo(wB);
      } else if (_sortColumn == 'rice') {
        num rA = num.tryParse(a['rice']?.toString() ?? '') ?? 0;
        num rB = num.tryParse(b['rice']?.toString() ?? '') ?? 0;
        comparison = rA.compareTo(rB);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  // =========================================================
  // ⭐ नवीन — बाहेरचे लाभार्थी (Outsiders)
  // ज्यांचं कार्ड आपल्या (दोन्ही दुकानांच्या) वाटप यादीत नाही, पण ज्यांना आपण
  // धान्य दिलं (व्यवहार यादीत आहेत) — म्हणजे दुसऱ्या दुकानाचे / पोर्टेबिलिटीचे लोक.
  // ही यादी मुख्य स्क्रीनच्या दुकान/फिल्टर/सर्च वर अवलंबून नाही.
  // =========================================================
  String _shopOfRecord(Map<String, dynamic> r) {
    final raw = r['shop_no']?.toString().trim() ?? '';
    if (raw.contains('104')) return '104';
    if (raw.contains('106')) return '106';
    return '';
  }

  List<Map<String, dynamic>> _computeOutsiders(
    List<Map<String, dynamic>> allotment,
    List<Map<String, dynamic>> transactions,
  ) {
    // आपल्या स्वतःच्या सर्व कार्डांचा संच (दोन्ही दुकाने)
    final ownCards = <String>{};
    for (final a in allotment) {
      if (_shopOfRecord(a).isEmpty) continue;
      final rc = _cleanRc(a['ration_card_no']);
      if (rc.isNotEmpty) ownCards.add(rc);
    }

    // वाटप यादीच नसेल (आयात केलेली नाही) तर सगळेच "बाहेरचे" दिसू नयेत
    if (ownCards.isEmpty) return [];

    final seen = <String>{};
    final result = <Map<String, dynamic>>[];

    for (final t in transactions) {
      final shop = _shopOfRecord(t);
      if (shop.isEmpty) continue;

      final rc = _cleanRc(t['ration_card_no']);
      if (rc.isEmpty || ownCards.contains(rc)) continue;

      final receipt = t['receipt_no']?.toString().trim() ?? '';
      final date = t['txn_date']?.toString().trim() ?? '';
      final key = receipt.isNotEmpty ? '${shop}_$receipt' : '${shop}_${rc}_$date';
      if (!seen.add(key)) continue;

      result.add(t);
    }

    result.sort((a, b) {
      final s = _shopOfRecord(a).compareTo(_shopOfRecord(b));
      if (s != 0) return s;
      final n = (a['name']?.toString().trim() ?? '').compareTo(b['name']?.toString().trim() ?? '');
      if (n != 0) return n;
      return (a['txn_date']?.toString() ?? '').compareTo(b['txn_date']?.toString() ?? '');
    });

    return result;
  }

  // ⭐ मुख्य स्क्रीनवरील दुकान dropdown आणि सर्च बॉक्स बाहेरच्या यादीलाही लागू
  List<Map<String, dynamic>> _visibleOutsiders() {
    final q = _searchQuery.toLowerCase().trim();
    return _outsiderRecords.where((r) {
      if (_selectedShop != null && _shopOfRecord(r) != _selectedShop) return false;
      if (q.isNotEmpty) {
        final name = (r['name']?.toString() ?? '').toLowerCase();
        final rc = _cleanRc(r['ration_card_no']);
        if (!name.contains(q) && !rc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ⭐ जादा पावत्या tab — मुख्य दुकान dropdown आणि सर्च लागू (एकाच कार्डाच्या ओळी एकत्रच राहतात)
  List<Map<String, dynamic>> _visibleDups() {
    final q = _searchQuery.toLowerCase().trim();
    return _dupRecords.where((r) {
      if (_selectedShop != null && _shopOfRecord(r) != _selectedShop) return false;
      if (q.isNotEmpty) {
        final name = (r['name']?.toString() ?? '').toLowerCase();
        final rc = (r['_rc'] ?? '').toString();
        if (!name.contains(q) && !rc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  int _dupExtraCount(List<Map<String, dynamic>> rows) {
    final cards = rows.map((r) => (r['_rc'] ?? '').toString()).toSet().length;
    return rows.length - cards;
  }

  // =========================================================
  // ⭐ हिशेब पडताळणी (Reconciliation) — वाटप / शिल्लक / व्यवहार / बाहेरचे यांचा ताळमेळ
  // =========================================================
  Map<String, dynamic> _computeReconciliation(
    List<Map<String, dynamic>> allotment,
    List<Map<String, dynamic>> remaining,
    List<Map<String, dynamic>> transactions,
  ) {
    final ownCards = <String>{};
    for (final a in allotment) {
      if (_shopOfRecord(a).isEmpty) continue;
      final rc = _cleanRc(a['ration_card_no']);
      if (rc.isNotEmpty) ownCards.add(rc);
    }
    if (ownCards.isEmpty) return {};

    final appRemainingCards = <String>{};
    for (final r in remaining) {
      if (_shopOfRecord(r).isEmpty) continue;
      final rc = _cleanRc(r['ration_card_no']);
      if (rc.isNotEmpty) appRemainingCards.add(rc);
    }

    final seen = <String>{};
    final ownTxnCards = <String>{};
    final outCards = <String>{};
    int totalTxn = 0;
    int ownTxn = 0;
    int outTxn = 0;

    for (final t in transactions) {
      final shop = _shopOfRecord(t);
      if (shop.isEmpty) continue;
      final rc = _cleanRc(t['ration_card_no']);
      if (rc.isEmpty) continue;
      final receipt = t['receipt_no']?.toString().trim() ?? '';
      final date = t['txn_date']?.toString().trim() ?? '';
      final key = receipt.isNotEmpty ? '${shop}_$receipt' : '${shop}_${rc}_$date';
      if (!seen.add(key)) continue;

      totalTxn++;
      if (ownCards.contains(rc)) {
        ownTxn++;
        ownTxnCards.add(rc);
      } else {
        outTxn++;
        outCards.add(rc);
      }
    }

    return {
      'ownCards': ownCards.length,
      'takenCards': ownTxnCards.length,
      'appRemaining': appRemainingCards.length,
      'totalTxn': totalTxn,
      'ownTxn': ownTxn,
      'outTxn': outTxn,
      'outCards': outCards.length,
    };
  }

  // =========================================================
  // ⚡ AEPDS LIVE SYNC कंट्रोल डायलॉग
  // =========================================================
  Future<void> _showLiveSyncDialog() async {
    final pasteController = TextEditingController();
    String syncMode = 'auto';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.sync_rounded, color: Color(0xFF00B894)),
              const SizedBox(width: 8),
              const Text('AEPDS Live Portal Sync'),
              const Spacer(),
              if (_isAutoSyncing)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ऑटो-सिंक स्टेटस कार्ड
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isAutoSyncEnabled ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isAutoSyncEnabled ? const Color(0xFF00B894) : Colors.grey.shade400,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAutoSyncEnabled ? Icons.check_circle_rounded : Icons.pause_circle_outline,
                        color: _isAutoSyncEnabled ? const Color(0xFF2E7D32) : Colors.grey.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAutoSyncEnabled
                                  ? '🟢 ऑटो-सिंक सक्रिय आहे (दर $_syncIntervalLabel आपोआप तपासणी)'
                                  : '⏸️ ऑटो-सिंक बंद आहे',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isAutoSyncEnabled ? const Color(0xFF1B5E20) : Colors.black87,
                              ),
                            ),
                            if (_lastSyncTime != null)
                              Text(
                                'शेवटचा सिंक: ${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}:${_lastSyncTime!.second.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAutoSyncEnabled,
                        activeColor: const Color(0xFF00B894),
                        onChanged: (val) {
                          setDialogState(() => _isAutoSyncEnabled = val);
                          setState(() => _isAutoSyncEnabled = val);
                          if (val) _startAutoSyncLoop();
                        },
                      ),
                    ],    
                  ),
                ),
                const SizedBox(height: 14),

                // थेट इंटरनेट सिंक बटण
                SizedBox( 
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B894),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _fetchAndSyncPortalDirectly(silent: false);
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text(
                      'आत्ताच थेट वेबसाईटवरून सिंक करा (Sync Now)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 6),
                const Text(
                  'पर्यायी: जुनी पद्धत (जर स्वतः कॉपी-पेस्ट करायचे असल्यास):',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pasteController,
                  maxLines: 3,
                  // ⭐ फिक्स: आधी "पेस्ट केलेला डेटा सिंक करा" बटण मजकूर टाकल्यावर दिसतच नव्हतं,
                  // कारण डायलॉग रिबिल्ड होत नव्हता. आता प्रत्येक बदलावर डायलॉग रिबिल्ड होतो.
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'पोर्टलवरून कॉपी केलेला मजकूर येथे पेस्ट करा (पर्यायी)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
            if (pasteController.text.trim().isNotEmpty)
              FilledButton(
                onPressed: () async {
                  final text = pasteController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);
                  await _importPastedPortalDataSmart(text, syncMode);
                },
                child: const Text('पेस्ट केलेला डेटा सिंक करा'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _importPastedPortalDataSmart(String text, String syncMode) async {
    try {
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final activePeriod = _selectedPeriod ?? _currentPeriodName();

      int count104 = 0;
      int count106 = 0;

      if (syncMode != 'auto') {
        final tempFile = File('${Directory.systemTemp.path}/pasted_portal_${syncMode}_$now.csv');
        await tempFile.writeAsString(text);
        final count = await DatabaseHelper.instance.importCsvData(
          tempFile.path,
          overrideShopNo: syncMode,
          overridePeriod: activePeriod,
        );
        await tempFile.delete().catchError((_) => tempFile);
        if (syncMode == '104') count104 = count;
        if (syncMode == '106') count106 = count;
      } else {
        final cardToShop = <String, String>{};
        for (final r in _allotmentRecords) {
          final rc = _cleanRc(r['ration_card_no']);
          final rawShop = r['shop_no']?.toString().trim() ?? '';
          if (rc.isNotEmpty) {
            cardToShop[rc] = rawShop.contains('104') ? '104' : '106';
          }
        }

        final header = lines.first;
        final isHeaderLine = header.toLowerCase().contains('rc') ||
            header.contains('कार्ड') ||
            header.contains('Receipt') ||
            header.contains('पावती') ||
            header.contains('Sl No');

        final dataLines = isHeaderLine ? lines.sublist(1) : lines;
        final lines104 = <String>[];
        final lines106 = <String>[];

        for (final line in dataLines) {
          String detected = '';
          for (final entry in cardToShop.entries) {
            if (line.contains(entry.key)) {
              detected = entry.value;
              break;
            }
          }

          if (detected.isEmpty) {
            if (line.contains('152300400104') || line.contains('400104') || line.contains('104')) {
              detected = '104';
            } else if (line.contains('152300400106') || line.contains('400106') || line.contains('106')) {
              detected = '106';
            }
          }

          if (detected == '106') {
            lines106.add(line);
          } else {
            lines104.add(line);
          }
        }

        if (lines104.isNotEmpty) {
          final content104 = isHeaderLine ? '$header\n${lines104.join('\n')}' : lines104.join('\n');
          final f104 = File('${Directory.systemTemp.path}/pasted_104_$now.csv');
          await f104.writeAsString(content104);
          count104 = await DatabaseHelper.instance.importCsvData(
            f104.path,
            overrideShopNo: '104',
            overridePeriod: activePeriod,
          );
          await f104.delete().catchError((_) => f104);
        }

        if (lines106.isNotEmpty) {
          final content106 = isHeaderLine ? '$header\n${lines106.join('\n')}' : lines106.join('\n');
          final f106 = File('${Directory.systemTemp.path}/pasted_106_$now.csv');
          await f106.writeAsString(content106);
          count106 = await DatabaseHelper.instance.importCsvData(
            f106.path,
            overrideShopNo: '106',
            overridePeriod: activePeriod,
          );
          await f106.delete().catchError((_) => f106);
        }
      }

      await _loadPeriods();
      await _loadData();
      _tabController.animateTo(2);

      if (mounted) {
        final totalCount = count104 + count106;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF00B894),
            content: Text('✅ $totalCount नवीन व्यवहार यशस्वीरित्या सिंक झाले!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('सिंक करताना अडचण: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndImportCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;

        String detectedShop = await DatabaseHelper.instance.peekShopNo(path);
        String? overrideShopNo;
        if (detectedShop.isEmpty) {
          overrideShopNo = await _askShopNoManually();
          if (overrideShopNo == null || overrideShopNo.trim().isEmpty) return;
        }

        String detectedPeriod = await DatabaseHelper.instance.peekPeriod(path);
        String? overridePeriod;
        if (detectedPeriod.isEmpty) {
          overridePeriod = await _askPeriodManually();
          if (overridePeriod == null || overridePeriod.trim().isEmpty) return;
        }

        int count = await DatabaseHelper.instance.importCsvData(
          path,
          overrideShopNo: overrideShopNo,
          overridePeriod: overridePeriod,
        );
        await _loadPeriods();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF00B894),
              content: Text('✅ $count रेकॉर्ड यशस्वीरित्या आयात झाले!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('Error importing CSV: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndImportMasterNames() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        int count = await DatabaseHelper.instance.importMasterNamesCsv(path);
        await _loadData();                                                       
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF00B894),
              content: Text('✅ मास्टर नावं आयात झाली: $count'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('Master Names import मध्ये अडचण: $e'),
          ),
        );
      }
    }
  }

  Future<void> _syncNames() async {
    final result = await DatabaseHelper.instance.syncNamesFromMaster();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF00B894),
          content: Text('✅ नावं जुळवली: वाटप=${result['allotment']}, व्यवहार=${result['transaction']}'),
        ),
      );
    }
  }

  // =========================================================
  // 🧹 डुप्लिकेट साफ करा (आधीच्या ऑटो-सिंकने साठवलेले तेच रेकॉर्ड्स)
  // आधी फक्त मोजतो, तुम्ही "होय, साफ करा" म्हटल्यावरच डिलीट करतो.
  // =========================================================
  Future<void> _cleanDuplicatesDialog() async {
    if (_isAutoSyncing) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सिंक चालू आहे — तो संपल्यावर पुन्हा प्रयत्न करा.')),
        );
      }
      return;
    }

    // साफसफाई चालू असताना ऑटो-सिंक मधे येऊ नये म्हणून थांबवतो
    setState(() => _isAutoSyncing = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔍 डुप्लिकेट तपासत आहे... (डेटा जास्त असल्यास थोडा वेळ लागेल)')),
        );
      }

      final plan = await DatabaseHelper.instance.findDuplicates();
      if (!mounted) return;

      if (plan.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 कोणतेही डुप्लिकेट सापडले नाहीत.')),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('डुप्लिकेट साफ करायचे?'),
          content: Text(
            'सापडलेले जादा (डुप्लिकेट) रेकॉर्ड्स:\n\n'
            '• वाटप: ${plan.allotmentCount}\n'
            '• व्यवहार: ${plan.transactionCount}\n\n'
            'प्रत्येक गटातलं एक रेकॉर्ड ठेवलं जाईल, फक्त जादा प्रती डिलीट होतील. '
            'हे कायमचं आहे (undo नाही).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करा')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('होय, साफ करा'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🧹 डिलीट सुरू आहे... कृपया ॲप बंद करू नका.')),
        );
      }

      final res = await DatabaseHelper.instance.deleteDuplicates(plan);
      await _loadPeriods();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF00B894),
            content: Text('✅ साफ झालं: वाटप=${res['allotment']}, व्यवहार=${res['transaction']} जादा रेकॉर्ड्स डिलीट.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            content: Text('डुप्लिकेट साफ करताना अडचण: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAutoSyncing = false);
      }
    }
  }

  Future<void> _exportMissingNamesCsv(List<String> missing) async {
    List<List<dynamic>> rows = [
      ['Sr No', 'RC No', 'Name'],
    ];
    for (int i = 0; i < missing.length; i++) {
      rows.add([i + 1, missing[i], '']);
    }
    final csvData = const ListToCsvConverter().convert(rows);

    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'नाव नसलेली कार्डे — CSV सेव्ह करा',
        fileName: 'missing_names.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.csv')) {
          savePath = '$savePath.csv';
        }
        final file = File(savePath);
        await file.writeAsBytes(utf8.encode('\uFEFF$csvData'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Export यशस्वी (${missing.length} कार्डे): $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  Future<void> _showMissingNamesDialog() async {
    final missing = await DatabaseHelper.instance.fetchMissingNameRationCards();
    if (!mounted) return;

    if (missing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 सर्व कार्डांना नावं आधीच आहेत!')),
      );
      return;
    }

    final controllers = {for (final rc in missing) rc: TextEditingController()};

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('नाव नसलेली कार्डे (${missing.length})'),
            TextButton.icon(
              onPressed: () => _exportMissingNamesCsv(missing),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export यादी', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          height: 440,
          child: ListView.separated(
            itemCount: missing.length,
            separatorBuilder: (_, __) => const Divider(height: 12),
            itemBuilder: (ctx, i) {
              final rc = missing[i];
              return Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      rc,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: controllers[rc],
                      decoration: InputDecoration(
                        hintText: 'नाव टाका',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
          FilledButton(
            onPressed: () async {
              int saved = 0;
              for (final rc in missing) {
                final name = controllers[rc]!.text.trim();
                if (name.isNotEmpty) {
                  await DatabaseHelper.instance.upsertMasterName(rc, name);
                  saved++;
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ $saved नावं सेव्ह झाली.')),
                );
              }
            },
            child: const Text('सेव्ह करा'),
          ),
        ],
      ),
    );
  }

  Widget _nameCell(String rationCardNo, String? name) {
    final hasName = name != null && name.isNotEmpty;
    return InkWell(
      onTap: () => _editNameDialog(rationCardNo, name ?? ''),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                hasName ? name : 'नाव टाका',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: hasName ? Colors.black87 : Colors.red.shade400,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _editNameDialog(String rationCardNo, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('नाव एडिट करा — $rationCardNo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'नाव टाका',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करा')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('सेव्ह करा'),
          ),
        ],
      ),
    );

    if (newName == null) return;
    await DatabaseHelper.instance.upsertMasterName(rationCardNo, newName);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF00B894),
          content: Text(newName.isEmpty ? '✅ नाव काढलं.' : '✅ नाव अपडेट झालं: $newName'),
        ),
      );
    }
  }

  Widget _mobileCell(String rationCardNo, String? mobile) {
    final hasMobile = mobile != null && mobile.isNotEmpty;
    return InkWell(
      onTap: () => _editMobileDialog(rationCardNo, mobile ?? ''),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                hasMobile ? mobile : 'नंबर टाका',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: hasMobile ? const Color(0xFF1565C0) : Colors.grey,
                  fontWeight: hasMobile ? FontWeight.bold : FontWeight.normal,
                  fontStyle: hasMobile ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Future<void> _editMobileDialog(String rationCardNo, String currentMobile) async {
    final controller = TextEditingController(text: currentMobile);
    final newMobile = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('मोबाईल नंबर — $rationCardNo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            hintText: '10 अंकी मोबाईल नंबर',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करा')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('सेव्ह करा'),
          ),
        ],
      ),
    );

    if (newMobile == null) return;
    await DatabaseHelper.instance.upsertMobile(rationCardNo, newMobile);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF00B894),
          content: Text(newMobile.isEmpty ? '✅ मोबाईल काढला.' : '✅ मोबाईल सेव्ह झाला: $newMobile'),
        ),
      );
    }
  }

  String _buildRationMessage(Map<String, dynamic> r) {
    return '''सेवा सहकारी संस्था मर्या.चनई ता.अंबाजोगाई.
( सरकार मान्य )
स्वस्त धान्य दुकान क्र 152300400104
स्वस्त धान्य दुकान क्र 152300400106

📍 सूचना 📍
दोन्ही स्वस्त धान्य दुकानाच्या कार्ड धारकांना सूचित करण्यात येते की,स्वस्त धान्य दुकानाच्या नियमीत धान्य,ऑगस्ट 2026 सर्व कार्ड धारकांचे (APL शेतकरी कार्ड धारक वगळून) उर्वरित सर्व कार्ड धरकांचे राशन वाटप करावयाचे आहे तरी सर्व कार्ड धारकांना कळविण्यात येते की खाली दिलेल्या वेळेत आपले धान्य मोफत घेवून जाणे हि विनंती.
नोट: ऑगस्ट मधील धान्य दिनांक-17-08-2026 पूर्वी घेऊन जाणे नंतर धान्य भेटणार नाही याची नोंद घ्यावी.
वाटप दिनांक:- 13/08/2026 ते 17/08/2026
वेळ :- सकाळी 9 ते 12 संध्याकाळी 4 ते 6

(अमोघ कदम)
विक्रेता तथा चेअरमन सेवा सहकारी संस्था मर्यादित चनई. ता अंबाजोगाई जि बीड.''';
  }

  Future<void> _makeCall(String mobile) async {
    final clean = mobile.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: clean);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _sendSms(Map<String, dynamic> r) async {
    final mobile = r['mobile']?.toString().trim() ?? '';
    final rc = r['ration_card_no']?.toString() ?? '';
    if (mobile.isEmpty) {
      await _editMobileDialog(rc, '');
      return;
    }

    final message = _buildRationMessage(r);
    final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'sms', path: cleanMobile, queryParameters: {'body': message});

    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        final fallbackUri = Uri.parse('sms:$cleanMobile?body=${Uri.encodeComponent(message)}');
        launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('SMS ॲप सापडले नाही'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'मेसेज क्लिपबोर्डवर कॉपी केला आहे — तुमच्या मोबाईलवरील SMS ॲपमध्ये पेस्ट करून $mobile या नंबरवर पाठवा:',
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(message, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
          ],
        ),
      );
    }
  }

  Widget _smsButtonCell(Map<String, dynamic> r) {
    return Center(
      child: InkWell(
        onTap: () => _sendSms(r),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF2E7D32)),
          ),
          child: const Icon(Icons.sms_rounded, size: 14, color: Color(0xFF2E7D32)),
        ),
      ),
    );
  }

  Future<void> _sendAllSms(List<Map<String, dynamic>> records) async {
    final withMobile = records.where((r) => (r['mobile']?.toString().trim() ?? '').isNotEmpty).toList();
    final withoutMobile = records.length - withMobile.length;

    if (withMobile.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('कोणत्याही कार्डधारकाला मोबाईल नंबर नाही — आधी नंबर टाका.')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('सर्वांना SMS पाठवायचा?'),
        content: Text(
          '${withMobile.length} कार्डधारकांना मेसेज तयार होईल (एकामागोमाग).\n'
          '${withoutMobile > 0 ? "$withoutMobile कार्डांना मोबाईल नंबर नसल्याने ते वगळले जातील.\n\n" : ""}'
          'मोबाईलवरील SMS ॲपमध्ये मेसेज तयार होऊन उघडेल.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करा')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('सुरू करा')),
        ],
      ),
    );
    if (confirm != true) return;

    for (int i = 0; i < withMobile.length; i++) {
      final r = withMobile[i];
      final mobile = r['mobile']?.toString().trim() ?? '';
      final name = r['name']?.toString() ?? '';
      final message = _buildRationMessage(r);
      final cleanMobile = mobile.replaceAll(RegExp(r'[^0-9+]'), '');

      final uri = Uri(scheme: 'sms', path: cleanMobile, queryParameters: {'body': message});
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }

      if (launched) continue;

      await Clipboard.setData(ClipboardData(text: message));
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${i + 1} / ${withMobile.length} — $name ($mobile)'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('मेसेज क्लिपबोर्डवर कॉपी झाला — SMS ॲपमध्ये पेस्ट करून पाठवा:'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Text(message, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'stop'), child: const Text('थांबवा')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'next'), child: const Text('पुढील ▶')),
          ],
        ),
      );

      if (action != 'next') break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Send All पूर्ण झालं.')),
      );
    }
  }

  // =========================================================
  // ⭐ नवीन — "बाहेरचे लाभार्थी" section (Summary मध्ये): table + नाव एडिट
  // =========================================================
  // ⭐ धान्य हिशेब — वाटप / आपल्या कार्डांना वितरित / शिल्लक / बाहेरच्यांना वितरित (दोन्ही दुकाने, डुप्लिकेट वगळून)
  Map<String, dynamic> _computeGrainSummary(
    List<Map<String, dynamic>> allotment,
    List<Map<String, dynamic>> remaining,
    List<Map<String, dynamic>> transactions,
  ) {
    num n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
    Map<String, num> zero() => {'count': 0, 'wheat': 0, 'rice': 0, 'sugar': 0, 'saree': 0, 'amount': 0};
    void add(Map<String, num> m, num wheat, num rice, num sugar, num saree, num amount) {
      m['count'] = (m['count'] ?? 0) + 1;
      m['wheat'] = (m['wheat'] ?? 0) + wheat;
      m['rice'] = (m['rice'] ?? 0) + rice;
      m['sugar'] = (m['sugar'] ?? 0) + sugar;
      m['saree'] = (m['saree'] ?? 0) + saree;
      m['amount'] = (m['amount'] ?? 0) + amount;
    }

    final ownCards = <String>{};
    final allot = zero();
    final own = zero();
    final rem = zero();
    final out = zero();

    final seenA = <String>{};
    for (final a in allotment) {
      final shop = _shopOfRecord(a);
      if (shop.isEmpty) continue;
      final rc = _cleanRc(a['ration_card_no']);
      if (rc.isEmpty) continue;
      ownCards.add(rc);
      if (!seenA.add('${shop}_$rc')) continue;
      add(allot, n(a['wheat']), n(a['rice']), n(a['sugar_curr']), n(a['saree']), 0);
    }
    if (ownCards.isEmpty) return {};

    final seenR = <String>{};
    for (final r in remaining) {
      final shop = _shopOfRecord(r);
      if (shop.isEmpty) continue;
      final rc = _cleanRc(r['ration_card_no']);
      if (rc.isEmpty) continue;
      if (!seenR.add('${shop}_$rc')) continue;
      add(rem, n(r['wheat']), n(r['rice']), n(r['sugar_curr']), n(r['saree']), 0);
    }

    final seenT = <String>{};
    for (final t in transactions) {
      final shop = _shopOfRecord(t);
      if (shop.isEmpty) continue;
      final rc = _cleanRc(t['ration_card_no']);
      if (rc.isEmpty) continue;
      final receipt = t['receipt_no']?.toString().trim() ?? '';
      final date = t['txn_date']?.toString().trim() ?? '';
      final key = receipt.isNotEmpty ? '${shop}_$receipt' : '${shop}_${rc}_$date';
      if (!seenT.add(key)) continue;

      num saree = n(t['saree']);
      if (saree > 10) saree = 0;
      add(ownCards.contains(rc) ? own : out, n(t['wheat']), n(t['rice']), n(t['sugar']), saree, n(t['amount']));
    }

    return {'allot': allot, 'own': own, 'rem': rem, 'out': out};
  }

  // ⭐ Summary PDF — कार्डांचा हिशेब + धान्य हिशेब (table स्वरूपात)
  Future<void> _exportSummaryPdf(Map<String, dynamic> recon, Map<String, dynamic> grain, String? period) async {
    if (recon.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF साठी डेटा उपलब्ध नाही (वाटप यादी आयात केलेली नाही).')),
        );
      }
      return;
    }

    int v(String k) => (recon[k] as int?) ?? 0;
    final ownCards = v('ownCards');
    final taken = v('takenCards');
    final appRemaining = v('appRemaining');
    final totalTxn = v('totalTxn');
    final ownTxn = v('ownTxn');
    final outTxn = v('outTxn');
    final outCards = v('outCards');
    final expectedRemaining = ownCards - taken;
    final extra = ownTxn - taken;
    final ok = expectedRemaining == appRemaining;

    Map<String, num> g(String k) {
      final raw = grain[k];
      if (raw is Map) {
        return raw.map<String, num>((key, value) => MapEntry(key.toString(), value as num));
      }
      return <String, num>{};
    }

    List<String> grainRow(String label, Map<String, num> x, {bool showAmount = true}) => [
          label,
          _fmtNum(x['count'] ?? 0),
          _fmtNum(x['wheat'] ?? 0),
          _fmtNum(x['rice'] ?? 0),
          _fmtNum(x['sugar'] ?? 0),
          _fmtNum(x['saree'] ?? 0),
          showAmount ? _fmtNum(x['amount'] ?? 0) : '-',
        ];

    final allot = g('allot');
    final own = g('own');
    final rem = g('rem');
    final out = g('out');
    final Map<String, num> distributed = {
      for (final k in ['count', 'wheat', 'rice', 'sugar', 'saree', 'amount']) k: (own[k] ?? 0) + (out[k] ?? 0),
    };

    try {
      final regularFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final ttfRegular = pw.Font.ttf(regularFontData);
      final ttfBold = pw.Font.ttf(boldFontData);

      const headerColor = PdfColor.fromInt(0xFF4A0E4E);
      const stripeColor = PdfColor.fromInt(0xFFF5F1FA);
      const borderColor = PdfColor.fromInt(0xFFD9CFEA);

      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dateText = '$dd-$mm-${now.year}';

      pw.Widget sectionTitle(String t) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
            child: pw.Text(t, style: pw.TextStyle(font: ttfBold, fontSize: 12, color: headerColor)),
          );

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          maxPages: 999999999,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('सेवा सहकारी संस्था मर्या. चनई — एकूण अहवाल (हिशेब पडताळणी)',
                  style: pw.TextStyle(font: ttfBold, fontSize: 15, color: headerColor)),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.4, color: headerColor),
              pw.SizedBox(height: 6),
              pw.Text(
                'महिना: ${period ?? "सर्व"}   |   दुकान: 104 + 106 (दोन्ही)   |   दिनांक: $dateText',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('तयार केले: सेवा सहकारी संस्था मर्या. चनई',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
              pw.Text('पान ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          build: (ctx) => [
            sectionTitle('१. कार्डांचा हिशेब'),
            pw.Table.fromTextArray(
              headers: ['विवरण', 'संख्या', 'हिशेब'],
              data: [
                ['आपल्या वाटप यादीतील कार्डे', '$ownCards', 'दुकान 104 + 106'],
                ['धान्य घेतलेली कार्डे', '$taken', 'आपली कार्डे ज्यांचा व्यवहार झाला'],
                ['शिल्लक कार्डे', '$expectedRemaining', '$ownCards - $taken'],
                ['एकूण व्यवहार (पावत्या)', '$totalTxn', 'पोर्टलवरील एकूण नोंदी'],
                ['आपल्या कार्डांचे व्यवहार', '$ownTxn', '$totalTxn - $outTxn'],
                ['आपल्या कार्डांवर जादा पावत्या', '$extra', '$ownTxn - $taken'],
                ['बाहेरचे व्यवहार', '$outTxn', 'व्यवहार यादीत, वाटप यादीत नसलेली कार्डे'],
                ['बाहेरची वेगळी कार्डे (माणसं)', '$outCards', 'एकाच कार्डाचे व्यवहार एकत्र'],
              ],
              headerStyle: pw.TextStyle(font: ttfBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey900),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerLeft,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: pw.TableBorder.all(color: borderColor, width: 0.4),
              oddRowDecoration: const pw.BoxDecoration(color: stripeColor),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(3.2),
              },
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              ok
                  ? 'ताळमेळ जुळला: ॲपची शिल्लक यादी ($appRemaining) = वाटप - घेतलेली ($expectedRemaining)'
                  : 'लक्ष द्या: ॲपची शिल्लक यादी $appRemaining आहे, पण वाटप - घेतलेली = $expectedRemaining',
              style: pw.TextStyle(font: ttfBold, fontSize: 9, color: headerColor),
            ),
            if (extra > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'टीप: $extra जादा पावत्या म्हणजे काही आपल्या कार्डांवर एकापेक्षा जास्त वेळा धान्य नोंदलं गेलं आहे.',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: PdfColors.grey700),
                ),
              ),
            sectionTitle('२. धान्य हिशेब'),
            pw.Table.fromTextArray(
              headers: ['विवरण', 'कार्डे / व्यवहार', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम'],
              data: [
                grainRow('वाटप (Allotment)', allot, showAmount: false),
                grainRow('आपल्या कार्डांना वितरित', own),
                grainRow('शिल्लक (Remaining)', rem, showAmount: false),
                grainRow('बाहेरच्यांना वितरित', out),
                grainRow('एकूण वितरित (आपले + बाहेरचे)', distributed),
              ],
              headerStyle: pw.TextStyle(font: ttfBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey900),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              border: pw.TableBorder.all(color: borderColor, width: 0.4),
              oddRowDecoration: const pw.BoxDecoration(color: stripeColor),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.4),
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(1),
                6: const pw.FlexColumnWidth(1.2),
              },
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Summary PDF सेव्ह करा',
        fileName: 'summary_hishob.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.pdf')) savePath = '$savePath.pdf';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ PDF Export यशस्वी: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  // =========================================================
  // ⭐ जादा पावत्या — आपल्या कार्डावर एकापेक्षा जास्त वेळा धान्य नोंदलेलं (डुप्लिकेट पावती वगळून)
  // =========================================================
  List<Map<String, dynamic>> _computeDuplicateReceipts(
    List<Map<String, dynamic>> allotment,
    List<Map<String, dynamic>> transactions,
  ) {
    final ownCards = <String>{};
    for (final a in allotment) {
      if (_shopOfRecord(a).isEmpty) continue;
      final rc = _cleanRc(a['ration_card_no']);
      if (rc.isNotEmpty) ownCards.add(rc);
    }
    if (ownCards.isEmpty) return [];

    final seen = <String>{};
    final byCard = <String, List<Map<String, dynamic>>>{};
    for (final t in transactions) {
      final shop = _shopOfRecord(t);
      if (shop.isEmpty) continue;
      final rc = _cleanRc(t['ration_card_no']);
      if (rc.isEmpty || !ownCards.contains(rc)) continue;
      final receipt = t['receipt_no']?.toString().trim() ?? '';
      final date = t['txn_date']?.toString().trim() ?? '';
      final key = receipt.isNotEmpty ? '${shop}_$receipt' : '${shop}_${rc}_$date';
      if (!seen.add(key)) continue;
      byCard.putIfAbsent(rc, () => <Map<String, dynamic>>[]).add(t);
    }

    final result = <Map<String, dynamic>>[];
    final cards = byCard.keys.where((k) => byCard[k]!.length > 1).toList()..sort();
    for (final rc in cards) {
      final list = byCard[rc]!;
      list.sort((a, b) => (a['txn_date'] ?? '').toString().compareTo((b['txn_date'] ?? '').toString()));
      for (int i = 0; i < list.length; i++) {
        final row = Map<String, dynamic>.from(list[i]);
        row['_seq'] = i + 1;
        row['_cnt'] = list.length;
        row['_rc'] = rc;
        result.add(row);
      }
    }
    return result;
  }

  Widget _buildDuplicateReceiptsSection({
    required List<Map<String, dynamic>> rows,
    required String? period,
  }) {
    const color = Color(0xFFE67E22);
    final cardCount = rows.map((r) => (r['_rc'] ?? '').toString()).toSet().length;
    final extra = rows.length - cardCount;

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 40),
      const _ColSpec('नाव', 170),
      const _ColSpec('कार्ड क्र.', 125),
      const _ColSpec('पावती', 55),
      const _ColSpec('दुकान', 55),
      const _ColSpec('पावती क्र.', 160),
      const _ColSpec('दिनांक / वेळ', 125),
      const _ColSpec('गहू', 55),
      const _ColSpec('तांदूळ', 60),
      const _ColSpec('साखर', 55),
      const _ColSpec('साडी', 50),
      const _ColSpec('रक्कम', 65),
    ];
    final widths = columns.map((c) => c.width).toList();
    final totalWidth = widths.fold<double>(0, (sum, w) => sum + w);

    Widget cell(double w, Widget child) => Container(
          width: w,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          alignment: Alignment.centerLeft,
          child: child,
        );
    const cellStyle = TextStyle(fontSize: 11);

    final headerRow = Container(
      color: color.withOpacity(0.16),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            cell(widths[i], Text(columns[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    // प्रत्येक कार्डाच्या गटाला वेगळी झलक (एकाच कार्डाच्या ओळी एकत्र दिसाव्यात)
    final groupOf = <int>[];
    int g = -1;
    String? lastRc;
    for (final r in rows) {
      final rc = (r['_rc'] ?? '').toString();
      if (rc != lastRc) {
        g++;
        lastRc = rc;
      }
      groupOf.add(g);
    }

    Widget dataRow(int i, Map<String, dynamic> r) {
      final rc = (r['_rc'] ?? '').toString();
      final name = _sanitizeForPdf(r['name'], fallback: 'नाव उपलब्ध नाही');
      final seq = (r['_seq'] ?? 1).toString();
      final cnt = (r['_cnt'] ?? 1).toString();
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final String cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');

      return Container(
        decoration: BoxDecoration(
          color: groupOf[i].isEven ? const Color(0xFFFFF6E8) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            cell(widths[0], Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
            cell(widths[1], Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            cell(widths[2], Text(rc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            cell(widths[3], Text('$seq / $cnt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
            cell(widths[4], Text(_shopOfRecord(r), style: cellStyle)),
            cell(widths[5], Text(r['receipt_no']?.toString() ?? '', style: cellStyle)),
            cell(widths[6], Text(r['txn_date']?.toString() ?? '', style: cellStyle)),
            cell(widths[7], Text(r['wheat']?.toString() ?? '0', style: cellStyle)),
            cell(widths[8], Text(r['rice']?.toString() ?? '0', style: cellStyle)),
            cell(widths[9], Text(r['sugar']?.toString() ?? '0', style: cellStyle)),
            cell(widths[10], Text(cleanSaree, style: cellStyle)),
            cell(widths[11], Text(r['amount']?.toString() ?? '0', style: cellStyle)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_copy_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('जादा पावत्या (एकाच कार्डावर एकापेक्षा जास्त वेळा धान्य)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ),
              Text('$cardCount कार्डे / $extra जादा पावत्या', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD63031),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: rows.isEmpty ? null : () => _exportDuplicateReceiptsPdf(rows, period),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: const Text('PDF / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'हे आपल्याच वाटप यादीतील कार्ड आहेत, ज्यांच्यावर वेगवेगळ्या पावत्यांनी धान्य दोनदा (किंवा जास्त) दिलेलं दिसतं. तपासा.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('✅ कोणत्याही कार्डावर जादा पावती नाही.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      headerRow,
                      for (int i = 0; i < rows.length; i++) dataRow(i, rows[i]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ⭐ जादा पावत्या PDF
  Future<void> _exportDuplicateReceiptsPdf(List<Map<String, dynamic>> rows, String? period) async {
    if (rows.isEmpty) return;

    final headers = [
      'अ.क्र.', 'नाव', 'कार्ड क्र.', 'पावती', 'दुकान', 'प्रकार', 'स्टेटस', 'पावती क्र.',
      'दिनांक / वेळ', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम',
    ];
    final dataRows = <List<String>>[];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');
      final seq = (r['_seq'] ?? 1).toString();
      final cnt = (r['_cnt'] ?? 1).toString();
      dataRows.add([
        '${i + 1}',
        _sanitizeForPdf(r['name'], fallback: 'नाव उपलब्ध नाही'),
        (r['_rc'] ?? '').toString(),
        '$seq / $cnt',
        _shopOfRecord(r),
        _sanitizeForPdf(r['avail_type']),
        _sanitizeForPdf(r['status']),
        _sanitizeForPdf(r['receipt_no']),
        _sanitizeForPdf(r['txn_date']),
        _sanitizeForPdf(r['wheat'], fallback: '0'),
        _sanitizeForPdf(r['rice'], fallback: '0'),
        _sanitizeForPdf(r['sugar'], fallback: '0'),
        _sanitizeForPdf(cleanSaree, fallback: '0'),
        _sanitizeForPdf(r['amount'], fallback: '0'),
      ]);
    }

    final cardCount = rows.map((r) => (r['_rc'] ?? '').toString()).toSet().length;
    final extra = rows.length - cardCount;

    try {
      final regularFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final ttfRegular = pw.Font.ttf(regularFontData);
      final ttfBold = pw.Font.ttf(boldFontData);

      const headerColor = PdfColor.fromInt(0xFF4A0E4E);
      const stripeColor = PdfColor.fromInt(0xFFF5F1FA);
      const borderColor = PdfColor.fromInt(0xFFD9CFEA);

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          maxPages: 999999999,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('सेवा सहकारी संस्था मर्या. चनई — जादा पावत्यांची यादी',
                      style: pw.TextStyle(font: ttfBold, fontSize: 15, color: headerColor)),
                  pw.Text('पान ${ctx.pageNumber} / ${ctx.pagesCount}',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.4, color: headerColor),
              pw.SizedBox(height: 6),
              pw.Text(
                'कार्डे: $cardCount   |   जादा पावत्या: $extra   |   महिना: ${period ?? "सर्व"}   |   एकाच कार्डावर एकापेक्षा जास्त पावत्या',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('तयार केले: सेवा सहकारी संस्था मर्या. चनई',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(font: ttfBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey900),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              border: pw.TableBorder.all(color: borderColor, width: 0.4),
              oddRowDecoration: const pw.BoxDecoration(color: stripeColor),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(0.7),
                5: const pw.FlexColumnWidth(1.3),
                6: const pw.FlexColumnWidth(1.1),
                7: const pw.FlexColumnWidth(2.1),
                8: const pw.FlexColumnWidth(1.6),
                9: const pw.FlexColumnWidth(0.7),
                10: const pw.FlexColumnWidth(0.7),
                11: const pw.FlexColumnWidth(0.7),
                12: const pw.FlexColumnWidth(0.6),
                13: const pw.FlexColumnWidth(0.8),
              },
              cellHeight: 20,
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'जादा पावत्या PDF सेव्ह करा',
        fileName: 'extra_receipts.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.pdf')) savePath = '$savePath.pdf';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ PDF Export यशस्वी: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  Widget _buildReconciliationSection(Map<String, dynamic> m, {VoidCallback? onPdf}) {
    if (m.isEmpty) return const SizedBox.shrink();
    int v(String k) => (m[k] as int?) ?? 0;

    const color = Color(0xFF0984E3);
    final ownCards = v('ownCards');
    final taken = v('takenCards');
    final appRemaining = v('appRemaining');
    final totalTxn = v('totalTxn');
    final ownTxn = v('ownTxn');
    final outTxn = v('outTxn');
    final outCards = v('outCards');
    final expectedRemaining = ownCards - taken;
    final extraReceipts = ownTxn - taken;
    final remainingOk = expectedRemaining == appRemaining;

    Widget cell(String text, {bool bold = false, Color? c, double size = 12, TextAlign align = TextAlign.left}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: c ?? Colors.black87),
        ),
      );
    }

    TableRow headRow() => TableRow(
          decoration: BoxDecoration(color: color.withOpacity(0.14)),
          children: [
            cell('विवरण', bold: true),
            cell('संख्या', bold: true, align: TextAlign.right),
            cell('हिशेब', bold: true),
          ],
        );

    TableRow row(String label, int value, String formula, {bool highlight = false, Color? valueColor}) => TableRow(
          decoration: BoxDecoration(color: highlight ? color.withOpacity(0.07) : Colors.white),
          children: [
            cell(label, bold: highlight),
            cell('$value', bold: true, c: valueColor ?? color, size: 13, align: TextAlign.right),
            cell(formula, size: 11, c: Colors.black54),
          ],
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('हिशेब पडताळणी (वाटप • शिल्लक • व्यवहार • बाहेरचे)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              ),
              if (onPdf != null)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD63031),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: const Text('PDF / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3.2),
                1: FixedColumnWidth(70),
                2: FlexColumnWidth(3),
              },
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
              children: [
                headRow(),
                row('आपल्या वाटप यादीतील कार्डे', ownCards, 'दुकान 104 + 106'),
                row('धान्य घेतलेली कार्डे', taken, 'आपली कार्डे ज्यांचा व्यवहार झाला'),
                row('शिल्लक कार्डे', expectedRemaining, '$ownCards − $taken', highlight: true, valueColor: const Color(0xFFD63031)),
                row('एकूण व्यवहार (पावत्या)', totalTxn, 'पोर्टलवरील एकूण नोंदी'),
                row('आपल्या कार्डांचे व्यवहार', ownTxn, '$totalTxn − $outTxn'),
                row('आपल्या कार्डांवर जादा पावत्या', extraReceipts, '$ownTxn − $taken',
                    valueColor: extraReceipts > 0 ? Colors.orange.shade800 : Colors.green.shade700),
                row('बाहेरचे व्यवहार', outTxn, 'व्यवहार यादीत, वाटप यादीत नसलेली कार्डे',
                    highlight: true, valueColor: const Color(0xFFE17055)),
                row('बाहेरची वेगळी कार्डे (माणसं)', outCards, 'एकाच कार्डाचे व्यवहार एकत्र',
                    highlight: true, valueColor: const Color(0xFFE17055)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remainingOk
                ? '✅ ताळमेळ जुळला: ॲपची शिल्लक यादी ($appRemaining) = वाटप − घेतलेली ($expectedRemaining)'
                : '⚠️ ॲपची शिल्लक यादी $appRemaining आहे, पण वाटप − घेतलेली = $expectedRemaining — काही कार्डांचे व्यवहार/शिल्लक जुळत नाहीत.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: remainingOk ? Colors.green.shade800 : Colors.orange.shade900,
            ),
          ),
          if (extraReceipts > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ℹ️ $extraReceipts जादा पावत्या म्हणजे काही आपल्या कार्डांवर एकापेक्षा जास्त वेळा धान्य नोंदलं गेलं आहे.',
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOutsidersSection({
    required List<Map<String, dynamic>> rows,
    required String? period,
    required String? shop,
    required ValueChanged<String?> onShopChanged,
    required Future<void> Function(String rc, String currentName) onEditName,
  }) {
    const color = Color(0xFFE17055);
    final uniqueCards = rows.map((r) => _cleanRc(r['ration_card_no'])).toSet().length;
    final wheat = _sumField(rows, 'wheat');
    final rice = _sumField(rows, 'rice');
    final sugar = _sumField(rows, 'sugar');
    final saree = _sumField(rows, 'saree', isTransactionSaree: true);
    final amount = _sumField(rows, 'amount');

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 40),
      const _ColSpec('नाव', 170),
      const _ColSpec('कार्ड क्र.', 125),
      const _ColSpec('दुकान', 55),
      const _ColSpec('स्कीम', 60),
      const _ColSpec('पावती क्र.', 95),
      const _ColSpec('दिनांक', 90),
      const _ColSpec('गहू', 55),
      const _ColSpec('तांदूळ', 60),
      const _ColSpec('साखर', 55),
      const _ColSpec('साडी', 50),
      const _ColSpec('रक्कम', 65),
    ];
    final widths = columns.map((c) => c.width).toList();
    final totalWidth = widths.fold<double>(0, (s, w) => s + w);

    Widget cell(double w, Widget child) => Container(
          width: w,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          alignment: Alignment.centerLeft,
          child: child,
        );

    const cellStyle = TextStyle(fontSize: 11);
    const boldTotalStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8A3B1F));

    Widget headerRow = Container(
      color: color.withOpacity(0.14),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            cell(
              widths[i],
              Text(columns[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );

    Widget dataRow(int i, Map<String, dynamic> r) {
      final rc = _cleanRc(r['ration_card_no']);
      final name = _sanitizeForPdf(r['name']);
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final String cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');

      return Container(
        decoration: BoxDecoration(
          color: i.isEven ? Colors.white : const Color(0xFFFFF7F4),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            cell(widths[0], Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
            cell(
              widths[1],
              InkWell(
                onTap: () => onEditName(rc, name),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name.isEmpty ? 'नाव टाका' : name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: name.isEmpty ? Colors.red.shade400 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 11, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            cell(widths[2], Text(rc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            cell(widths[3], Text(_shopOfRecord(r), style: cellStyle)),
            cell(widths[4], Text(r['scheme']?.toString() ?? '', style: cellStyle)),
            cell(widths[5], Text(r['receipt_no']?.toString() ?? '', style: cellStyle)),
            cell(widths[6], Text(r['txn_date']?.toString() ?? '', style: cellStyle)),
            cell(widths[7], Text(r['wheat']?.toString() ?? '0', style: cellStyle)),
            cell(widths[8], Text(r['rice']?.toString() ?? '0', style: cellStyle)),
            cell(widths[9], Text(r['sugar']?.toString() ?? '0', style: cellStyle)),
            cell(widths[10], Text(cleanSaree, style: cellStyle)),
            cell(widths[11], Text(r['amount']?.toString() ?? '0', style: cellStyle)),
          ],
        ),
      );
    }

    Widget totalsRow = Container(
      color: color.withOpacity(0.12),
      child: Row(
        children: [
          cell(widths[0], const SizedBox.shrink()),
          cell(widths[1], Text('एकूण — $uniqueCards कार्डे', style: boldTotalStyle)),
          cell(widths[2], const SizedBox.shrink()),
          cell(widths[3], const SizedBox.shrink()),
          cell(widths[4], const SizedBox.shrink()),
          cell(widths[5], const SizedBox.shrink()),
          cell(widths[6], const SizedBox.shrink()),
          cell(widths[7], Text(_fmtNum(wheat), style: boldTotalStyle)),
          cell(widths[8], Text(_fmtNum(rice), style: boldTotalStyle)),
          cell(widths[9], Text(_fmtNum(sugar), style: boldTotalStyle)),
          cell(widths[10], Text(_fmtNum(saree), style: boldTotalStyle)),
          cell(widths[11], Text(_fmtNum(amount), style: boldTotalStyle)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_outlined, size: 16, color: color),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'बाहेरचे लाभार्थी (आपल्या दुकानाचे नसलेले)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                ),
              ),
              Text('$uniqueCards कार्डे / ${rows.length} व्यवहार',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'ज्यांचं कार्ड आपल्या वाटप यादीत नाही, पण आपण ज्यांना धान्य दिलं (पोर्टेबिलिटी).',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('दुकान:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  DropdownButton<String?>(
                    value: shop,
                    isDense: true,
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('सर्व दुकाने', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem<String?>(value: '104', child: Text('दुकान क्र. 104', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem<String?>(value: '106', child: Text('दुकान क्र. 106', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: onShopChanged,
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD63031),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: rows.isEmpty ? null : () => _exportOutsidersPdf(rows, period, shop),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                label: const Text('PDF / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('या निवडीसाठी बाहेरचे लाभार्थी सापडले नाहीत.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: totalWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      headerRow,
                      for (int i = 0; i < rows.length; i++) dataRow(i, rows[i]),
                      totalsRow,
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ⭐ नवीन — बाहेरचे लाभार्थी यादीचा PDF (table स्वरूपात, मराठी फॉन्टसह)
  Future<void> _exportOutsidersPdf(
    List<Map<String, dynamic>> rows,
    String? period,
    String? shop,
  ) async {
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Export करण्यासाठी डेटा उपलब्ध नाही.')),
        );
      }
      return;
    }

    final headers = [
      'अ.क्र.', 'नाव', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'पावती',
      'दिनांक', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम',
    ];

    final dataRows = <List<String>>[];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');
      dataRows.add([
        '${i + 1}',
        _sanitizeForPdf(r['name'], fallback: 'नाव उपलब्ध नाही'),
        _cleanRc(r['ration_card_no']),
        _shopOfRecord(r),
        _sanitizeForPdf(r['scheme']),
        _sanitizeForPdf(r['receipt_no']),
        _sanitizeForPdf(r['txn_date']),
        _sanitizeForPdf(r['wheat'], fallback: '0'),
        _sanitizeForPdf(r['rice'], fallback: '0'),
        _sanitizeForPdf(r['sugar'], fallback: '0'),
        _sanitizeForPdf(cleanSaree, fallback: '0'),
        _sanitizeForPdf(r['amount'], fallback: '0'),
      ]);
    }

    final uniqueCards = rows.map((r) => _cleanRc(r['ration_card_no'])).toSet().length;
    final totalWheat = _sumField(rows, 'wheat');
    final totalRice = _sumField(rows, 'rice');
    final totalSugar = _sumField(rows, 'sugar');
    final totalSaree = _sumField(rows, 'saree', isTransactionSaree: true);
    final totalAmount = _sumField(rows, 'amount');

    try {
      final regularFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final ttfRegular = pw.Font.ttf(regularFontData);
      final ttfBold = pw.Font.ttf(boldFontData);

      const headerColor = PdfColor.fromInt(0xFF4A0E4E);
      const stripeColor = PdfColor.fromInt(0xFFF5F1FA);
      const borderColor = PdfColor.fromInt(0xFFD9CFEA);

      final Map<int, pw.TableColumnWidth> colWidths = {
        0: const pw.FlexColumnWidth(0.6),
        1: const pw.FlexColumnWidth(2.6),
        2: const pw.FlexColumnWidth(1.7),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(0.9),
        5: const pw.FlexColumnWidth(1.3),
        6: const pw.FlexColumnWidth(1.4),
        7: const pw.FlexColumnWidth(0.8),
        8: const pw.FlexColumnWidth(0.8),
        9: const pw.FlexColumnWidth(0.8),
        10: const pw.FlexColumnWidth(0.7),
        11: const pw.FlexColumnWidth(0.9),
      };

      final shopText = shop == null ? 'सर्व' : shop;
      final periodText = period ?? 'सर्व';

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          maxPages: 999999999,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('सेवा सहकारी संस्था मर्या. चनई — बाहेरचे लाभार्थी यादी',
                      style: pw.TextStyle(font: ttfBold, fontSize: 15, color: headerColor)),
                  pw.Text('पान ${ctx.pageNumber} / ${ctx.pagesCount}',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.4, color: headerColor),
              pw.SizedBox(height: 6),
              pw.Text(
                'एकूण कार्डे: $uniqueCards   |   एकूण व्यवहार: ${rows.length}   |   दुकान: $shopText   |   महिना: $periodText',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('तयार केले: सेवा सहकारी संस्था मर्या. चनई',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(font: ttfBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey900),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              border: pw.TableBorder.all(color: borderColor, width: 0.4),
              oddRowDecoration: const pw.BoxDecoration(color: stripeColor),
              columnWidths: colWidths,
              cellHeight: 20,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const pw.BoxDecoration(color: stripeColor),
              child: pw.Text(
                'एकूण — $uniqueCards कार्डे, ${rows.length} व्यवहार   |   गहू: ${_fmtNum(totalWheat)}   |   '
                'तांदूळ: ${_fmtNum(totalRice)}   |   साखर: ${_fmtNum(totalSugar)}   |   '
                'साडी: ${_fmtNum(totalSaree)}   |   रक्कम: ${_fmtNum(totalAmount)}',
                style: pw.TextStyle(font: ttfBold, fontSize: 9, color: headerColor),
              ),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'बाहेरचे लाभार्थी PDF सेव्ह करा',
        fileName: 'outsiders_${shop ?? "all"}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.pdf')) savePath = '$savePath.pdf';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ PDF Export यशस्वी: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  Future<void> _showSummaryDialog() async {
    String? dialogPeriod = _selectedPeriod;
    String? dialogShop; // ⭐ बाहेरचे लाभार्थी section साठी दुकान फिल्टर

    Future<Map<String, List<Map<String, dynamic>>>> fetchSummary(String? period) async {
      final allotment = await DatabaseHelper.instance.fetchAllotmentByShop(null, query: '', period: period);
      final transactions = await DatabaseHelper.instance.fetchTransactionsByShop(null, query: '', period: period);
      final remaining = await DatabaseHelper.instance.fetchRemainingRecords(null, period: period, query: '');
      return {
        'allotment': _getFilteredList(allotment),
        'transaction': _getFilteredList(transactions, isTransaction: true),
        'remaining': _getFilteredList(remaining),
        'outsiders': _computeOutsiders(allotment, transactions),
        'recon': [_computeReconciliation(allotment, remaining, transactions)],
        'grain': [_computeGrainSummary(allotment, remaining, transactions)],
        'dups': _computeDuplicateReceipts(allotment, transactions),
      };
    }

    Map<String, List<Map<String, dynamic>>> data = await fetchSummary(dialogPeriod);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final allot = data['allotment'] ?? [];
          final txn = data['transaction'] ?? [];
          final rem = data['remaining'] ?? [];
          final dups = data['dups'] ?? [];
          final grainList = data['grain'] ?? [];
          final Map<String, dynamic> grain = grainList.isNotEmpty ? grainList.first : <String, dynamic>{};
          final reconList = data['recon'] ?? [];
          final Map<String, dynamic> recon = reconList.isNotEmpty ? reconList.first : <String, dynamic>{};
          final outsidersAll = data['outsiders'] ?? [];
          final outsiders = dialogShop == null
              ? outsidersAll
              : outsidersAll.where((r) => _shopOfRecord(r) == dialogShop).toList();
          final dialogWidth = (MediaQuery.of(ctx).size.width * 0.9).clamp(320.0, 920.0).toDouble();

          Widget totalTile(String label, num value, Color color) {
            return Column(
              children: [
                Text(_fmtNum(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            );
          }

          Widget sectionCard(
            String title,
            IconData icon,
            Color color,
            List<Map<String, dynamic>> records, {
            bool isTransaction = false,
          }) {
            final count = records.length;
            final wheat = _sumField(records, 'wheat');
            final rice = _sumField(records, 'rice');
            final sugar = isTransaction ? _sumField(records, 'sugar') : _sumField(records, 'sugar_curr');
            final saree = _sumField(records, 'saree', isTransactionSaree: isTransaction);
            final amount = isTransaction ? _sumField(records, 'amount') : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                      const Spacer(),
                      Text('$count कार्डे/व्यवहार', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      totalTile('गहू', wheat, color),
                      totalTile('तांदूळ', rice, color),
                      totalTile(isTransaction ? 'साखर' : 'साखर(चालू)', sugar, color),
                      totalTile('साडी', saree, color),
                      if (amount != null) totalTile('रक्कम', amount, color),
                    ],
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('एकूण अहवाल (Summary)'),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      value: dialogPeriod,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'महिना निवडा',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('सर्व महिने')),
                        ..._periods.map((p) => DropdownMenuItem<String?>(value: p, child: Text(p))),
                      ],
                      onChanged: (value) async {
                        final newData = await fetchSummary(value);
                        setDialogState(() {
                          dialogPeriod = value;
                          data = newData;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    sectionCard('वाटप (Allotment)', Icons.inventory_2_outlined, const Color(0xFF6C5CE7), allot),
                    sectionCard('व्यवहार (Transaction)', Icons.receipt_long_outlined, const Color(0xFF00B894), txn, isTransaction: true),
                    sectionCard('शिल्लक (Remaining)', Icons.pending_actions_rounded, const Color(0xFFD63031), rem),

                    // ⭐ नवीन — हिशेब पडताळणी table
                    _buildReconciliationSection(
                      recon,
                      onPdf: () => _exportSummaryPdf(recon, grain, dialogPeriod),
                    ),

                    // ⭐ नवीन section — जादा पावत्या (table + PDF)
                    _buildDuplicateReceiptsSection(rows: dups, period: dialogPeriod),

                    // ⭐ नवीन section — बाहेरचे लाभार्थी (table + PDF)
                    _buildOutsidersSection(
                      rows: outsiders,
                      period: dialogPeriod,
                      shop: dialogShop,
                      onShopChanged: (v) => setDialogState(() => dialogShop = v),
                      onEditName: (rc, current) async {
                        await _editNameDialog(rc, current);
                        final newData = await fetchSummary(dialogPeriod);
                        setDialogState(() => data = newData);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
            ],
          );
        },
      ),
    );
  }

  // Diagnostics — एरर आल्यास तो स्क्रीनवरच वेगळ्या डायलॉगमध्ये दाखवला जातो.
  Future<void> _showDiagnostics() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🔍 Diagnostics सुरू — Firestore ला कॉल करतोय...')),
      );
    }
    Map<String, List<Map<String, dynamic>>> data;
    try {
      data = await DatabaseHelper.instance.debugSample(shopNo: _selectedShop);
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Diagnostics — एरर आली'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Text(
                'Firestore मधून डेटा वाचताना खालील एरर आली:\n\n$e',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
          ],
        ),
      );
      return;
    }
    final allot = data['allotment'] ?? [];
    final txn = data['transaction'] ?? [];
    final counts = data['counts']?.first ?? {};

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Diagnostics ${_selectedShop != null ? "(दुकान $_selectedShop)" : "(सर्व दुकाने)"}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'एकूण: allotment=${counts['allotment_total']}, transaction=${counts['transaction_total']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Divider(),
                const Text('वाटप (Allotment) — शेवटचे रेकॉर्ड्स:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                if (allot.isEmpty)
                  const Text('(काहीच नाही)', style: TextStyle(fontSize: 11, fontFamily: 'monospace'))
                else
                  ...allot.map((r) => Text(
                        'shop=[${r['shop_no']}] card=[${r['ration_card_no']}] period=[${r['period']}] wheat=${r['wheat']} rice=${r['rice']}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      )),
                const SizedBox(height: 12),
                const Text('व्यवहार (Transaction) — शेवटचे रेकॉर्ड्स:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                if (txn.isEmpty)
                  const Text('(काहीच नाही)', style: TextStyle(fontSize: 11, fontFamily: 'monospace'))
                else
                  ...txn.map((r) => Text(
                        'shop=[${r['shop_no']}] card=[${r['ration_card_no']}] txn_date=[${r['txn_date']}] amount=${r['amount']}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('बंद करा')),
        ],
      ),
    );
  }

  Future<String?> _askShopNoManually() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('दुकान क्र. निवडा'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'या फाईलसाठी दुकान नंबर निवडा (104 किंवा 106):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'दुकान क्र. (104 / 106)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: ['104', '106'].map((s) {
                return ActionChip(
                  label: Text('दुकान $s'),
                  onPressed: () => controller.text = s,
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('रद्द करा'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('पुढे जा'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPeriodManually() async {
    String? selected;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('महिना (Period) निवडा'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'कृपया या फाईलसाठी योग्य महिना निवडा:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selected,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                hint: const Text('महिना निवडा', style: TextStyle(fontSize: 13)),
                items: {..._defaultPeriods, ..._periods}.toList().map((p) {
                  return DropdownMenuItem<String>(value: p, child: Text(p, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (value) => setDialogState(() => selected = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('रद्द करा'),
            ),
            FilledButton(
              onPressed: selected == null ? null : () => Navigator.pop(ctx, selected),
              child: const Text('पुढे जा'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('सर्व डेटा डिलीट करायचा?'),
        content: const Text(
          'हे डेटाबेसमधील सर्व जुने रेकॉर्ड्स (वाटप + व्यवहार दोन्ही) कायमचे काढून टाकेल.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('रद्द करा')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('डिलीट करा'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.clearAllRecords();
      _lastHtmlHash.clear();
      setState(() {
        _selectedShop = null;
        _selectedPeriod = null;
      });
      await _loadPeriods();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सर्व डेटा साफ केला.')),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    final tabIdx = _tabController.index;
    final filteredAllotment = _getFilteredList(_allotmentRecords);
    final filteredTransactions = _getFilteredList(_transactionRecords, isTransaction: true);
    final filteredRemaining = _getFilteredList(_remainingRecords);

    List<List<dynamic>> rows = [];

    if (tabIdx == 0) {
      rows.add(['अ.क्र.', 'कुटुंब प्रमुखाचे नाव', 'मोबाईल', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'युनिट्स', 'कालावधी', 'गहू', 'तांदूळ', 'साखर(चालू)', 'साखर(मागील)', 'साडी']);
      for (int i = 0; i < filteredAllotment.length; i++) {
        final r = filteredAllotment[i];
        rows.add([
          i + 1, r['name'], r['mobile'], r['ration_card_no'], r['shop_no'], r['scheme'], r['units'], r['period'],
          r['wheat'], r['rice'], r['sugar_curr'], r['sugar_prev'], r['saree'],
        ]);
      }
    } else if (tabIdx == 1) {
      rows.add(['अ.क्र.', 'कुटुंब प्रमुखाचे नाव', 'मोबाईल', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'युनिट्स', 'कालावधी', 'गहू', 'तांदूळ', 'साखर(चालू)', 'साखर(मागील)', 'साडी']);
      for (int i = 0; i < filteredRemaining.length; i++) {
        final r = filteredRemaining[i];
        rows.add([
          i + 1, r['name'], r['mobile'], r['ration_card_no'], r['shop_no'], r['scheme'], r['units'], r['period'],
          r['wheat'], r['rice'], r['sugar_curr'], r['sugar_prev'], r['saree'],
        ]);
      }
    } else if (tabIdx == 4) {
      final dupRows = _visibleDups();
      rows.add(['अ.क्र.', 'नाव', 'कार्ड क्र.', 'पावती', 'दुकान', 'स्कीम', 'प्रकार', 'पावती क्र.', 'दिनांक', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम', 'पोर्टेबिलिटी', 'स्टेटस']);
      for (int i = 0; i < dupRows.length; i++) {
        final r = dupRows[i];
        final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
        final cleanSaree = (rawSaree > 10) ? 0 : (r['saree'] ?? 0);
        rows.add([
          i + 1, r['name'], r['_rc'], '${r['_seq']}/${r['_cnt']}', _shopOfRecord(r), r['scheme'], r['avail_type'], r['receipt_no'], r['txn_date'],
          r['wheat'], r['rice'], r['sugar'], cleanSaree, r['amount'], r['portability'], r['status'],
        ]);
      }
    } else if (tabIdx == 3) {
      final outs = _visibleOutsiders();
      rows.add(['अ.क्र.', 'नाव', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'पावती क्र.', 'दिनांक', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम']);
      for (int i = 0; i < outs.length; i++) {
        final r = outs[i];
        final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
        final cleanSaree = (rawSaree > 10) ? 0 : (r['saree'] ?? 0);
        rows.add([
          i + 1, r['name'], _cleanRc(r['ration_card_no']), _shopOfRecord(r), r['scheme'], r['receipt_no'], r['txn_date'],
          r['wheat'], r['rice'], r['sugar'], cleanSaree, r['amount'],
        ]);
      }
    } else {
      rows.add(['अ.क्र.', 'कुटुंब प्रमुखाचे नाव', 'मोबाईल', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'प्रकार', 'पावती क्र.', 'दिनांक', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम', 'पोर्टेबिलिटी', 'वेळ', 'स्टेटस']);
      for (int i = 0; i < filteredTransactions.length; i++) {
        final r = filteredTransactions[i];
        final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
        final cleanSaree = (rawSaree > 10) ? 0 : (r['saree'] ?? 0);

        rows.add([
          i + 1, r['name'], r['mobile'], r['ration_card_no'], r['shop_no'], r['scheme'], r['avail_type'], r['receipt_no'], r['txn_date'],
          r['wheat'], r['rice'], r['sugar'], cleanSaree, r['amount'],
          r['portability'], r['auth_time'], r['status'],
        ]);
      }
    }

    if (rows.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export करण्यासाठी डेटा उपलब्ध नाही.')),
        );
      }
      return;
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final defaultName = tabIdx == 0
        ? 'allotment_export.csv'
        : (tabIdx == 1
            ? 'remaining_export.csv'
            : (tabIdx == 3 ? 'outsiders_export.csv' : (tabIdx == 4 ? 'extra_receipts_export.csv' : 'transaction_export.csv')));

    try {
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'CSV सेव्ह करा',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.csv')) {
          savePath = '$savePath.csv';
        }
        final file = File(savePath);
        await file.writeAsBytes(utf8.encode('\uFEFF$csvData'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Export यशस्वी: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  // नाव, मोबाईल इत्यादी PDF मध्ये पाठवण्याआधी साफ करणे
  // (रिकामे/अदृश्य कॅरेक्टर्समुळे PDF फॉन्ट सायलेंटली रिकामं दाखवू शकतो, ते टाळण्यासाठी)
  String _sanitizeForPdf(dynamic raw, {String fallback = ''}) {
    if (raw == null) return fallback;
    String s = raw.toString();
    // BOM, zero-width space/joiner सारखे अदृश्य कॅरेक्टर्स काढणे
    s = s.replaceAll('\uFEFF', '').replaceAll('\u200B', '');
    // कंट्रोल कॅरेक्टर्स काढणे (टॅब/एंटर सोडून)
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    s = s.trim();
    return s.isEmpty ? fallback : s;
  }

  // PDF टेबलसाठी प्रत्येक कॉलमची ठराविक रुंदी (अ.क्र. लहान, नाव मोठं, बाकी मध्यम)
  Map<int, pw.TableColumnWidth> _pdfColumnWidths(int colCount) {
    final Map<int, pw.TableColumnWidth> widths = {};
    for (int i = 0; i < colCount; i++) {
      widths[i] = const pw.FlexColumnWidth(1.4); // डिफॉल्ट रुंदी
    }
    widths[0] = const pw.FlexColumnWidth(0.6); // अ.क्र. — सर्वात लहान
    if (colCount > 1) widths[1] = const pw.FlexColumnWidth(2.4); // नाव — सर्वात मोठं
    if (colCount > 2) widths[2] = const pw.FlexColumnWidth(1.6); // मोबाईल
    if (colCount > 3) widths[3] = const pw.FlexColumnWidth(1.8); // कार्ड क्र.
    return widths;
  }

  // PDF Export फंक्शन (कॉलम-वाईज, मराठी फॉन्टसह, नावं नेहमी दिसतील असं)
  Future<void> _exportPdf() async {
    final tabIdx = _tabController.index;
    // ⭐ जादा पावत्या tab वर असताना त्याचाच PDF
    if (tabIdx == 4) {
      await _exportDuplicateReceiptsPdf(_visibleDups(), _selectedPeriod);
      return;
    }
    // ⭐ बाहेरचे लाभार्थी tab वर असताना त्याचाच PDF
    if (tabIdx == 3) {
      await _exportOutsidersPdf(_visibleOutsiders(), _selectedPeriod, _selectedShop);
      return;
    }
    final filteredAllotment = _getFilteredList(_allotmentRecords);
    final filteredTransactions = _getFilteredList(_transactionRecords, isTransaction: true);
    final filteredRemaining = _getFilteredList(_remainingRecords);

    List<String> headers;
    List<List<String>> dataRows = [];

    if (tabIdx == 0 || tabIdx == 1) {
      final source = tabIdx == 0 ? filteredAllotment : filteredRemaining;
      headers = ['अ.क्र.', 'नाव', 'मोबाईल', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'युनिट्स', 'कालावधी', 'गहू', 'तांदूळ', 'साखर(चा)', 'साखर(मा)', 'साडी'];
      for (int i = 0; i < source.length; i++) {
        final r = source[i];
        dataRows.add([
          '${i + 1}',
          _sanitizeForPdf(r['name'], fallback: 'नाव उपलब्ध नाही'),
          _sanitizeForPdf(r['mobile']),
          _cleanRc(r['ration_card_no']),
          _sanitizeForPdf(r['shop_no']),
          _sanitizeForPdf(r['scheme']),
          _sanitizeForPdf(r['units'], fallback: '0'),
          _sanitizeForPdf(r['period']),
          _sanitizeForPdf(r['wheat'], fallback: '0'),
          _sanitizeForPdf(r['rice'], fallback: '0'),
          _sanitizeForPdf(r['sugar_curr'], fallback: '0'),
          _sanitizeForPdf(r['sugar_prev'], fallback: '0'),
          _sanitizeForPdf(r['saree'], fallback: '0'),
        ]);
      }
    } else {
      headers = ['अ.क्र.', 'नाव', 'मोबाईल', 'कार्ड क्र.', 'दुकान', 'स्कीम', 'प्रकार', 'पावती', 'दिनांक', 'गहू', 'तांदूळ', 'साखर', 'साडी', 'रक्कम', 'स्टेटस'];
      for (int i = 0; i < filteredTransactions.length; i++) {
        final r = filteredTransactions[i];
        final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
        final cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');
        dataRows.add([
          '${i + 1}',
          _sanitizeForPdf(r['name'], fallback: 'नाव उपलब्ध नाही'),
          _sanitizeForPdf(r['mobile']),
          _cleanRc(r['ration_card_no']),
          _sanitizeForPdf(r['shop_no']),
          _sanitizeForPdf(r['scheme']),
          _sanitizeForPdf(r['avail_type']),
          _sanitizeForPdf(r['receipt_no']),
          _sanitizeForPdf(r['txn_date']),
          _sanitizeForPdf(r['wheat'], fallback: '0'),
          _sanitizeForPdf(r['rice'], fallback: '0'),
          _sanitizeForPdf(r['sugar'], fallback: '0'),
          _sanitizeForPdf(cleanSaree, fallback: '0'),
          _sanitizeForPdf(r['amount'], fallback: '0'),
          _sanitizeForPdf(r['status']),
        ]);
      }
    }

    if (dataRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Export करण्यासाठी डेटा उपलब्ध नाही.')),
        );
      }
      return;
    }

    try {
      final regularFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      final ttfRegular = pw.Font.ttf(regularFontData);
      final ttfBold = pw.Font.ttf(boldFontData);

      // ब्रँड कलर्स — टेबल थोडं अधिक स्वच्छ आणि व्यावसायिक दिसावं म्हणून
      const headerColor = PdfColor.fromInt(0xFF4A0E4E); // गडद जांभळा
      const stripeColor = PdfColor.fromInt(0xFFF5F1FA); // हलकी जांभळी झलक
      const borderColor = PdfColor.fromInt(0xFFD9CFEA);

      final doc = pw.Document();
      final title = tabIdx == 0 ? 'वाटप यादी' : (tabIdx == 1 ? 'शिल्लक यादी' : 'व्यवहार यादी');

      doc.addPage(
        pw.MultiPage(
          maxPages: 999999999,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('सेवा सहकारी संस्था मर्या. चनई — $title',
                      style: pw.TextStyle(font: ttfBold, fontSize: 15, color: headerColor)),
                  pw.Text('पान ${ctx.pageNumber} / ${ctx.pagesCount}',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.4, color: headerColor),
              pw.SizedBox(height: 6),
              pw.Text(
                'एकूण नोंदी: ${dataRows.length}   |   दुकान: ${_selectedShop ?? "सर्व"}   |   महिना: ${_selectedPeriod ?? "सर्व"}',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Text('तयार केले: सेवा सहकारी संस्था मर्या. चनई',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey600)),
          ),
          build: (ctx) => [
            pw.Table.fromTextArray(
              headers: headers,
              data: dataRows,
              headerStyle: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: headerColor),
              cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 7.5, color: PdfColors.grey900),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              border: pw.TableBorder.all(color: borderColor, width: 0.4),
              oddRowDecoration: const pw.BoxDecoration(color: stripeColor),
              // प्रत्येक कॉलमला स्वतःची निश्चित रुंदी — शब्द एकमेकांत मिसळणार नाहीत
              columnWidths: _pdfColumnWidths(headers.length),
              cellHeight: 20,
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'PDF सेव्ह करा',
        fileName: tabIdx == 0 ? 'allotment_export.pdf' : (tabIdx == 1 ? 'remaining_export.pdf' : 'transaction_export.pdf'),
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savePath != null) {
        if (!savePath.toLowerCase().endsWith('.pdf')) savePath = '$savePath.pdf';
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ PDF Export यशस्वी: $savePath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export मध्ये अडचण: $e')),
        );
      }
    }
  }

  // ==========================================
  // ⭐ मुख्य Build पद्धत
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    final filteredAllotment = _getFilteredList(_allotmentRecords);
    final filteredTransactions = _getFilteredList(_transactionRecords, isTransaction: true);
    final filteredRemaining = _getFilteredList(_remainingRecords);
    final visibleOutsiders = _visibleOutsiders();
    final visibleDups = _visibleDups();

    final mainContent = Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 16,
        isMobile ? 6 : 14,
        isMobile ? 8 : 16,
        isMobile ? 6 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            _buildHeroBanner(),
            const SizedBox(height: 12),
          ],
          _buildToolbar(isMobile),
          if (_showSmartFilters) ...[
            const SizedBox(height: 8),
            _buildSmartFiltersBar(isMobile),
          ],
          SizedBox(height: isMobile ? 6 : 10),
          _buildMetricsSection(isMobile, filteredAllotment, filteredRemaining, filteredTransactions),
          SizedBox(height: isMobile ? 6 : 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: isMobile,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00B894)]),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade700,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12),
              tabs: [
                Tab(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text('वाटप यादी (${filteredAllotment.length})'),
                    ],
                  ),
                ),
                Tab(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pending_actions_rounded, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text('शिल्लक यादी (${filteredRemaining.length})'),
                    ],
                  ),
                ),
                Tab(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text('व्यवहार यादी (${filteredTransactions.length})'),
                    ],
                  ),
                ),
                Tab(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.groups_2_outlined, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text('बाहेरचे लाभार्थी (${visibleOutsiders.length})'),
                    ],
                  ),
                ),
                Tab(
                  height: isMobile ? 36 : 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.content_copy_rounded, size: isMobile ? 14 : 16),
                      const SizedBox(width: 4),
                      Text('जादा पावत्या (${_dupExtraCount(visibleDups)})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 6 : 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllotmentList(filteredAllotment),
                _buildRemainingList(filteredRemaining),
                _buildTransactionList(filteredTransactions),
                _buildOutsidersList(visibleOutsiders),
                _buildDuplicatesList(visibleDups),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4FA),
        appBar: AppBar(
          title: const Text('सेवा सहकारी संस्था मर्या. चनई', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: _isCardView ? 'टेबल व्ह्यू' : 'कार्ड व्ह्यू',
              icon: Icon(_isCardView ? Icons.table_chart_rounded : Icons.view_agenda_rounded),
              onPressed: () => setState(() => _isCardView = !_isCardView),
            ),
            IconButton(
              tooltip: 'Live Sync',
              icon: Icon(
                Icons.sync_rounded,
                color: _isAutoSyncing ? Colors.amberAccent : Colors.white,
              ),
              onPressed: _showLiveSyncDialog,
            ),
          ],
        ),
        drawer: Drawer(child: _buildSidebar()),
        body: mainContent,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FA),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: mainContent),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A0E4E), Color(0xFF6C5CE7), Color(0xFF00B894)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF6C5CE7).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: const Icon(
              Icons.rice_bowl_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('SMART RATION DISTRIBUTION SYSTEM',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isAutoSyncEnabled ? const Color(0xFF00B894) : Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isAutoSyncing
                            ? '⚡ सिंक चालू आहे...'
                            : (_isAutoSyncEnabled ? '🟢 AUTO-SYNC ON (${_syncIntervalSeconds}s)' : '⏸️ AUTO-SYNC OFF'),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('AEPDS सेवा सहकारी संस्था म. चनई — स्वस्त धान्य दुकान',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                const Text('🌾 पारदर्शक धान्य वाटप • डिजिटल नोंदी • १००% अचूक सार्वजनिक वितरण प्रणाली',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C5CE7),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() => _tabController.index = 0),
                icon: const Icon(Icons.inventory_2_outlined, size: 14),
                label: const Text('वाटप यादी', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B894),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => setState(() => _tabController.index = 1),
                icon: const Icon(Icons.pending_actions_rounded, size: 14),
                label: const Text('शिल्लक यादी', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFFE17055)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rice_bowl_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AEPDS\nRATION TRACKER',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
          _sidebarItem(Icons.dashboard_rounded, 'Household Records', selected: true, closeDrawer: true),
          _sidebarItem(
            Icons.sync_rounded,
            _isAutoSyncing ? 'सिंक होत आहे...' : 'AEPDS Live Sync',
            onTap: _showLiveSyncDialog,
            closeDrawer: true,
          ),
          _sidebarItem(Icons.bug_report_outlined, 'Diagnostics', onTap: _showDiagnostics, closeDrawer: true),
          _sidebarItem(Icons.badge_outlined, 'Master Names Import', onTap: _pickAndImportMasterNames, closeDrawer: true),
          _sidebarItem(Icons.sync_rounded, 'नावं जुळवा (name match)', onTap: _syncNames, closeDrawer: true),
          _sidebarItem(Icons.person_search_outlined, 'Missing Names भरा', onTap: _showMissingNamesDialog, closeDrawer: true),
          _sidebarItem(Icons.summarize_rounded, 'एकूण अहवाल (Summary)', onTap: _showSummaryDialog, closeDrawer: true),
          _sidebarItem(Icons.cleaning_services_outlined, 'डुप्लिकेट साफ करा', onTap: _cleanDuplicatesDialog, closeDrawer: true),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(child: _shopChip('104', '२८१ कार्डे')),
                const SizedBox(width: 8),
                Expanded(child: _shopChip('106', '४८७ कार्डे')),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _shopChip(String shop, String subtitle) {
    final colors = ShopColors.forShop(shop);
    final isSelected = _selectedShop == shop;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedShop = isSelected ? null : shop;
        });
        _loadData();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('दुकान $shop', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {bool selected = false, VoidCallback? onTap, bool closeDrawer = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: selected ? const Border(left: BorderSide(color: Color(0xFF00B894), width: 3)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: Builder(
          builder: (ctx) => ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: Icon(icon, color: selected ? const Color(0xFF55EFC4) : Colors.white70, size: 18),
            title: Text(label, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            onTap: () {
              if (closeDrawer && Scaffold.maybeOf(ctx)?.hasDrawer == true) {
                Navigator.maybePop(ctx);
              }
              if (onTap != null) onTap();
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ⭐ TOOLBAR
  // ==========================================
  Widget _buildToolbar(bool isMobile) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: isMobile ? double.infinity : 280,
          child: TextField(
            // ⭐ बदल: प्रत्येक अक्षराला नाही, टाइप थांबल्यावर (३०० ms) फिल्टर होतं
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _searchQuery = value);
              });
            },
            decoration: InputDecoration(
              hintText: 'नाव किंवा कार्ड नंबर शोधा...',
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6C5CE7), size: 18),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10, horizontal: 10),
            ),
          ),
        ),
        _buildDropdownContainer(
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFFE17055),
          isMobile: isMobile,
          child: DropdownButton<String?>(
            value: _selectedShop,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('सर्व दुकाने', style: TextStyle(fontSize: 12))),
              DropdownMenuItem<String?>(value: '104', child: Text('दुकान क्र. 104', style: TextStyle(fontSize: 12))),
              DropdownMenuItem<String?>(value: '106', child: Text('दुकान क्र. 106', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (value) {
              setState(() => _selectedShop = value);
              _loadData();
            },
          ),
        ),
        _buildDropdownContainer(
          icon: Icons.calendar_month_rounded,
          iconColor: const Color(0xFF0984E3),
          isMobile: isMobile,
          child: DropdownButton<String?>(
            value: _selectedPeriod,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('सर्व महिने', style: TextStyle(fontSize: 12))),
              ..._periods.map((p) => DropdownMenuItem<String?>(
                    value: p,
                    child: Text(p, style: const TextStyle(fontSize: 12)),
                  )),
            ],
            onChanged: (value) {
              setState(() => _selectedPeriod = value);
              _loadData();
            },
          ),
        ),

        // ⚡ LIVE SYNC बटन (लाईव्ह इंडिकेटरसह)
        _gradientButton(
          onPressed: _showLiveSyncDialog,
          icon: _isAutoSyncing ? Icons.hourglass_top_rounded : Icons.sync_rounded,
          label: _isAutoSyncing
              ? 'सिंक होत आहे...'
              : (_isAutoSyncEnabled ? 'Live Sync (Auto)' : 'Live Sync'),
          gradient: _isAutoSyncEnabled
              ? const [Color(0xFF00B894), Color(0xFF00CEC9)]
              : const [Color(0xFF636E72), Color(0xFFB2BEC3)],
          isMobile: isMobile,
        ),

        _gradientButton(
          onPressed: _pickAndImportCsv,
          icon: Icons.upload_file,
          label: 'Import',
          gradient: const [Color(0xFF6C5CE7), Color(0xFF8E7CF7)],
          isMobile: isMobile,
        ),
        _gradientButton(
          onPressed: _exportCsv,
          icon: Icons.download,
          label: 'Export',
          gradient: const [Color(0xFF0984E3), Color(0xFF74B9FF)],
          isMobile: isMobile,
        ),
        _gradientButton(
          onPressed: _exportPdf,
          icon: Icons.picture_as_pdf_rounded,
          label: 'PDF',
          gradient: const [Color(0xFFD63031), Color(0xFFFF7675)],
          isMobile: isMobile,
        ),
        _gradientButton(
          onPressed: () {
            final tabIdx = _tabController.index;
            final records = tabIdx == 0
                ? _getFilteredList(_allotmentRecords)
                : (tabIdx == 1
                    ? _getFilteredList(_remainingRecords)
                    : (tabIdx == 4
                        ? _visibleDups()
                        : (tabIdx == 3 ? _visibleOutsiders() : _getFilteredList(_transactionRecords, isTransaction: true))));
            _sendAllSms(records);
          },
          icon: Icons.forward_to_inbox_rounded,
          label: 'Send All',
          gradient: const [Color(0xFFE17055), Color(0xFFFAB1A0)],
          isMobile: isMobile,
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6C5CE7),
            side: const BorderSide(color: Color(0xFF6C5CE7)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => setState(() => _showSmartFilters = !_showSmartFilters),
          icon: Icon(_showSmartFilters ? Icons.filter_alt_off : Icons.filter_alt, size: 15),
          label: Text(_showSmartFilters ? 'फिल्टर्स लपवा' : 'फिल्टर्स', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: isMobile ? 34 : 38,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _confirmClearAll,
            icon: const Icon(Icons.delete_outline, size: 15),
            label: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartFiltersBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.2)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('स्कीम:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _filterScheme,
                isDense: true,
                items: ['सर्व', 'PHH', 'AAY', 'NPH'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _filterScheme = v ?? 'सर्व'),
              ),
            ],
          ),
          FilterChip(
            label: const Text('🌾 फक्त गहू'),
            selected: _filterOnlyWheat,
            onSelected: (v) => setState(() => _filterOnlyWheat = v),
          ),
          FilterChip(
            label: const Text('🍚 फक्त तांदूळ'),
            selected: _filterOnlyRice,
            onSelected: (v) => setState(() => _filterOnlyRice = v),
          ),
          FilterChip(
            label: const Text('🍬 फक्त साखर'),
            selected: _filterOnlySugar,
            onSelected: (v) => setState(() => _filterOnlySugar = v),
          ),
          FilterChip(
            label: const Text('🥻 फक्त साडी'),
            selected: _filterOnlySaree,
            onSelected: (v) => setState(() => _filterOnlySaree = v),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _filterScheme = 'सर्व';
                _filterOnlyWheat = false;
                _filterOnlyRice = false;
                _filterOnlySugar = false;
                _filterOnlySaree = false;
                _filterUnit = 'सर्व';
              });
            },
            child: const Text('Reset All', style: TextStyle(fontSize: 11, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownContainer({required IconData icon, required Color iconColor, required Widget child, bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: isMobile ? 36 : 40,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 5),
          DropdownButtonHideUnderline(child: child),
        ],
      ),
    );
  }

  Widget _gradientButton({required VoidCallback onPressed, required IconData icon, required String label, required List<Color> gradient, bool isMobile = false}) {
    return Container(
      height: isMobile ? 36 : 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // ⭐ अचूक मेट्रिक कार्ड्स
  // ==========================================
  Widget _buildMetricsSection(
    bool isMobile,
    List<Map<String, dynamic>> allot,
    List<Map<String, dynamic>> rem,
    List<Map<String, dynamic>> txn,
  ) {
    final List<_MetricItem> metrics = [
      _MetricItem(
        title: 'Households',
        value: allot.length.toString(),
        icon: Icons.home_rounded,
        gradient: const [Color(0xFF6C5CE7), Color(0xFF8E7CF7)],
      ),
      _MetricItem(
        title: 'शिल्लक कार्ड',
        value: rem.length.toString(),
        icon: Icons.pending_actions_rounded,
        gradient: const [Color(0xFFD63031), Color(0xFFFF7675)],
      ),
      _MetricItem(
        title: 'दुकान क्र.',
        value: _selectedShop != null ? 'दुकान $_selectedShop' : 'सर्व',
        icon: Icons.storefront_rounded,
        gradient: const [Color(0xFFE17055), Color(0xFFFAB1A0)],
      ),
      _MetricItem(
        title: 'महिना',
        value: _selectedPeriod ?? 'सर्व महिने',
        icon: Icons.calendar_month_rounded,
        gradient: const [Color(0xFF0984E3), Color(0xFF74B9FF)],
      ),
    ];

    if (!isMobile) {
      return Row(
        children: [
          for (int i = 0; i < metrics.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _buildMetricCard(
              title: metrics[i].title,
              value: metrics[i].value,
              icon: metrics[i].icon,
              gradient: metrics[i].gradient,
              isMobile: false,
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard(title: metrics[0].title, value: metrics[0].value, icon: metrics[0].icon, gradient: metrics[0].gradient, isMobile: true),
            const SizedBox(width: 8),
            _buildMetricCard(title: metrics[1].title, value: metrics[1].value, icon: metrics[1].icon, gradient: metrics[1].gradient, isMobile: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildMetricCard(title: metrics[2].title, value: metrics[2].value, icon: metrics[2].icon, gradient: metrics[2].gradient, isMobile: true),
            const SizedBox(width: 8),
            _buildMetricCard(title: metrics[3].title, value: metrics[3].value, icon: metrics[3].icon, gradient: metrics[3].gradient, isMobile: true),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required List<Color> gradient, bool isMobile = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: isMobile ? 9 : 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: isMobile ? 14 : 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isMobile ? 4 : 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: isMobile ? 14 : 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  num _sumField(List<Map<String, dynamic>> records, String field, {bool isTransactionSaree = false}) {
    num total = 0;
    for (final r in records) {
      final v = r[field];
      num val = 0;
      if (v is num) {
        val = v;
      } else {
        val = num.tryParse(v?.toString() ?? '') ?? 0;
      }
      if (isTransactionSaree && val > 10) continue;
      total += val;
    }
    return total;
  }

  String _fmtNum(num n) {
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  // ==========================================
  // ⭐ MOBILE CARD VIEW
  // ==========================================
  Widget _buildMobileRecordCard(Map<String, dynamic> r, Color accentColor, {bool isTransaction = false}) {
    final rc = _cleanRc(r['ration_card_no']);
    final mobile = r['mobile']?.toString().trim() ?? '';
    final hasMobile = mobile.isNotEmpty;
    final shop = r['shop_no']?.toString().trim().endsWith('104') == true ? '104' : '106';

    final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
    final cleanSaree = (isTransaction && rawSaree > 10) ? 0 : (r['saree'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text('दुकान $shop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text(rc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                child: Text(r['scheme']?.toString() ?? 'PHH', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              if (isTransaction)
                Text(r['txn_date']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          _nameCell(rc, r['name']?.toString()),
          const SizedBox(height: 6),
          Row(
            children: [
              _miniBadge('🌾 ${r['wheat'] ?? 0}'),
              const SizedBox(width: 4),
              _miniBadge('🍚 ${r['rice'] ?? 0}'),
              const SizedBox(width: 4),
              _miniBadge('🍬 ${isTransaction ? (r['sugar'] ?? 0) : (r['sugar_curr'] ?? 0)}'),
              const SizedBox(width: 4),
              _miniBadge('🥻 $cleanSaree'),
            ],
          ),
          const Divider(height: 14),
          Row(
            children: [
              const Icon(Icons.phone_android_rounded, size: 15, color: Color(0xFF1565C0)),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => _editMobileDialog(rc, mobile),
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    hasMobile ? mobile : 'नंबर जोडा',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: hasMobile ? const Color(0xFF1565C0) : Colors.grey,
                      fontStyle: hasMobile ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ),
              ),
              if (hasMobile)
                IconButton(
                  icon: const Icon(Icons.call, size: 16, color: Color(0xFF00B894)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _makeCall(mobile),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B894),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _sendSms(r),
                icon: const Icon(Icons.sms_rounded, size: 14),
                label: const Text('SMS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMobileCardListView(List<Map<String, dynamic>> records, Color accentColor, {bool isTransaction = false}) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: records.length,
      itemBuilder: (context, i) => _buildMobileRecordCard(records[i], accentColor, isTransaction: isTransaction),
    );
  }

  // ==========================================
  // ⭐ ४. बाहेरचे लाभार्थी (आपल्या वाटप यादीत नसलेले, पण ज्यांना आपण धान्य दिलं)
  // ==========================================
  Widget _buildOutsidersList(List<Map<String, dynamic>> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReconStrip(_reconData),
        Expanded(child: _buildOutsidersTable(records)),
      ],
    );
  }

  // ⭐ बाहेरचे tab च्या वर — हिशेबाची छोटी table (लेबल / संख्या / सूत्र)
  Widget _buildReconStrip(Map<String, dynamic> m) {
    if (m.isEmpty) return const SizedBox.shrink();
    int v(String k) => (m[k] as int?) ?? 0;

    final ownCards = v('ownCards');
    final taken = v('takenCards');
    final appRemaining = v('appRemaining');
    final totalTxn = v('totalTxn');
    final ownTxn = v('ownTxn');
    final outTxn = v('outTxn');
    final outCards = v('outCards');
    final expectedRemaining = ownCards - taken;
    final extra = ownTxn - taken;
    final ok = expectedRemaining == appRemaining;

    const blue = Color(0xFF0984E3);
    const red = Color(0xFFD63031);
    const orange = Color(0xFFE17055);

    Widget cell(String label, int value, String formula, Color color, {bool tint = false}) {
      return Container(
        width: 128,
        decoration: BoxDecoration(
          color: tint ? color.withOpacity(0.08) : Colors.white,
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              color: color.withOpacity(0.14),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              child: Text(formula,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Text(
              'हिशेब पडताळणी (दोन्ही दुकाने)   ${ok ? "✅ ताळमेळ जुळला" : "⚠️ शिल्लक ॲपमध्ये $appRemaining, हिशेबात $expectedRemaining"}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: ok ? Colors.green.shade800 : Colors.orange.shade900,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cell('वाटप कार्डे', ownCards, 'दुकान 104 + 106', blue),
                  cell('घेतलेली कार्डे', taken, 'व्यवहार असलेली', blue),
                  cell('शिल्लक', expectedRemaining, '$ownCards − $taken', red, tint: true),
                  cell('एकूण व्यवहार', totalTxn, 'पोर्टल नोंदी', blue),
                  cell('आपले व्यवहार', ownTxn, '$totalTxn − $outTxn', blue),
                  cell('जादा पावत्या', extra, '$ownTxn − $taken', extra > 0 ? Colors.orange.shade800 : Colors.green.shade700),
                  cell('बाहेरचे व्यवहार', outTxn, 'वाटप यादीत नाहीत', orange, tint: true),
                  cell('बाहेरची कार्डे', outCards, 'माणसं (वेगळी)', orange, tint: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutsidersTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return _emptyState('बाहेरचे लाभार्थी नाहीत (सर्व व्यवहार आपल्याच कार्डांचे)', Icons.groups_2_outlined);
    }

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile && _isCardView) {
      return _buildMobileCardListView(records, const Color(0xFFE17055), isTransaction: true);
    }

    final totalWheat = _sumField(records, 'wheat');
    final totalRice = _sumField(records, 'rice');
    final totalSugar = _sumField(records, 'sugar');
    final totalSaree = _sumField(records, 'saree', isTransactionSaree: true);
    final totalAmount = _sumField(records, 'amount');
    final uniqueCards = records.map((r) => _cleanRc(r['ration_card_no'])).toSet().length;

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 45),
      const _ColSpec('नाव', 180),
      const _ColSpec('कार्ड क्र.', 130),
      const _ColSpec('दुकान', 65),
      const _ColSpec('स्कीम', 65),
      const _ColSpec('प्रकार', 80),
      const _ColSpec('पावती क्र.', 95),
      const _ColSpec('दिनांक', 95),
      const _ColSpec('गहू', 65),
      const _ColSpec('तांदूळ', 65),
      const _ColSpec('साखर', 65),
      const _ColSpec('साडी', 60),
      const _ColSpec('रक्कम', 75),
      const _ColSpec('पोर्टेबिलिटी', 90),
      const _ColSpec('वेळ', 100),
      const _ColSpec('स्टेटस', 85),
    ];

    final rows = records.asMap().entries.map<List<Widget>>((entry) {
      final i = entry.key;
      final r = entry.value;
      final cleanCard = _cleanRc(r['ration_card_no']);
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final String cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');

      return [
        Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        _nameCell(cleanCard, r['name']?.toString()),
        Text(cleanCard, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(_shopOfRecord(r), style: const TextStyle(fontSize: 11)),
        Text(r['scheme']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['avail_type']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['receipt_no']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['txn_date']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['wheat']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['rice']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(cleanSaree, style: const TextStyle(fontSize: 11)),
        Text(r['amount']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['portability']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['auth_time']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['status']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
      ];
    }).toList();

    final boldTotalStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8A3B1F));

    final totalsRow = <Widget>[
      const SizedBox.shrink(),
      Text('एकूण — $uniqueCards कार्डे', style: boldTotalStyle),
      Text('${records.length} व्यवहार', style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      Text(_fmtNum(totalWheat), style: boldTotalStyle),
      Text(_fmtNum(totalRice), style: boldTotalStyle),
      Text(_fmtNum(totalSugar), style: boldTotalStyle),
      Text(_fmtNum(totalSaree), style: boldTotalStyle),
      Text(_fmtNum(totalAmount), style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];

    return _buildStickyDataTable(
      columns: columns,
      rows: rows,
      headerBackground: const Color(0xFFE17055).withOpacity(0.10),
      hBodyController: _outHController,
      hHeaderController: _outHHeaderController,
      hFooterController: _outHFooterController,
      vController: _outVController,
      totalsRow: totalsRow,
      totalsBackground: const Color(0xFFE17055).withOpacity(0.14),
    );
  }

  // ==========================================
  // ⭐ ५. जादा पावत्या (आपल्याच कार्डांवर एकापेक्षा जास्त पावत्या) — कोण-कोणती कार्डे ते इथे दिसतं
  // ==========================================
  Widget _buildDuplicatesList(List<Map<String, dynamic>> records) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReconStrip(_reconData),
        Expanded(child: _buildDuplicatesTable(records)),
      ],
    );
  }

  Widget _buildDuplicatesTable(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return _emptyState('कोणत्याही कार्डावर जादा पावती नाही', Icons.check_circle_outline);
    }

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile && _isCardView) {
      return _buildMobileCardListView(records, const Color(0xFFE67E22), isTransaction: true);
    }

    final cardCount = records.map((r) => (r['_rc'] ?? '').toString()).toSet().length;
    final totalWheat = _sumField(records, 'wheat');
    final totalRice = _sumField(records, 'rice');
    final totalSugar = _sumField(records, 'sugar');
    final totalSaree = _sumField(records, 'saree', isTransactionSaree: true);
    final totalAmount = _sumField(records, 'amount');

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 45),
      const _ColSpec('नाव', 180),
      const _ColSpec('कार्ड क्र.', 130),
      const _ColSpec('पावती', 65),
      const _ColSpec('दुकान', 65),
      const _ColSpec('स्कीम', 65),
      const _ColSpec('प्रकार', 90),
      const _ColSpec('पावती क्र.', 160),
      const _ColSpec('दिनांक / वेळ', 130),
      const _ColSpec('गहू', 65),
      const _ColSpec('तांदूळ', 65),
      const _ColSpec('साखर', 65),
      const _ColSpec('साडी', 60),
      const _ColSpec('रक्कम', 75),
      const _ColSpec('पोर्टेबिलिटी', 90),
      const _ColSpec('स्टेटस', 85),
    ];

    final rows = records.asMap().entries.map<List<Widget>>((entry) {
      final i = entry.key;
      final r = entry.value;
      final rc = (r['_rc'] ?? '').toString();
      final seq = (r['_seq'] ?? 1).toString();
      final cnt = (r['_cnt'] ?? 1).toString();
      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final String cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');

      return [
        Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        _nameCell(rc, r['name']?.toString()),
        Text(rc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text('$seq / $cnt', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE67E22))),
        Text(_shopOfRecord(r), style: const TextStyle(fontSize: 11)),
        Text(r['scheme']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['avail_type']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['receipt_no']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['txn_date']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['wheat']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['rice']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(cleanSaree, style: const TextStyle(fontSize: 11)),
        Text(r['amount']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['portability']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['status']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
      ];
    }).toList();

    final boldTotalStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9A5310));

    final totalsRow = <Widget>[
      const SizedBox.shrink(),
      Text('एकूण — $cardCount कार्डे', style: boldTotalStyle),
      Text('${records.length} पावत्या', style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      Text(_fmtNum(totalWheat), style: boldTotalStyle),
      Text(_fmtNum(totalRice), style: boldTotalStyle),
      Text(_fmtNum(totalSugar), style: boldTotalStyle),
      Text(_fmtNum(totalSaree), style: boldTotalStyle),
      Text(_fmtNum(totalAmount), style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];

    return _buildStickyDataTable(
      columns: columns,
      rows: rows,
      headerBackground: const Color(0xFFE67E22).withOpacity(0.12),
      hBodyController: _dupHController,
      hHeaderController: _dupHHeaderController,
      hFooterController: _dupHFooterController,
      vController: _dupVController,
      totalsRow: totalsRow,
      totalsBackground: const Color(0xFFE67E22).withOpacity(0.16),
    );
  }

  // ==========================================
  // ⭐ STICKY-HEADER TABLE
  // ==========================================
  Widget _buildStickyDataTable({
    required List<_ColSpec> columns,
    required List<List<Widget>> rows,
    required Color headerBackground,
    required ScrollController hBodyController,
    required ScrollController hHeaderController,
    required ScrollController hFooterController,
    required ScrollController vController,
    List<Widget>? totalsRow,
    Color? totalsBackground,
  }) {
    final totalWidth = columns.fold<double>(0, (sum, c) => sum + c.width);

    return SelectionArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                color: headerBackground,
                child: SingleChildScrollView(
                  controller: hHeaderController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalWidth,
                    child: Row(
                      children: columns.map((c) {
                        return InkWell(
                          onTap: c.sortKey != null ? () => _toggleSort(c.sortKey!) : null,
                          child: Container(
                            width: c.width,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: c.labelColor ?? Colors.black87,
                                    ),
                                  ),
                                ),
                                if (c.sortKey != null && _sortColumn == c.sortKey)
                                  Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: Colors.black54),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade300),
              Expanded(
                child: Scrollbar(
                  controller: hBodyController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: hBodyController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    child: SizedBox(
                      width: totalWidth,
                      child: ListView.builder(
                        controller: vController,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: rows.length,
                        itemBuilder: (context, rowIdx) {
                          final cells = rows[rowIdx];
                          return Container(
                            decoration: BoxDecoration(
                              color: rowIdx.isEven ? Colors.white : const Color(0xFFFAFAFC),
                              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                            ),
                            child: Row(
                              children: List.generate(columns.length, (i) {
                                return Container(
                                  width: columns[i].width,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  alignment: Alignment.centerLeft,
                                  child: cells[i],
                                );
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (totalsRow != null) ...[
                Divider(height: 1, color: Colors.grey.shade300),
                Container(
                  color: totalsBackground ?? const Color(0xFFF3F1FE),
                  child: SingleChildScrollView(
                    controller: hFooterController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: totalWidth,
                      child: Row(
                        children: List.generate(columns.length, (i) {
                          return Container(
                            width: columns[i].width,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            alignment: Alignment.centerLeft,
                            child: totalsRow[i],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // १. वाटप यादी (Allotment)
  // ==========================================
  Widget _buildAllotmentList(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return _emptyState('वाटप यादीत डेटा नाही', Icons.inventory_2_outlined);

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile && _isCardView) {
      return _buildMobileCardListView(records, const Color(0xFF6C5CE7));
    }

    final totalUnits = _sumField(records, 'units');
    final totalWheat = _sumField(records, 'wheat');
    final totalRice = _sumField(records, 'rice');
    final totalSugarCurr = _sumField(records, 'sugar_curr');
    final totalSugarPrev = _sumField(records, 'sugar_prev');
    final totalSaree = _sumField(records, 'saree');

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 45),
      const _ColSpec('कुटुंब प्रमुखाचे नाव', 180, sortKey: 'name'),
      const _ColSpec('मोबाईल', 115),
      const _ColSpec('SMS', 55),
      const _ColSpec('कार्ड क्र.', 140),
      const _ColSpec('दुकान', 65),
      const _ColSpec('स्कीम', 65),
      const _ColSpec('युनिट्स', 65, sortKey: 'units'),
      const _ColSpec('कालावधी', 120),
      const _ColSpec('गहू', 60, sortKey: 'wheat'),
      const _ColSpec('तांदूळ', 60, sortKey: 'rice'),
      const _ColSpec('साखर(चालू)', 85),
      const _ColSpec('साखर(मागील)', 85),
      const _ColSpec('साडी', 55),
    ];

    final rows = records.asMap().entries.map<List<Widget>>((entry) {
      final i = entry.key;
      final r = entry.value;
      final shop = r['shop_no']?.toString().trim().endsWith('104') == true ? '104' : '106';
      final cleanCard = _cleanRc(r['ration_card_no']);

      return [
        Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        _nameCell(cleanCard, r['name']?.toString()),
        _mobileCell(cleanCard, r['mobile']?.toString()),
        _smsButtonCell(r),
        Text(cleanCard, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(shop, style: const TextStyle(fontSize: 11)),
        Text(r['scheme']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['units']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['period']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['wheat']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['rice']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar_curr']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar_prev']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['saree']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
      ];
    }).toList();

    final boldTotalStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A0E4E));

    final totalsRow = <Widget>[
      const SizedBox.shrink(),
      Text('एकूण — ${records.length} कार्डे', style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      Text(_fmtNum(totalUnits), style: boldTotalStyle),
      const SizedBox.shrink(),
      Text(_fmtNum(totalWheat), style: boldTotalStyle),
      Text(_fmtNum(totalRice), style: boldTotalStyle),
      Text(_fmtNum(totalSugarCurr), style: boldTotalStyle),
      Text(_fmtNum(totalSugarPrev), style: boldTotalStyle),
      Text(_fmtNum(totalSaree), style: boldTotalStyle),
    ];

    return _buildStickyDataTable(
      columns: columns,
      rows: rows,
      headerBackground: const Color(0xFF6C5CE7).withOpacity(0.08),
      hBodyController: _allotHController,
      hHeaderController: _allotHHeaderController,
      hFooterController: _allotHFooterController,
      vController: _allotVController,
      totalsRow: totalsRow,
      totalsBackground: const Color(0xFF6C5CE7).withOpacity(0.12),
    );
  }

  // ==========================================
  // २. शिल्लक यादी (Remaining)
  // ==========================================
  Widget _buildRemainingList(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return _emptyState('कोणतीही शिल्लक कार्डे नाहीत (सर्व वाटप पूर्ण)', Icons.check_circle_outline);

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile && _isCardView) {
      return _buildMobileCardListView(records, const Color(0xFFD63031));
    }

    final totalUnits = _sumField(records, 'units');
    final totalWheat = _sumField(records, 'wheat');
    final totalRice = _sumField(records, 'rice');
    final totalSugarCurr = _sumField(records, 'sugar_curr');
    final totalSugarPrev = _sumField(records, 'sugar_prev');
    final totalSaree = _sumField(records, 'saree');

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 45),
      const _ColSpec('कुटुंब प्रमुखाचे नाव', 180, sortKey: 'name'),
      const _ColSpec('मोबाईल', 115),
      const _ColSpec('SMS', 55),
      const _ColSpec('कार्ड क्र. (बाकी)', 140, labelColor: Colors.red),
      const _ColSpec('दुकान', 65),
      const _ColSpec('स्कीम', 65),
      const _ColSpec('युनिट्स', 65, sortKey: 'units'),
      const _ColSpec('कालावधी', 120),
      const _ColSpec('गहू', 60, sortKey: 'wheat'),
      const _ColSpec('तांदूळ', 60, sortKey: 'rice'),
      const _ColSpec('साखर(चालू)', 85),
      const _ColSpec('साखर(मागील)', 85),
      const _ColSpec('साडी', 55),
    ];

    final rows = records.asMap().entries.map<List<Widget>>((entry) {
      final i = entry.key;
      final r = entry.value;
      final shop = r['shop_no']?.toString().trim().endsWith('104') == true ? '104' : '106';
      final cleanCard = _cleanRc(r['ration_card_no']);

      return [
        Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        _nameCell(cleanCard, r['name']?.toString()),
        _mobileCell(cleanCard, r['mobile']?.toString()),
        _smsButtonCell(r),
        Text(cleanCard, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
        Text(shop, style: const TextStyle(fontSize: 11)),
        Text(r['scheme']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['units']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['period']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['wheat']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['rice']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar_curr']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar_prev']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['saree']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
      ];
    }).toList();

    final boldTotalStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9E1B1B));

    final totalsRow = <Widget>[
      const SizedBox.shrink(),
      Text('एकूण — ${records.length} बाकी कार्डे', style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      Text(_fmtNum(totalUnits), style: boldTotalStyle),
      const SizedBox.shrink(),
      Text(_fmtNum(totalWheat), style: boldTotalStyle),
      Text(_fmtNum(totalRice), style: boldTotalStyle),
      Text(_fmtNum(totalSugarCurr), style: boldTotalStyle),
      Text(_fmtNum(totalSugarPrev), style: boldTotalStyle),
      Text(_fmtNum(totalSaree), style: boldTotalStyle),
    ];

    return _buildStickyDataTable(
      columns: columns,
      rows: rows,
      headerBackground: const Color(0xFFD63031).withOpacity(0.08),
      hBodyController: _remHController,
      hHeaderController: _remHHeaderController,
      hFooterController: _remHFooterController,
      vController: _remVController,
      totalsRow: totalsRow,
      totalsBackground: const Color(0xFFD63031).withOpacity(0.10),
    );
  }

  // ==========================================
  // ३. व्यवहार यादी (Transaction)
  // ==========================================
  Widget _buildTransactionList(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return _emptyState('व्यवहार यादीत डेटा नाही', Icons.receipt_long_outlined);

    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile && _isCardView) {
      return _buildMobileCardListView(records, const Color(0xFF00B894), isTransaction: true);
    }

    final totalWheat = _sumField(records, 'wheat');
    final totalRice = _sumField(records, 'rice');
    final totalSugar = _sumField(records, 'sugar');
    final totalSaree = _sumField(records, 'saree', isTransactionSaree: true);
    final totalAmount = _sumField(records, 'amount');

    final columns = <_ColSpec>[
      const _ColSpec('अ.क्र.', 45),
      const _ColSpec('कुटुंब प्रमुखाचे नाव', 170, sortKey: 'name'),
      const _ColSpec('मोबाईल', 115),
      const _ColSpec('SMS', 55),
      const _ColSpec('कार्ड क्र.', 130),
      const _ColSpec('दुकान', 65),
      const _ColSpec('स्कीम', 65),
      const _ColSpec('प्रकार', 80),
      const _ColSpec('पावती क्र.', 95),
      const _ColSpec('दिनांक', 95),
      const _ColSpec('गहू', 65, sortKey: 'wheat'),
      const _ColSpec('तांदूळ', 65, sortKey: 'rice'),
      const _ColSpec('साखर', 65),
      const _ColSpec('साडी', 60),
      const _ColSpec('रक्कम', 75),
      const _ColSpec('पोर्टेबिलिटी', 90),
      const _ColSpec('वेळ', 100),
      const _ColSpec('स्टेटस', 85),
    ];

    final rows = records.asMap().entries.map<List<Widget>>((entry) {
      final i = entry.key;
      final r = entry.value;
      final shop = r['shop_no']?.toString().trim().endsWith('104') == true ? '104' : '106';
      final cleanCard = _cleanRc(r['ration_card_no']);

      final num rawSaree = num.tryParse(r['saree']?.toString() ?? '') ?? 0;
      final String cleanSaree = (rawSaree > 10) ? '0' : (r['saree']?.toString() ?? '0');

      return [
        Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        _nameCell(cleanCard, r['name']?.toString()),
        _mobileCell(cleanCard, r['mobile']?.toString()),
        _smsButtonCell(r),
        Text(cleanCard, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(shop, style: const TextStyle(fontSize: 11)),
        Text(r['scheme']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['avail_type']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['receipt_no']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['txn_date']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['wheat']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['rice']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['sugar']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(cleanSaree, style: const TextStyle(fontSize: 11)),
        Text(r['amount']?.toString() ?? '0', style: const TextStyle(fontSize: 11)),
        Text(r['portability']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['auth_time']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
        Text(r['status']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
      ];
    }).toList();

    final boldTotalStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00694A));

    final totalsRow = <Widget>[
      const SizedBox.shrink(),
      Text('एकूण — ${records.length} व्यवहार', style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      Text(_fmtNum(totalWheat), style: boldTotalStyle),
      Text(_fmtNum(totalRice), style: boldTotalStyle),
      Text(_fmtNum(totalSugar), style: boldTotalStyle),
      Text(_fmtNum(totalSaree), style: boldTotalStyle),
      Text(_fmtNum(totalAmount), style: boldTotalStyle),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
      const SizedBox.shrink(),
    ];

    return _buildStickyDataTable(
      columns: columns,
      rows: rows,
      headerBackground: const Color(0xFF00B894).withOpacity(0.08),
      hBodyController: _txnHController,
      hHeaderController: _txnHHeaderController,
      hFooterController: _txnHFooterController,
      vController: _txnVController,
      totalsRow: totalsRow,
      totalsBackground: const Color(0xFF00B894).withOpacity(0.12),
    );
  }
}