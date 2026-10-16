import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Company operations added in PASS135. Client-side checks improve UX; Firestore
/// rules and trusted backend jobs must remain the final authorization boundary.
class CompanyOperationsService {
  CompanyOperationsService._();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static User? get _user => FirebaseAuth.instance.currentUser;
  static CollectionReference<Map<String, dynamic>> _company(String id) =>
      _db.collection('companies').doc(id).collection('operations');

  static Future<void> _authorize(String companyId) async {
    final user = _user;
    if (user == null) throw StateError('not_authenticated');
    final company = await _db.collection('companies').doc(companyId).get();
    if (!company.exists) throw StateError('company_not_found');
    final profile = await _db.collection('users').doc(user.uid).get();
    final caps = profile.data()?['capabilities'];
    if (company.data()?['ownerId'] != user.uid &&
        !(caps is List && caps.contains('manageServices'))) {
      throw StateError('company_permission_denied');
    }
  }

  static Future<void> _audit(String companyId, String action,
      {Map<String, dynamic> details = const {}}) async {
    final user = _user;
    if (user == null) throw StateError('not_authenticated');
    await _company(companyId).doc('audit').collection('entries').add({
      'actorId': user.uid, 'action': action, 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> stream(String companyId, String kind) {
    const allowed = {'reviews','verification','exceptions','reschedules','cancellations',
      'lateness','staffAssignments','staffPermissions','serviceCatalog','availability',
      'reports','imports','stockAlerts','technicalReports','complaints','reviewModeration'};
    if (!allowed.contains(kind)) throw ArgumentError('invalid_company_operation');
    return _company(companyId).doc(kind).collection('items').orderBy('updatedAt', descending: true).limit(200).snapshots();
  }

  static Future<String> submitReview(String companyId, {required int stars, required String comment}) async {
    final user = _user; if (user == null) throw StateError('not_authenticated');
    final text = comment.trim();
    if (stars < 1 || stars > 5 || text.length > 1000) throw ArgumentError('invalid_review');
    final ref = _company(companyId).doc('reviews').collection('items').doc('${user.uid}_${DateTime.now().millisecondsSinceEpoch}');
    await ref.set({'userId': user.uid, 'stars': stars, 'comment': text, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  static Future<String> submitComplaint(String companyId, {required String reason, String details = ''}) async {
    final user = _user; if (user == null) throw StateError('not_authenticated');
    final r = reason.trim(), d = details.trim();
    if (r.isEmpty || r.length > 120 || d.length > 2000) throw ArgumentError('invalid_complaint');
    final ref = _company(companyId).doc('complaints').collection('items').doc();
    await ref.set({'userId': user.uid, 'reason': r, 'details': d, 'status': 'open', 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  static Future<void> reviewItem(String companyId, String kind, String itemId, {required String status, String note = ''}) async {
    await _authorize(companyId);
    const statuses = {'reviews': {'approved','rejected','hidden'}, 'verification': {'pending','approved','rejected','expired'},
      'exceptions': {'open','closed'}, 'reschedules': {'requested','approved','rejected'},
      'cancellations': {'requested','approved','rejected'}, 'lateness': {'reported','excused','confirmed'},
      'complaints': {'open','in_review','resolved','dismissed'}, 'reviewModeration': {'pending','approved','rejected','hidden'}};
    if (!statuses.containsKey(kind) || !statuses[kind]!.contains(status) || note.trim().length > 1000) throw ArgumentError('invalid_review_decision');
    await _company(companyId).doc(kind).collection('items').doc(itemId).update({'status': status, 'reviewNote': note.trim(), 'reviewedBy': _user!.uid, 'reviewedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    await _audit(companyId, 'review_$kind', details: {'itemId': itemId, 'status': status});
  }

  static Future<String> createRecord(String companyId, String kind, Map<String, dynamic> data) async {
    await _authorize(companyId);
    const allowed = {'verification','exceptions','reschedules','cancellations','lateness','staffAssignments','staffPermissions','serviceCatalog','availability','reports','stockAlerts','technicalReports','imports'};
    if (!allowed.contains(kind) || data.length > 40) throw ArgumentError('invalid_company_record');
    final ref = _company(companyId).doc(kind).collection('items').doc();
    await ref.set({...data, 'createdBy': _user!.uid, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    await _audit(companyId, 'create_$kind', details: {'itemId': ref.id});
    return ref.id;
  }

  static Future<void> updateRecord(String companyId, String kind, String itemId, Map<String, dynamic> changes) async {
    await _authorize(companyId);
    if (changes.isEmpty || changes.length > 30 || changes.keys.any((k) => {'createdBy','createdAt','actorId','ownerId'}.contains(k))) throw ArgumentError('invalid_company_update');
    await _company(companyId).doc(kind).collection('items').doc(itemId).update({...changes, 'updatedAt': FieldValue.serverTimestamp()});
    await _audit(companyId, 'update_$kind', details: {'itemId': itemId, 'fields': changes.keys.toList()});
  }

  /// Strict, dependency-free CSV parser for product imports. Header row required;
  /// columns: name,price,stock,sku. Returns validated rows without writing them.
  static List<Map<String, dynamic>> parseProductCsv(String csv) {
    final lines = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2 || lines.length > 5001) throw ArgumentError('invalid_csv_row_count');
    List<String> parse(String line) => line.split(',').map((v) => v.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
    final headers = parse(lines.first).map((v) => v.toLowerCase()).toList();
    for (final required in ['name','price','stock']) { if (!headers.contains(required)) throw ArgumentError('csv_missing_$required'); }
    final rows = <Map<String, dynamic>>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = parse(lines[i]); if (cells.length != headers.length) throw FormatException('csv_column_count_line_${i+1}');
      final row = <String, String>{for (var j=0;j<headers.length;j++) headers[j]: cells[j]};
      final name = row['name']!.trim(), price = double.tryParse(row['price']!), stock = int.tryParse(row['stock']!);
      if (name.isEmpty || name.length > 160 || price == null || !price.isFinite || price < 0 || stock == null || stock < 0) throw FormatException('csv_invalid_product_line_${i+1}');
      rows.add({'name': name, 'price': price, 'stock': stock, 'sku': (row['sku'] ?? '').trim()});
    }
    return rows;
  }

  /// Deterministic CSV export; caller supplies authorized, already-fetched rows.
  static String toCsv(List<Map<String, dynamic>> rows, List<String> columns) {
    if (columns.isEmpty || columns.length > 40 || rows.length > 10000) throw ArgumentError('invalid_export_size');
    String cell(Object? value) { final s = (value ?? '').toString(); return '"${s.replaceAll('"', '""')}"'; }
    return ([columns, ...rows.map((r) => columns.map((c) => r[c]?.toString() ?? '').toList())]).map((r) => r.map(cell).join(',')).join('\r\n');
  }

  static Future<Map<String, dynamic>> branchPerformance(String companyId, {required DateTime from, required DateTime to}) async {
    await _authorize(companyId);
    if (!to.isAfter(from) || to.difference(from).inDays > 366) throw ArgumentError('invalid_report_range');
    final start = Timestamp.fromDate(from), end = Timestamp.fromDate(to);
    final appointments = await _db.collection('companies').doc(companyId).collection('appointments').where('requestedAt', isGreaterThanOrEqualTo: start).where('requestedAt', isLessThan: end).get();
    final branches = await _db.collection('companies').doc(companyId).collection('branches').get();
    final byBranch = <String, Map<String, int>>{};
    for (final b in branches.docs) { byBranch[b.id] = {'appointments': 0, 'completed': 0, 'cancelled': 0}; }
    for (final a in appointments.docs) {
      final id = (a.data()['branchId'] ?? 'unassigned').toString();
      final counts = byBranch.putIfAbsent(id, () => {'appointments': 0, 'completed': 0, 'cancelled': 0});
      counts['appointments'] = counts['appointments']! + 1;
      if (a.data()['status'] == 'completed') counts['completed'] = counts['completed']! + 1;
      if (a.data()['status'] == 'cancelled') counts['cancelled'] = counts['cancelled']! + 1;
    }
    final report = {'from': from.toIso8601String(), 'to': to.toIso8601String(), 'branches': byBranch, 'generatedAt': DateTime.now().toIso8601String()};
    await _audit(companyId, 'branch_performance_report', details: {'from': report['from'], 'to': report['to']});
    return report;
  }

  static bool isWithinAvailability({required DateTime at, required Map<String, dynamic> weeklyHours, List<Map<String, dynamic>> exceptions = const []}) {
    final dateKey = '${at.year.toString().padLeft(4,'0')}-${at.month.toString().padLeft(2,'0')}-${at.day.toString().padLeft(2,'0')}';
    Map<String, dynamic>? exception;
    for (final item in exceptions) { if (item['date'] == dateKey) { exception = item; break; } }
    final matchedException = exception;
    if (matchedException != null) return matchedException['closed'] != true && _inside(at, matchedException['open']?.toString(), matchedException['close']?.toString());
    final day = const ['mon','tue','wed','thu','fri','sat','sun'][at.weekday-1];
    final hours = weeklyHours[day];
    if (hours is! Map || hours['closed'] == true) return false;
    return _inside(at, hours['open']?.toString(), hours['close']?.toString());
  }
  static bool _inside(DateTime at, String? open, String? close) {
    final a = _minutes(open), b = _minutes(close); if (a == null || b == null || b <= a) return false;
    final m = at.hour * 60 + at.minute; return m >= a && m < b;
  }
  static int? _minutes(String? value) { if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return null; final p = value.split(':').map(int.parse).toList(); if (p[0] > 23 || p[1] > 59) return null; return p[0]*60+p[1]; }
}
