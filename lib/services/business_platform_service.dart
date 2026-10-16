/// PASS136: deterministic business-platform policies.
///
/// This layer validates and calculates data locally. It does not charge cards,
/// issue tax-compliant invoices, grant subscription entitlements, delete Firebase
/// accounts, or schedule trusted jobs; those actions require trusted backend work.
class BusinessPlatformService {
  BusinessPlatformService._();

  static const Map<String, Map<String, Object?>> subscriptionPlans = {
    'starter': {'monthlyPrice': null, 'branches': 1, 'staff': 2, 'catalogItems': 25},
    'growth': {'monthlyPrice': null, 'branches': 3, 'staff': 10, 'catalogItems': 250},
    'business': {'monthlyPrice': null, 'branches': 20, 'staff': 100, 'catalogItems': 5000},
  };

  static Map<String, Object> planFor(String planId) {
    final plan = subscriptionPlans[planId];
    if (plan == null) throw ArgumentError('unknown_subscription_plan');
    return Map.unmodifiable(plan);
  }

  static DateTime renewalGraceEnd(DateTime expiresAt, {int graceDays = 7}) {
    if (graceDays < 0 || graceDays > 30) throw ArgumentError('invalid_grace_period');
    return expiresAt.add(Duration(days: graceDays));
  }

  static String subscriptionState({required DateTime now, required DateTime expiresAt,
      int graceDays = 7, bool cancelled = false}) {
    if (cancelled) return 'cancelled';
    if (!now.isAfter(expiresAt)) return 'active';
    if (!now.isAfter(renewalGraceEnd(expiresAt, graceDays: graceDays))) return 'grace_period';
    return 'expired';
  }

  /// Returns calculated amounts only; currency and tax treatment must be set
  /// by the business and checked against applicable local law before invoicing.
  static Map<String, double> calculateInvoice({required double subtotal,
      double discount = 0, double taxRatePercent = 0}) {
    if (![subtotal, discount, taxRatePercent].every((v) => v.isFinite) ||
        subtotal < 0 || discount < 0 || discount > subtotal ||
        taxRatePercent < 0 || taxRatePercent > 100) {
      throw ArgumentError('invalid_invoice_amount');
    }
    final taxable = subtotal - discount;
    final tax = taxable * taxRatePercent / 100;
    return {'subtotal': _money(subtotal), 'discount': _money(discount),
      'taxable': _money(taxable), 'tax': _money(tax), 'total': _money(taxable + tax)};
  }

  static double _money(double value) => (value * 100).roundToDouble() / 100;

  static bool promotionIsActive({required DateTime now, required DateTime startsAt,
      required DateTime endsAt, required bool enabled}) =>
      enabled && !now.isBefore(startsAt) && now.isBefore(endsAt) && endsAt.isAfter(startsAt);

  static bool couponCanBeUsed({required bool enabled, required DateTime now,
      required DateTime startsAt, required DateTime endsAt,
      required int usageCount, required int maxUses, required double minimumSpend,
      required double cartSubtotal, String? assignedUserId, String? userId}) {
    if (!enabled || maxUses < 1 || usageCount < 0 || usageCount >= maxUses ||
        minimumSpend < 0 || cartSubtotal < minimumSpend ||
        !promotionIsActive(now: now, startsAt: startsAt, endsAt: endsAt, enabled: enabled)) return false;
    if (assignedUserId != null && assignedUserId != userId) return false;
    return true;
  }

  static bool referralEligible({required String referrerId, required String referredUserId,
      required bool referredAccountIsNew, required bool alreadyRewarded}) =>
      referrerId.trim().isNotEmpty && referredUserId.trim().isNotEmpty &&
      referrerId != referredUserId && referredAccountIsNew && !alreadyRewarded;

  static Map<String, String> localizedContent(Map<String, dynamic> translations,
      {required String language, String fallbackLanguage = 'ar-TN'}) {
    String valueFor(String key) {
      final raw = translations[key];
      if (raw is! Map) return '';
      final chosen = raw[language] ?? raw[fallbackLanguage] ?? raw['en'];
      return chosen is String ? chosen.trim() : '';
    }
    return {for (final key in translations.keys) if (key is String) key: valueFor(key)};
  }

  static List<Map<String, dynamic>> compareServices(List<Map<String, dynamic>> services) {
    if (services.length > 100) throw ArgumentError('too_many_services_to_compare');
    final copy = services.map((e) => Map<String, dynamic>.from(e)).toList();
    copy.sort((a, b) {
      final av = a['price']; final bv = b['price'];
      final ap = av is num && av.isFinite && av >= 0 ? av.toDouble() : double.infinity;
      final bp = bv is num && bv.isFinite && bv >= 0 ? bv.toDouble() : double.infinity;
      final priceOrder = ap.compareTo(bp);
      if (priceOrder != 0) return priceOrder;
      final ar = a['rating']; final br = b['rating'];
      final ratingA = ar is num && ar.isFinite ? ar.toDouble() : 0.0;
      final ratingB = br is num && br.isFinite ? br.toDouble() : 0.0;
      return ratingB.compareTo(ratingA);
    });
    return List.unmodifiable(copy);
  }

