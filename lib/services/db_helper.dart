import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';

// ---------------------------------------------------------------------
// ⭐ Firestore च्या एका WriteBatch मध्ये जास्तीत जास्त ५०० ops चालतात.
// हा छोटा helper ४०० झाल्यावर आपोआप commit करून नवा batch सुरू करतो,
// म्हणजे कितीही मोठ्या डिलीट/अपडेटला "too many writes" एरर येत नाही.
// ---------------------------------------------------------------------
class _BatchWriter {
  _BatchWriter(FirebaseFirestore db)
      : _db = db,
        _batch = db.batch();

  final FirebaseFirestore _db;
  WriteBatch _batch;
  int _ops = 0;

  Future<void> _flushIfFull() async {
    if (_ops >= 400) {
      await _batch.commit();
      _batch = _db.batch();
      _ops = 0;
    }
  }

  Future<void> set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) async {
    _batch.set(ref, data, options);
    _ops++;
    await _flushIfFull();
  }

  Future<void> update(DocumentReference ref, Map<String, dynamic> data) async {
    _batch.update(ref, data);
    _ops++;
    await _flushIfFull();
  }

  Future<void> delete(DocumentReference ref) async {
    _batch.delete(ref);
    _ops++;
    await _flushIfFull();
  }

  Future<void> commit() async {
    if (_ops > 0) {
      await _batch.commit();
      _batch = _db.batch();
      _ops = 0;
    }
  }
}

// ---------------------------------------------------------------------
// ⭐ डुप्लिकेट साफ करण्याची योजना — आधी फक्त मोजतो, यूजरने OK म्हटल्यावरच डिलीट करतो
// ---------------------------------------------------------------------
class DuplicatePlan {
  final List<DocumentReference> allotmentRefs;
  final List<DocumentReference> transactionRefs;
  DuplicatePlan(this.allotmentRefs, this.transactionRefs);

  int get allotmentCount => allotmentRefs.length;
  int get transactionCount => transactionRefs.length;
  bool get isEmpty => allotmentRefs.isEmpty && transactionRefs.isEmpty;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _allotmentCol => _db.collection('allotment_records');
  CollectionReference get _transactionCol => _db.collection('transaction_records');
  CollectionReference get _masterNamesCol => _db.collection('master_names');

  // =====================================================================
  // ⭐ CACHE — आधी प्रत्येक स्क्रीन-लोडला ५-६ वेळा संपूर्ण collection वाचली जायची.
  // आता allotment आणि transaction प्रत्येकी एकदाच वाचली जाते आणि २ मिनिटं
  // (किंवा काही बदल/import होईपर्यंत) मेमरीमध्ये ठेवली जाते. दुकान/महिना/सर्च
  // बदलले तर फिल्टर मेमरीमध्येच होतं — नेटवर्क कॉल शून्य.
  // =====================================================================
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<List<Map<String, dynamic>>>? _allotCache;
  DateTime? _allotCacheAt;
  Future<List<Map<String, dynamic>>>? _txnCache;
  DateTime? _txnCacheAt;

  bool _isFresh(DateTime? at) => at != null && DateTime.now().difference(at) < _cacheTtl;

  void invalidateCache() {
    _allotCache = null;
    _allotCacheAt = null;
    _txnCache = null;
    _txnCacheAt = null;
  }

  Future<List<Map<String, dynamic>>> _readAll(CollectionReference col) async {
    final snap = await col.get();
    return snap.docs.map((d) {
      final m = Map<String, dynamic>.from(d.data() as Map);
      m['id'] = d.id;
      return m;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _allotAll({bool force = false}) {
    if (!force && _allotCache != null && _isFresh(_allotCacheAt)) return _allotCache!;
    final f = _readAll(_allotmentCol);
    _allotCache = f;
    _allotCacheAt = DateTime.now();
    f.catchError((Object _) {
      if (identical(_allotCache, f)) {
        _allotCache = null;
        _allotCacheAt = null;
      }
      return <Map<String, dynamic>>[];
    });
    return f;
  }

  Future<List<Map<String, dynamic>>> _txnAll({bool force = false}) {
    if (!force && _txnCache != null && _isFresh(_txnCacheAt)) return _txnCache!;
    final f = _readAll(_transactionCol);
    _txnCache = f;
    _txnCacheAt = DateTime.now();
    f.catchError((Object _) {
      if (identical(_txnCache, f)) {
        _txnCache = null;
        _txnCacheAt = null;
      }
      return <Map<String, dynamic>>[];
    });
    return f;
  }

  // नाव/मोबाईल बदलल्यावर संपूर्ण cache पुन्हा न वाचता, मेमरीमधले तेच कार्ड अपडेट करतो
  Future<void> _patchCache(String rc, Map<String, dynamic> fields) async {
    for (final f in [_allotCache, _txnCache]) {
      if (f == null) continue;
      try {
        final rows = await f;
        for (final r in rows) {
          if ((r['ration_card_no']?.toString().trim() ?? '') == rc) {
            r.addAll(fields);
          }
        }
      } catch (_) {}
    }
  }

  // =====================================================================
  // ⭐ KEYS — डुप्लिकेट ओळखण्यासाठी आणि Firestore document ID ठरवण्यासाठी
  // =====================================================================
  String _allotKey(String shop, String period, String rc) => '${shop}_${period}_$rc';

  String _txnKey(String shop, String rc, String receipt, String txnDate) {
    final r = receipt.trim();
    return r.isNotEmpty ? '${shop}_$r' : '${shop}_${rc}_${txnDate.trim()}';
  }

  // Firestore document ID मध्ये '/' आणि स्पेस चालत नाहीत
  String _docId(String key) => key.replaceAll(RegExp(r'[\/\s]+'), '_');

  Future<Set<String>> _knownTxnKeys() async {
    final all = await _txnAll();
    final keys = <String>{};
    for (final r in all) {
      keys.add(_txnKey(
        r['shop_no']?.toString().trim() ?? '',
        r['ration_card_no']?.toString().trim() ?? '',
        r['receipt_no']?.toString() ?? '',
        r['txn_date']?.toString() ?? '',
      ));
    }
    return keys;
  }

  // ---------------------------------------------------------------------
  // FETCH: Allotment records
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchAllotmentByShop(String? shopNo, {String query = '', String? period}) async {
    final all = await _allotAll();
    final shop = shopNo?.trim() ?? '';
    final per = period?.trim() ?? '';

    Iterable<Map<String, dynamic>> rows = all;
    if (shop.isNotEmpty) {
      rows = rows.where((r) => (r['shop_no']?.toString().trim() ?? '') == shop);
    }
    if (per.isNotEmpty) {
      rows = rows.where((r) => (r['period']?.toString().trim() ?? '') == per);
    }
    if (query.isNotEmpty) {
      final ql = query.toLowerCase();
      rows = rows.where((r) {
        final rc = (r['ration_card_no']?.toString() ?? '').toLowerCase();
        final name = (r['name']?.toString() ?? '').toLowerCase();
        return rc.contains(ql) || name.contains(ql);
      });
    }
    return rows.toList();
  }

  // ---------------------------------------------------------------------
  // FETCH: Transaction records
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchTransactionsByShop(String? shopNo, {String query = '', String? period}) async {
    final all = await _txnAll();
    final shop = shopNo?.trim() ?? '';

    Iterable<Map<String, dynamic>> it = all;
    if (shop.isNotEmpty) {
      it = it.where((r) => (r['shop_no']?.toString().trim() ?? '') == shop);
    }
    var rows = it.toList();

    if (query.isNotEmpty) {
      final ql = query.toLowerCase();
      rows = rows.where((r) {
        final rc = (r['ration_card_no']?.toString() ?? '').toLowerCase();
        final receipt = (r['receipt_no']?.toString() ?? '').toLowerCase();
        final name = (r['name']?.toString() ?? '').toLowerCase();
        return rc.contains(ql) || receipt.contains(ql) || name.contains(ql);
      }).toList();
    }

    if (period != null && period.trim().isNotEmpty) {
      final target = period.trim();
      rows = rows.where((r) {
        final p = _periodFromDateString(r['txn_date']?.toString() ?? '');
        return p == target;
      }).toList();
    }

    rows.sort((a, b) => (b['txn_date']?.toString() ?? '').compareTo(a['txn_date']?.toString() ?? ''));
    return rows;
  }

  // ---------------------------------------------------------------------
  // शिल्लक (Remaining) records
  // ---------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchRemainingRecords(String? shopNo, {String? period, String query = ''}) async {
    final txnRows = await _txnAll();

    final Set<String> txnCards;
    if (period != null && period.trim().isNotEmpty) {
      final target = period.trim();
      txnCards = txnRows
          .where((t) => _periodFromDateString(t['txn_date']?.toString() ?? '') == target)
          .map((t) => t['ration_card_no']?.toString().trim() ?? '')
          .toSet();
    } else {
      txnCards = txnRows.map((t) => t['ration_card_no']?.toString().trim() ?? '').toSet();
    }

    final allAllotments = await fetchAllotmentByShop(shopNo, query: query, period: period);

    final remaining = <Map<String, dynamic>>[];
    for (final row in allAllotments) {
      final rc = row['ration_card_no']?.toString().trim() ?? '';
      if (!txnCards.contains(rc)) {
        remaining.add(row);
      }
    }
    return remaining;
  }

  // ---------------------------------------------------------------------
  Future<List<String>> fetchShopNumbers() async {
    final aRows = await _allotAll();
    final tRows = await _txnAll();
    final shops = <String>{};
    for (final r in aRows) {
      final s = r['shop_no']?.toString().trim();
      if (s != null && s.isNotEmpty) shops.add(s);
    }
    for (final r in tRows) {
      final s = r['shop_no']?.toString().trim();
      if (s != null && s.isNotEmpty) shops.add(s);
    }
    final list = shops.toList();
    list.sort();
    return list;
  }

  Future<List<String>> fetchPeriods() async {
    final rows = await _allotAll();
    final periods = <String>{};
    for (final r in rows) {
      final p = r['period']?.toString().trim();
      if (p != null && p.isNotEmpty) periods.add(p);
    }
    final list = periods.toList();
    list.sort();
    return list;
  }

  Future<int> getHouseholdCount({String? shopNo, String? period}) async {
    final rows = await fetchAllotmentByShop(shopNo, period: period);
    final cards = <String>{};
    for (final r in rows) {
      final rc = r['ration_card_no']?.toString();
      if (rc != null) cards.add(rc);
    }
    return cards.length;
  }

  Future<int> getTotalMembersCount({String? shopNo, String? period}) async {
    final rows = await fetchAllotmentByShop(shopNo, period: period);
    int total = 0;
    for (final r in rows) {
      final v = r['units'];
      if (v is num) {
        total += v.toInt();
      } else {
        total += int.tryParse(v?.toString() ?? '') ?? 0;
      }
    }
    return total;
  }

  // ---------------------------------------------------------------------
  // डिलीट
  // ---------------------------------------------------------------------
  Future<void> clearAllRecords() async {
    final aSnap = await _allotmentCol.get();
    final tSnap = await _transactionCol.get();
    final writer = _BatchWriter(_db);
    for (final d in aSnap.docs) {
      await writer.delete(d.reference);
    }
    for (final d in tSnap.docs) {
      await writer.delete(d.reference);
    }
    await writer.commit();
    invalidateCache();
  }

  // ⭐ फक्त दिलेल्या महिन्याचा (period) डेटा डिलीट करतो; बाकीचे महिने सुरक्षित.
  Future<Map<String, int>> clearRecordsByPeriod(String period, {String? shopNo}) async {
    final target = period.trim();
    if (target.isEmpty) {
      throw ArgumentError('period रिकामं असू शकत नाही — चुकून सगळा डेटा डिलीट होऊ नये म्हणून ही सुरक्षा तपासणी आहे.');
    }

    int allotDeleted = 0;
    int txnDeleted = 0;
    final writer = _BatchWriter(_db);

    Query qa = _allotmentCol.where('period', isEqualTo: target);
    if (shopNo != null && shopNo.trim().isNotEmpty) {
      qa = qa.where('shop_no', isEqualTo: shopNo.trim());
    }
    final aSnap = await qa.get();
    for (final d in aSnap.docs) {
      await writer.delete(d.reference);
      allotDeleted++;
    }

    Query qt = _transactionCol;
    if (shopNo != null && shopNo.trim().isNotEmpty) {
      qt = qt.where('shop_no', isEqualTo: shopNo.trim());
    }
    final tSnap = await qt.get();
    for (final d in tSnap.docs) {
      final data = d.data() as Map;
      final p = _periodFromDateString(data['txn_date']?.toString() ?? '');
      if (p == target) {
        await writer.delete(d.reference);
        txnDeleted++;
      }
    }

    await writer.commit();
    invalidateCache();
    return {'allotment': allotDeleted, 'transaction': txnDeleted};
  }

  // =====================================================================
  // ⭐⭐ डुप्लिकेट साफ करणे (एकदाच चालवायचं)
  // आधीच्या ऑटो-सिंकने Firestore मध्ये तेच व्यवहार पुन्हा पुन्हा साठवले आहेत.
  // findDuplicates() फक्त मोजतो/यादी बनवतो, deleteDuplicates() खरं डिलीट करतो.
  // प्रत्येक गटातलं एक रेकॉर्ड (शक्यतो ज्यात नाव आहे ते) ठेवलं जातं.
  // =====================================================================
  bool _snapHasName(QueryDocumentSnapshot d) {
    final data = d.data() as Map;
    return (data['name']?.toString().trim() ?? '').isNotEmpty;
  }

  Future<DuplicatePlan> findDuplicates() async {
    final aSnap = await _allotmentCol.get();
    final tSnap = await _transactionCol.get();

    final allotRefs = <DocumentReference>[];
    final txnRefs = <DocumentReference>[];

    // --- Allotment: shop + period + rc जुळणारे ---
    final keptA = <String, QueryDocumentSnapshot>{};
    for (final d in aSnap.docs) {
      final data = d.data() as Map;
      final rc = data['ration_card_no']?.toString().trim() ?? '';
      if (rc.isEmpty) continue;
      final key = _allotKey(
        data['shop_no']?.toString().trim() ?? '',
        data['period']?.toString().trim() ?? '',
        rc,
      );
      final kept = keptA[key];
      if (kept == null) {
        keptA[key] = d;
        continue;
      }
      if (!_snapHasName(kept) && _snapHasName(d)) {
        allotRefs.add(kept.reference);
        keptA[key] = d;
      } else {
        allotRefs.add(d.reference);
      }
    }

    // --- Transaction: shop + receipt (किंवा rc + date) जुळणारे ---
    final keptT = <String, QueryDocumentSnapshot>{};
    for (final d in tSnap.docs) {
      final data = d.data() as Map;
      final receipt = data['receipt_no']?.toString().trim() ?? '';
      final date = data['txn_date']?.toString().trim() ?? '';
      // पावती आणि तारीख दोन्ही रिकामे असतील तर ओळखता येत नाही — तसे रेकॉर्ड हात लावत नाही
      if (receipt.isEmpty && date.isEmpty) continue;
      final key = _txnKey(
        data['shop_no']?.toString().trim() ?? '',
        data['ration_card_no']?.toString().trim() ?? '',
        receipt,
        date,
      );
      final kept = keptT[key];
      if (kept == null) {
        keptT[key] = d;
        continue;
      }
      if (!_snapHasName(kept) && _snapHasName(d)) {
        txnRefs.add(kept.reference);
        keptT[key] = d;
      } else {
        txnRefs.add(d.reference);
      }
    }

    return DuplicatePlan(allotRefs, txnRefs);
  }

  Future<Map<String, int>> deleteDuplicates(DuplicatePlan plan) async {
    final writer = _BatchWriter(_db);
    for (final ref in plan.allotmentRefs) {
      await writer.delete(ref);
    }
    for (final ref in plan.transactionRefs) {
      await writer.delete(ref);
    }
    await writer.commit();
    invalidateCache();
    return {'allotment': plan.allotmentCount, 'transaction': plan.transactionCount};
  }

  String? _periodFromDateString(String dateStr) {
    final s = dateStr.trim();
    if (s.isEmpty) return null;

    final dmy = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})').firstMatch(s);
    if (dmy != null) {
      final month = int.tryParse(dmy.group(2)!);
      final year = dmy.group(3)!;
      if (month != null && month >= 1 && month <= 12) {
        return '${_monthByNumber[month]} $year';
      }
    }

    final ymd = RegExp(r'^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})').firstMatch(s);
    if (ymd != null) {
      final year = ymd.group(1)!;
      final month = int.tryParse(ymd.group(2)!);
      if (month != null && month >= 1 && month <= 12) {
        return '${_monthByNumber[month]} $year';
      }
    }

    final nameMatch = RegExp(r'([A-Za-z]{3,9})\D{0,3}(\d{4})').firstMatch(s);
    if (nameMatch != null) {
      final m = nameMatch.group(1)!.toLowerCase();
      if (_monthNames.containsKey(m)) {
        return '${_monthNames[m]} ${nameMatch.group(2)}';
      }
    }

    return null;
  }