  static Map<String, dynamic> savedSearch({required String ownerId, required String query,
      required Map<String, dynamic> filters, required DateTime createdAt,
      bool alertOnChange = false}) {
    final q = query.trim();
    if (ownerId.trim().isEmpty || q.length > 200 || filters.length > 30) {
      throw ArgumentError('invalid_saved_search');
    }
    return {'ownerId': ownerId, 'query': q, 'filters': Map<String, dynamic>.from(filters),
      'createdAt': createdAt.toUtc().toIso8601String(), 'alertOnChange': alertOnChange};
  }

  static Map<String, dynamic> supportTicket({required String userId,
      required String subject, required String details, String priority = 'normal',
      List<String> attachmentUrls = const []}) {
    final s = subject.trim(), d = details.trim();
    if (userId.trim().isEmpty || s.length < 4 || s.length > 140 ||
        d.length < 4 || d.length > 4000 ||
        !const {'low', 'normal', 'high', 'urgent'}.contains(priority) ||
        attachmentUrls.length > 5 || attachmentUrls.any((u) =>
          !u.startsWith('https://') || u.length > 2048)) {
      throw ArgumentError('invalid_support_ticket');
    }
    return {'userId': userId, 'subject': s, 'details': d, 'priority': priority,
      'attachmentUrls': List<String>.unmodifiable(attachmentUrls), 'status': 'open'};
  }

  static Map<String, dynamic> accessibilityPreferences({double textScale = 1,
      bool highContrast = false, bool reduceMotion = false, bool screenReaderHints = true}) {
    if (!textScale.isFinite || textScale < 0.8 || textScale > 2.0) {
      throw ArgumentError('invalid_text_scale');
    }
    return {'textScale': textScale, 'highContrast': highContrast,
      'reduceMotion': reduceMotion, 'screenReaderHints': screenReaderHints};
  }

  static Map<String, dynamic> offlineCachePolicy({int maxAgeHours = 24,
      int maxMegabytes = 100, bool allowMedia = false}) {
    if (maxAgeHours < 1 || maxAgeHours > 720 || maxMegabytes < 10 || maxMegabytes > 2048) {
      throw ArgumentError('invalid_cache_policy');
    }
    return {'maxAgeHours': maxAgeHours, 'maxMegabytes': maxMegabytes,
      'allowMedia': allowMedia, 'sensitiveDataAllowed': false};
  }

  static Map<String, dynamic> storageSummary({required int usedBytes,
      required int cacheBytes, required int mediaBytes}) {
    if ([usedBytes, cacheBytes, mediaBytes].any((v) => v < 0) ||
        cacheBytes > usedBytes || mediaBytes > usedBytes) throw ArgumentError('invalid_storage_usage');
    return {'usedBytes': usedBytes, 'cacheBytes': cacheBytes, 'mediaBytes': mediaBytes,
      'clearableCacheBytes': cacheBytes};
  }

  static DateTime sessionExpiry(DateTime issuedAt, {int maxAgeHours = 720}) {
    if (maxAgeHours < 1 || maxAgeHours > 2160) throw ArgumentError('invalid_session_age');
    return issuedAt.add(Duration(hours: maxAgeHours));
  }

  static bool sessionIsExpired(DateTime now, DateTime issuedAt, {int maxAgeHours = 720}) =>
      !now.isBefore(sessionExpiry(issuedAt, maxAgeHours: maxAgeHours));

  static Map<String, dynamic> accountDeletionRequest({required String userId,
      required DateTime now, int graceDays = 14, required String policyVersion}) {
    if (userId.trim().isEmpty || graceDays < 1 || graceDays > 30 || policyVersion.trim().isEmpty) {
      throw ArgumentError('invalid_account_deletion_request');
    }
    return {'userId': userId, 'requestedAt': now.toUtc().toIso8601String(),
      'scheduledFor': now.add(Duration(days: graceDays)).toUtc().toIso8601String(),
      'policyVersion': policyVersion, 'status': 'pending', 'requiresTrustedBackend': true};
  }

  static Map<String, dynamic> backupManifest({required String companyId,
      required DateTime createdAt, required List<String> includedCollections,
      required int recordCount, required String formatVersion}) {
    if (companyId.trim().isEmpty || includedCollections.isEmpty ||
        includedCollections.length > 100 || recordCount < 0 ||
        formatVersion.trim().isEmpty) throw ArgumentError('invalid_backup_manifest');
    return {'companyId': companyId, 'createdAt': createdAt.toUtc().toIso8601String(),
      'includedCollections': List<String>.unmodifiable(includedCollections.toSet().toList()),
      'recordCount': recordCount, 'formatVersion': formatVersion,
      'restoreTested': false, 'containsSecrets': false};
  }
}