  Future<Map<String, List<Map<String, dynamic>>>> debugSample({String? shopNo, int limit = 8}) async {
    final aRows = await fetchAllotmentByShop(shopNo);
    final tRows = await fetchTransactionsByShop(shopNo);

    final allot = aRows.take(limit).map((r) => Map<String, dynamic>.from(r)).toList();
    final txn = tRows.take(limit).map((r) => Map<String, dynamic>.from(r)).toList();

    return {
      'allotment': allot,
      'transaction': txn,
      'counts': [
        {'allotment_total': aRows.length, 'transaction_total': tRows.length}
      ],
    };
  }

  double _num(String v) => double.tryParse(v.replaceAll(',', '').trim()) ?? 0.0;

  // ⭐ RC No स्वच्छ करणे — Excel मधला apostrophe, स्पेस, डॅश काढून फक्त अंक ठेवतो.
  String _cleanNumber(String v) {
    var s = v.trim();
    if (s.startsWith("'")) s = s.substring(1).trim();

    final d = double.tryParse(s);
    if (d != null) return d.toInt().toString();

    final digitsOnly = s.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.isNotEmpty ? digitsOnly : s;
  }

  // ⭐ मोबाईल नंबर स्वच्छ करा — फक्त अंक; +91/0 असल्यास शेवटचे 10 अंक.
  String _cleanMobile(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  String _detectShopNo(String titleLine, String fileName, {List<String> knownShops = const ['104', '106']}) {
    String shopNo = '';
    final longCode = RegExp(r'(\d{6,})').firstMatch(titleLine);
    if (longCode != null) {
      final code = longCode.group(1)!;
      for (final s in knownShops) {
        if (code.endsWith(s)) {
          shopNo = s;
          break;
        }
      }
    }
    if (shopNo.isEmpty) {
      for (final s in knownShops) {
        if (RegExp('\\b$s\\b').hasMatch(titleLine)) {
          shopNo = s;
          break;
        }
      }
    }
    if (shopNo.isEmpty) {
      for (final s in knownShops) {
        if (fileName.contains(s)) {
          shopNo = s;
          break;
        }
      }
    }
    return shopNo;
  }

  Future<String> peekShopNo(String path, {List<String> knownShops = const ['104', '106']}) async {
    try {
      final bytes = await File(path).readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content.split('\n');
      String fileName = path.split(Platform.pathSeparator).last;
      for (int i = 0; i < lines.length && i < 6; i++) {
        final s = _detectShopNo(lines[i], fileName, knownShops: knownShops);
        if (s.isNotEmpty) return s;
      }
      return _detectShopNo('', fileName, knownShops: knownShops);
    } catch (_) {
      return '';
    }
  }

  Future<String> peekPeriod(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content.split('\n');
      String fileName = path.split(Platform.pathSeparator).last;
      for (int i = 0; i < lines.length && i < 6; i++) {
        final p = _detectPeriod(lines[i]);
        if (p.isNotEmpty) return p;
      }
      return _detectPeriod(fileName);
    } catch (_) {
      return '';
    }
  }

  static const Map<String, String> _monthNames = {
    'jan': 'January', 'january': 'January',
    'feb': 'February', 'february': 'February',
    'mar': 'March', 'march': 'March',
    'apr': 'April', 'april': 'April',
    'may': 'May',
    'jun': 'June', 'june': 'June',
    'jul': 'July', 'july': 'July',
    'aug': 'August', 'august': 'August',
    'sep': 'September', 'sept': 'September', 'september': 'September',
    'oct': 'October', 'october': 'October',
    'nov': 'November', 'november': 'November',
    'dec': 'December', 'december': 'December',
  };

  static const List<String> _monthByNumber = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _normalizeYear(String y) {
    if (y.length == 4) return y;
    if (y.length == 2) {
      final n = int.tryParse(y) ?? 0;
      return n <= 79 ? '20$y' : '19$y';
    }
    return y;
  }

  String _detectPeriod(String titleLine) {
    final nameMatch = RegExp(
      r"([A-Za-z]{3,9})\s*[\-'/]?\s*(\d{4}|\d{2})",
    ).firstMatch(titleLine);
    if (nameMatch != null) {
      final rawMonth = nameMatch.group(1)!.toLowerCase();
      if (_monthNames.containsKey(rawMonth)) {
        final year = _normalizeYear(nameMatch.group(2)!);
        return '${_monthNames[rawMonth]} $year';
      }
    }

    final numMatchMY = RegExp(r'\b(0?[1-9]|1[0-2])[\-/](\d{4})\b').firstMatch(titleLine);
    if (numMatchMY != null) {
      final m = int.parse(numMatchMY.group(1)!);
      final year = numMatchMY.group(2)!;
      return '${_monthByNumber[m]} $year';
    }

    final numMatchYM = RegExp(r'\b(\d{4})[\-/](0?[1-9]|1[0-2])\b').firstMatch(titleLine);
    if (numMatchYM != null) {
      final year = numMatchYM.group(1)!;
      final m = int.parse(numMatchYM.group(2)!);
      return '${_monthByNumber[m]} $year';
    }

    return '';
  }

  // ---------------------------------------------------------------------
  // Master Names + Mobile
  // ---------------------------------------------------------------------
  Future<int> importMasterNamesCsv(String path) async {
    final bytes = await File(path).readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    final fields = const CsvToListConverter().convert(content);
    if (fields.isEmpty) return 0;

    final writer = _BatchWriter(_db);
    int count = 0;
    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.length < 2) continue;
      final rc = _cleanNumber(row[0].toString().trim());
      final name = row[1].toString().trim();
      // तिसरा कॉलम (असल्यास) मोबाईल नंबर — CSV: RC No, Name, Mobile
      final mobile = row.length > 2 ? _cleanMobile(row[2].toString()) : '';
      if (rc.isEmpty || name.isEmpty) continue;
      final data = <String, dynamic>{'ration_card_no': rc, 'name': name};
      if (mobile.isNotEmpty) data['mobile'] = mobile;
      await writer.set(_masterNamesCol.doc(rc), data, SetOptions(merge: true));
      count++;
    }
    await writer.commit();

    await syncNamesFromMaster();
    return count;
  }

  // एका रेकॉर्डसाठी master मधून कोणती नाव/मोबाईल फील्ड्स अपडेट करायची ते ठरवतो
  Map<String, dynamic> _contactUpdates(
    Map data,
    Map<String, Map<String, String>> contactMap, {
    required bool overwrite,
  }) {
    final updates = <String, dynamic>{};
    final rc = _cleanNumber(data['ration_card_no']?.toString() ?? '');
    final contact = contactMap[rc];
    if (contact == null) return updates;

    final newName = contact['name'] ?? '';
    final newMobile = contact['mobile'] ?? '';
    final curName = data['name']?.toString() ?? '';
    final curMobile = data['mobile']?.toString() ?? '';

    if (newName.isNotEmpty && newName != curName && (overwrite || curName.trim().isEmpty)) {
      updates['name'] = newName;
    }
    if (newMobile.isNotEmpty && newMobile != curMobile && (overwrite || curMobile.trim().isEmpty)) {
      updates['mobile'] = newMobile;
    }
    return updates;
  }

  Future<Map<String, int>> _applyMaster({required bool overwrite}) async {
    final contactMap = await _loadMasterContactsMap();

    int allotCount = 0;
    int txnCount = 0;
    final writer = _BatchWriter(_db);

    final aSnap = await _allotmentCol.get();
    for (final d in aSnap.docs) {
      final updates = _contactUpdates(d.data() as Map, contactMap, overwrite: overwrite);
      if (updates.isNotEmpty) {
        await writer.update(d.reference, updates);
        allotCount++;
      }
    }

    final tSnap = await _transactionCol.get();
    for (final d in tSnap.docs) {
      final updates = _contactUpdates(d.data() as Map, contactMap, overwrite: overwrite);
      if (updates.isNotEmpty) {
        await writer.update(d.reference, updates);
        txnCount++;
      }
    }

    await writer.commit();
    invalidateCache();
    return {'allotment': allotCount, 'transaction': txnCount};
  }

  // रिकाम्या नाव/मोबाईल साठीच master मधून भरतो
  Future<Map<String, int>> syncNamesFromMaster() => _applyMaster(overwrite: false);

  // ⚠️ आधीच नाव असलं तरी master मधल्या नावाने OVERWRITE करतो (irreversible)
  Future<Map<String, int>> forceSyncNamesFromMaster() => _applyMaster(overwrite: true);

  Future<void> upsertMasterName(String rationCardNo, String name) async {
    final rc = _cleanNumber(rationCardNo.trim());
    final cleanName = name.trim();
    await _masterNamesCol.doc(rc).set({'ration_card_no': rc, 'name': cleanName}, SetOptions(merge: true));

    final writer = _BatchWriter(_db);
    final aSnap = await _allotmentCol.where('ration_card_no', isEqualTo: rc).get();
    for (final d in aSnap.docs) {
      await writer.update(d.reference, {'name': cleanName});
    }
    final tSnap = await _transactionCol.where('ration_card_no', isEqualTo: rc).get();
    for (final d in tSnap.docs) {
      await writer.update(d.reference, {'name': cleanName});
    }
    await writer.commit();

    await _patchCache(rc, {'name': cleanName});
  }

  // ⭐ मोबाईल नंबर सेव्ह/अपडेट — master_names मध्ये आणि त्या कार्डाच्या सर्व रेकॉर्ड्समध्ये.
  Future<void> upsertMobile(String rationCardNo, String mobile) async {
    final rc = _cleanNumber(rationCardNo.trim());
    final cleanMobile = _cleanMobile(mobile);
    await _masterNamesCol.doc(rc).set({'ration_card_no': rc, 'mobile': cleanMobile}, SetOptions(merge: true));

    final writer = _BatchWriter(_db);
    final aSnap = await _allotmentCol.where('ration_card_no', isEqualTo: rc).get();
    for (final d in aSnap.docs) {
      await writer.update(d.reference, {'mobile': cleanMobile});
    }
    final tSnap = await _transactionCol.where('ration_card_no', isEqualTo: rc).get();
    for (final d in tSnap.docs) {
      await writer.update(d.reference, {'mobile': cleanMobile});
    }
    await writer.commit();

    await _patchCache(rc, {'mobile': cleanMobile});
  }

  // नाव + मोबाईल दोन्ही एकत्र लोड करण्यासाठी (import च्या वेळी वापरलं जातं)
  Future<Map<String, Map<String, String>>> _loadMasterContactsMap() async {
    final snap = await _masterNamesCol.get();
    return {
      for (final d in snap.docs)
        d.id: {
          'name': (d.data() as Map)['name']?.toString() ?? '',
          'mobile': (d.data() as Map)['mobile']?.toString() ?? '',
        }
    };
  }

  Future<int> getMasterNamesCount() async {
    final snap = await _masterNamesCol.get();
    return snap.docs.length;
  }

  Future<List<String>> fetchMissingNameRationCards() async {
    final aRows = await _allotAll();
    final tRows = await _txnAll();
    final missing = <String>{};
    for (final data in aRows) {
      final name = data['name']?.toString() ?? '';
      final rc = data['ration_card_no']?.toString() ?? '';
      if (name.trim().isEmpty && rc.trim().isNotEmpty) missing.add(rc);
    }
    for (final data in tRows) {
      final name = data['name']?.toString() ?? '';
      final rc = data['ration_card_no']?.toString() ?? '';
      if (name.trim().isEmpty && rc.trim().isNotEmpty) missing.add(rc);
    }
    final list = missing.toList();
    list.sort();
    return list;
  }

  // ---------------------------------------------------------------------
  // Import CSV
  // ---------------------------------------------------------------------
  Future<int> importCsvData(String path, {String? overrideShopNo, String? overridePeriod}) async {
    final bytes = await File(path).readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines = content.split('\n');
    final firstLine = lines.isNotEmpty ? lines[0] : '';
    final secondLine = lines.length > 1 ? lines[1] : '';
    String fileName = path.split(Platform.pathSeparator).last;

    final probe = ('$firstLine\n$secondLine').toLowerCase();
    final looksLikeTransaction = probe.contains('src no') && probe.contains('receipt no');
    final looksLikeAllotment = !looksLikeTransaction &&
        (probe.contains('register') || probe.contains('rc no'));

    if (looksLikeAllotment) {
      return _importAllotmentCsv(content, fileName, overrideShopNo: overrideShopNo, overridePeriod: overridePeriod);
    } else if (looksLikeTransaction) {
      return _importTransactionCsv(content, fileName, overrideShopNo: overrideShopNo);
    } else {
      throw Exception(
        'अनोळखी फाईल फॉरमॅट! कृपया "Key Register" (वाटप) किंवा "Transaction Details" (व्यवहार) रिपोर्ट अपलोड करा.',
      );
    }
  }

  // ⭐ आता document ID ठरलेला (shop + period + rc) आहे — तीच फाईल पुन्हा import केली
  // तरी नवे duplicate रेकॉर्ड्स बनत नाहीत, आहे तेच रेकॉर्ड अपडेट होतं.
  Future<int> _importAllotmentCsv(String content, String fileName, {String? overrideShopNo, String? overridePeriod}) async {
    final fields = const CsvToListConverter().convert(content);
    if (fields.isEmpty) return 0;

    int headerRowIdx = 0;
    for (int i = 0; i < fields.length && i < 10; i++) {
      final rowText = fields[i].map((e) => e.toString().toLowerCase()).join(' ');
      if (rowText.contains('rc no')) {
        headerRowIdx = i;
        break;
      }
    }
    List<String> headerRow = fields[headerRowIdx].map((e) => e.toString().toLowerCase().trim()).toList();

    int rcNoIdx = headerRow.indexWhere((h) => h.contains('rc no'));
    if (rcNoIdx == -1) rcNoIdx = 1;
    int schemeIdx = headerRow.indexWhere((h) => h.contains('scheme'));
    int unitsIdx = headerRow.indexWhere((h) => h.contains('units'));
    int wheatIdx = headerRow.indexWhere((h) => h.contains('wheat'));
    int riceIdx = headerRow.indexWhere((h) => h.contains('rice'));
    List<int> sugarIdxs = [for (int i = 0; i < headerRow.length; i++) if (headerRow[i].contains('sug')) i];
    int sareeIdx = headerRow.indexWhere((h) => h.contains('saree'));

    if (wheatIdx == -1) {
      for (int i = headerRowIdx + 1; i < fields.length && i < headerRowIdx + 5; i++) {
        final subRow = fields[i].map((e) => e.toString().toLowerCase().trim()).toList();
        if (subRow.any((h) => h.contains('wheat'))) {
          wheatIdx = subRow.indexWhere((h) => h.contains('wheat'));
          riceIdx = subRow.indexWhere((h) => h.contains('rice'));
          sugarIdxs = [for (int j = 0; j < subRow.length; j++) if (subRow[j].contains('sug')) j];
          sareeIdx = subRow.indexWhere((h) => h.contains('saree'));
          headerRowIdx = i;
          break;
        }
      }
    }

    String shopNo = overrideShopNo ?? '';
    String period = overridePeriod ?? '';
    for (int i = 0; i < fields.length && i < headerRowIdx + 1 && i < 6; i++) {
      final lineText = fields[i].map((e) => e.toString()).join(' ');
      if (shopNo.isEmpty) {
        final s = _detectShopNo(lineText, fileName);
        if (s.isNotEmpty) shopNo = s;
      }
      if (period.isEmpty) {
        period = _detectPeriod(lineText);
      }
    }
    if (shopNo.isEmpty) shopNo = 'अज्ञात';
    if (period.isEmpty) period = _detectPeriod(fileName);

    final contactMap = await _loadMasterContactsMap();

    // आधीपासून असलेल्या रेकॉर्ड्सचा नकाशा (key -> document id), जुने random-ID रेकॉर्ड्ससहित
    final existing = await _allotAll(force: true);
    final existingIds = <String, String>{};
    for (final r in existing) {
      final k = _allotKey(
        r['shop_no']?.toString().trim() ?? '',
        r['period']?.toString().trim() ?? '',
        r['ration_card_no']?.toString().trim() ?? '',
      );
      existingIds.putIfAbsent(k, () => r['id'].toString());
    }

    final writer = _BatchWriter(_db);
    final seenInFile = <String>{};
    int processedCount = 0;

    for (int i = headerRowIdx + 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;
      final slNo = int.tryParse(row[0].toString().trim());
      if (slNo == null) continue;

      if (rcNoIdx >= row.length) continue;
      String rcNoRaw = row[rcNoIdx].toString().trim();
      if (rcNoRaw.isEmpty) continue;
      String rcNo = _cleanNumber(rcNoRaw);

      String scheme = (schemeIdx != -1 && schemeIdx < row.length) ? row[schemeIdx].toString().trim() : '';
      int units = (unitsIdx != -1 && unitsIdx < row.length) ? (int.tryParse(row[unitsIdx].toString().trim()) ?? 0) : 0;
      double wheat = (wheatIdx != -1 && wheatIdx < row.length) ? _num(row[wheatIdx].toString()) : 0;
      double rice = (riceIdx != -1 && riceIdx < row.length) ? _num(row[riceIdx].toString()) : 0;
      double saree = (sareeIdx != -1 && sareeIdx < row.length) ? _num(row[sareeIdx].toString()) : 0;

      double sugarCurr = 0, sugarPrev = 0;
      if (sugarIdxs.isNotEmpty) {
        final sugarVals = [for (final idx in sugarIdxs) if (idx < row.length) _num(row[idx].toString())];
        if (sugarVals.isNotEmpty) {
          sugarCurr = sugarVals.last;
          if (sugarVals.length > 1) {
            sugarPrev = sugarVals.sublist(0, sugarVals.length - 1).fold(0.0, (a, b) => a + b);
          }
        }
      }

      final key = _allotKey(shopNo, period, rcNo);
      if (!seenInFile.add(key)) continue; // त्याच फाईलमधली पुनरावृत्ती वगळा

      final contact = contactMap[rcNo];
      final data = <String, dynamic>{
        'shop_no': shopNo,
        'ration_card_no': rcNo,
        'scheme': scheme,
        'units': units,
        'period': period,
        'wheat': wheat,
        'rice': rice,
        'sugar_curr': sugarCurr,
        'sugar_prev': sugarPrev,
        'saree': saree,
      };
      final cName = contact?['name'] ?? '';
      final cMobile = contact?['mobile'] ?? '';
      if (cName.isNotEmpty) data['name'] = cName;
      if (cMobile.isNotEmpty) data['mobile'] = cMobile;

      final existingId = existingIds[key];
      if (existingId == null) {
        // नवीन रेकॉर्ड — नाव/मोबाईल रिकामे तरी फील्ड्स असू द्या
        data.putIfAbsent('name', () => '');
        data.putIfAbsent('mobile', () => '');
      }

      await writer.set(
        _allotmentCol.doc(existingId ?? _docId(key)),
        data,
        SetOptions(merge: true),
      );
      processedCount++;
    }

    await writer.commit();
    invalidateCache();
    return processedCount;
  }

  // ⭐ आता document ID = shop + पावती क्र. — तोच व्यवहार पुन्हा आला तर स्किप होतो.
  // परत केलेली संख्या = फक्त खरोखर नवीन साठवलेले व्यवहार.
  Future<int> _importTransactionCsv(String content, String fileName, {String? overrideShopNo}) async {
    final lines = content.split('\n');
    final headerLine = lines.isNotEmpty ? lines[0] : '';
    final delimiter = headerLine.contains('\t') ? '\t' : ',';
    final fields = CsvToListConverter(fieldDelimiter: delimiter, eol: '\n').convert(content);
    if (fields.isEmpty) return 0;

    String shopNo = overrideShopNo ?? '';
    if (shopNo.isEmpty) {
      for (int i = 0; i < fields.length && i < 6; i++) {
        final lineText = fields[i].map((e) => e.toString()).join(' ');
        final s = _detectShopNo(lineText, fileName);
        if (s.isNotEmpty) {
          shopNo = s;
          break;
        }
      }
    }
    if (shopNo.isEmpty) shopNo = 'अज्ञात';

    final contactMap = await _loadMasterContactsMap();
    final knownKeys = await _knownTxnKeys();

    final writer = _BatchWriter(_db);
    int insertedCount = 0;

    for (final row in fields) {
      if (row.isEmpty) continue;
      final slNo = int.tryParse(row[0].toString().trim());
      if (slNo == null) continue;
      final n = row.length;
      if (n < 11) continue;

      String rcNoRaw = row[1].toString().trim();
      if (rcNoRaw.isEmpty) continue;
      String rcNo = _cleanNumber(rcNoRaw);
      String scheme = row[2].toString().trim();
      String availType = row[3].toString().trim();
      String receiptNo = row[4].toString().trim();
      String txnDate = row[5].toString().trim();

      final key = _txnKey(shopNo, rcNo, receiptNo, txnDate);
      if (knownKeys.contains(key)) continue; // आधीच साठवलेला व्यवहार
      knownKeys.add(key);

      double wheat = n > 6 ? _num(row[6].toString()) : 0;
      double rice = n > 7 ? _num(row[7].toString()) : 0;
      double sugar = n > 8 ? _num(row[8].toString()) : 0;
      double saree = n > 9 ? _num(row[9].toString()) : 0;
      double jowar = n > 10 ? _num(row[10].toString()) : 0;

      double frice = 0.0;
      double amount = 0.0;
      String portability = '';
      String authTime = '';

      if (n >= 15) {
        frice = _num(row[11].toString());
        amount = _num(row[12].toString());
        portability = row[13].toString().trim();
        authTime = row[14].toString().trim();
      } else if (n == 14) {
        amount = _num(row[11].toString());
        portability = row[12].toString().trim();
        authTime = row[13].toString().trim();
      } else if (n >= 3) {
        authTime = row[n - 1].toString().trim();
        portability = row[n - 2].toString().trim();
        amount = _num(row[n - 3].toString());
      }

      final contact = contactMap[rcNo];

      await writer.set(_transactionCol.doc(_docId(key)), {
        'shop_no': shopNo,
        'ration_card_no': rcNo,
        'scheme': scheme,
        'avail_type': availType,
        'receipt_no': receiptNo,
        'txn_date': txnDate,
        'wheat': wheat,
        'rice': rice,
        'sugar': sugar,
        'saree': saree,
        'jowar': jowar,
        'frice': frice,
        'amount': amount,
        'portability': portability,
        'auth_time': authTime,
        'status': '✅ यशस्वी',
        'name': contact?['name'] ?? '',
        'mobile': contact?['mobile'] ?? '',
      });
      insertedCount++;
    }

    await writer.commit();
    if (insertedCount > 0) invalidateCache();
    return insertedCount;
  }
}