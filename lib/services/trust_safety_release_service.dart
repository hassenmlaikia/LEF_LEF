/// PASS137: deterministic policy helpers for trust, safety, privacy and release.
///
/// These helpers validate locally supplied data only. Enforcement that must resist
/// client tampering (rate limits, moderation decisions, notification delivery,
/// account export/deletion, retention jobs, rollout assignments and updates) must
/// be repeated in trusted backend code and security rules before production use.
class TrustSafetyReleaseService {
  TrustSafetyReleaseService._();

  static Map<String, dynamic> consentReceipt({required String userId,
      required String documentType, required String documentVersion,
      required DateTime acceptedAt, required String locale,
      required bool accepted}) {
    if (userId.trim().isEmpty || documentType.trim().isEmpty ||
        documentVersion.trim().isEmpty || locale.trim().isEmpty || !accepted) {
      throw ArgumentError('invalid_consent_receipt');
    }
    return {'userId': userId, 'documentType': documentType,
      'documentVersion': documentVersion, 'acceptedAt': acceptedAt.toUtc().toIso8601String(),
      'locale': locale, 'accepted': true};
  }

  static Map<String, dynamic> privacyConsent({required String userId,
      required Map<String, bool> purposes, required DateTime updatedAt,
      required String policyVersion}) {
    const allowed = {'personalization', 'analytics', 'marketing', 'location'};
    if (userId.trim().isEmpty || policyVersion.trim().isEmpty || purposes.isEmpty ||
        purposes.keys.any((key) => !allowed.contains(key))) {
      throw ArgumentError('invalid_privacy_consent');
    }
    return {'userId': userId, 'purposes': Map<String, bool>.unmodifiable(purposes),
      'updatedAt': updatedAt.toUtc().toIso8601String(), 'policyVersion': policyVersion};
  }

  /// Evaluates a sliding-window limit. The authoritative event list must come
  /// from a trusted store; this pure helper is not a distributed rate limiter.
  static bool rateLimitAllows({required DateTime now, required List<DateTime> events,
      required Duration window, required int maxEvents}) {
    if (window <= Duration.zero || maxEvents < 1) throw ArgumentError('invalid_rate_limit');
    final recent = events.where((event) => !event.isAfter(now) && now.difference(event) < window).length;
    return recent < maxEvents;
  }

  static Map<String, dynamic> userBlock({required String actorId,
      required String targetId, required DateTime createdAt, String? reason}) {
    if (actorId.trim().isEmpty || targetId.trim().isEmpty || actorId == targetId ||
        (reason?.length ?? 0) > 300) throw ArgumentError('invalid_user_block');
    return {'actorId': actorId, 'targetId': targetId,
      'createdAt': createdAt.toUtc().toIso8601String(), 'reason': reason?.trim()};
  }

  static Map<String, dynamic> muteRule({required String ownerId,
      required String targetType, required String targetId, required DateTime createdAt,
      DateTime? expiresAt}) {
    if (ownerId.trim().isEmpty || targetId.trim().isEmpty ||
        !const {'user', 'topic', 'keyword'}.contains(targetType) ||
        (expiresAt != null && !expiresAt.isAfter(createdAt))) {
      throw ArgumentError('invalid_mute_rule');
    }
    return {'ownerId': ownerId, 'targetType': targetType, 'targetId': targetId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt?.toUtc().toIso8601String()};
  }

  static Map<String, dynamic> followerRequest({required String requesterId,
      required String profileOwnerId, required DateTime createdAt}) {
    if (requesterId.trim().isEmpty || profileOwnerId.trim().isEmpty || requesterId == profileOwnerId) {
      throw ArgumentError('invalid_follow_request');
    }
    return {'requesterId': requesterId, 'profileOwnerId': profileOwnerId,
      'createdAt': createdAt.toUtc().toIso8601String(), 'status': 'pending'};
  }

  static Map<String, dynamic> postDraft({required String ownerId, required String text,
      required List<String> mediaUrls, required DateTime updatedAt,
      DateTime? scheduledAt}) {
    final body = text.trim();
    if (ownerId.trim().isEmpty || body.length > 10000 || mediaUrls.length > 10 ||
        mediaUrls.any((url) => !url.startsWith('https://') || url.length > 2048) ||
        (scheduledAt != null && scheduledAt.isBefore(updatedAt))) {
      throw ArgumentError('invalid_post_draft');
    }
    return {'ownerId': ownerId, 'text': body, 'mediaUrls': List<String>.unmodifiable(mediaUrls),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'scheduledAt': scheduledAt?.toUtc().toIso8601String(), 'status': 'draft'};
  }

  static Map<String, dynamic> validateMedia({required String fileName,
      required String mimeType, required int byteLength, int maxMegabytes = 50}) {
    const allowed = {'image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime'};
    final maxBytes = maxMegabytes * 1024 * 1024;
    if (fileName.trim().isEmpty || fileName.length > 255 || !allowed.contains(mimeType) ||
        byteLength < 1 || maxMegabytes < 1 || maxMegabytes > 500 || byteLength > maxBytes) {
      throw ArgumentError('invalid_media_file');
    }
    return {'fileName': fileName.trim(), 'mimeType': mimeType,
      'byteLength': byteLength, 'maxBytes': maxBytes,
      'requiresServerContentScan': true, 'stripSensitiveMetadata': true};
  }

  static Map<String, dynamic> moderationCase({required String reporterId,
      required String contentId, required String category, required DateTime createdAt,
      String? evidenceUrl}) {
    if (reporterId.trim().isEmpty || contentId.trim().isEmpty ||
        !const {'spam', 'harassment', 'violence', 'nudity', 'fraud', 'other'}.contains(category) ||
        (evidenceUrl != null && !evidenceUrl.startsWith('https://'))) {
      throw ArgumentError('invalid_moderation_case');
    }
    return {'reporterId': reporterId, 'contentId': contentId, 'category': category,
      'createdAt': createdAt.toUtc().toIso8601String(), 'evidenceUrl': evidenceUrl,
      'status': 'pending', 'decision': null, 'appealStatus': 'not_requested'};
  }

  static Map<String, dynamic> notificationPolicy({required bool enabled,
      required String priority, required String category, String? quietStart,
      String? quietEnd, required String timeZone}) {
    if (!const {'low', 'normal', 'high', 'critical'}.contains(priority) ||
        !const {'social', 'events', 'rides', 'services', 'security', 'system'}.contains(category) ||
        timeZone.trim().isEmpty || ((quietStart == null) != (quietEnd == null)) ||
        (quietStart != null && (!_validClock(quietStart) || !_validClock(quietEnd!)))) {
      throw ArgumentError('invalid_notification_policy');
    }
    return {'enabled': enabled, 'priority': priority, 'category': category,
      'quietStart': quietStart, 'quietEnd': quietEnd, 'timeZone': timeZone,
      'criticalMayBypassQuietHours': category == 'security' && priority == 'critical'};
  }

  static bool _validClock(String value) => RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value);

  static List<DateTime> notificationRetrySchedule(DateTime firstAttempt,
      {int maxAttempts = 5, Duration initialDelay = const Duration(minutes: 1),
       Duration maxDelay = const Duration(hours: 6)}) {
    if (maxAttempts < 1 || maxAttempts > 10 || initialDelay <= Duration.zero || maxDelay < initialDelay) {
      throw ArgumentError('invalid_retry_schedule');
    }
    final result = <DateTime>[];
    var delay = initialDelay;
    for (var i = 0; i < maxAttempts; i++) {
      result.add(firstAttempt.add(delay));
      final doubled = delay * 2;
      delay = doubled > maxDelay ? maxDelay : doubled;
    }
    return List.unmodifiable(result);
  }

  static Map<String, dynamic> userDataExportRequest({required String userId,
      required DateTime requestedAt, required String verificationMethod,
      required List<String> dataScopes}) {
    const allowed = {'profile', 'posts', 'messages_metadata', 'preferences', 'company_data'};
    if (userId.trim().isEmpty || verificationMethod.trim().isEmpty || dataScopes.isEmpty ||
        dataScopes.any((scope) => !allowed.contains(scope))) {
      throw ArgumentError('invalid_data_export_request');
    }
    return {'userId': userId, 'requestedAt': requestedAt.toUtc().toIso8601String(),
      'verificationMethod': verificationMethod,
      'dataScopes': List<String>.unmodifiable(dataScopes.toSet().toList()),
      'status': 'pending_verification', 'requiresTrustedBackend': true};
  }

  static Map<String, dynamic> retentionPolicy({required String recordType,
      required int retentionDays, required bool legalHoldAllowed}) {
    if (recordType.trim().isEmpty || retentionDays < 1 || retentionDays > 3650) {
      throw ArgumentError('invalid_retention_policy');
    }
    return {'recordType': recordType, 'retentionDays': retentionDays,
      'legalHoldAllowed': legalHoldAllowed, 'requiresScheduledBackendJob': true};
  }

  static Map<String, dynamic> securityIncident({required String reporterId,
      required String category, required String severity, required DateTime detectedAt,
      required String summary}) {
    if (reporterId.trim().isEmpty || summary.trim().length < 8 || summary.length > 4000 ||
        !const {'account', 'data_access', 'abuse', 'malware', 'other'}.contains(category) ||
        !const {'low', 'medium', 'high', 'critical'}.contains(severity)) {
      throw ArgumentError('invalid_security_incident');
    }
    return {'reporterId': reporterId, 'category': category, 'severity': severity,
      'detectedAt': detectedAt.toUtc().toIso8601String(), 'summary': summary.trim(),
      'status': 'open', 'assignedTo': null, 'resolution': null};
  }

  static bool featureEnabled({required bool globallyEnabled, required bool roleEnabled,
      required String stableSubjectId, required int rolloutPercent}) {
    if (rolloutPercent < 0 || rolloutPercent > 100 || stableSubjectId.trim().isEmpty) {
      throw ArgumentError('invalid_feature_rollout');
    }
    if (!globallyEnabled || !roleEnabled || rolloutPercent == 0) return false;
    if (rolloutPercent == 100) return true;
    var hash = 0;
    for (final unit in stableSubjectId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % 100 < rolloutPercent;
  }

  static Map<String, dynamic> releaseGate({required bool analyzePassed,
      required bool testsPassed, required bool securityReviewPassed,
      required bool backendRulesTested, required bool releaseNotesPresent}) {
    final checks = {'analyze': analyzePassed, 'tests': testsPassed,
      'securityReview': securityReviewPassed, 'backendRules': backendRulesTested,
      'releaseNotes': releaseNotesPresent};
    return {'checks': checks, 'ready': checks.values.every((value) => value),
      'failedChecks': checks.entries.where((entry) => !entry.value).map((entry) => entry.key).toList()};
  }

  static Map<String, dynamic> updatePolicy({required int installedBuild,
      required int latestBuild, required int minimumSupportedBuild,
      required String releaseUrl}) {
    if (installedBuild < 1 || latestBuild < 1 || minimumSupportedBuild < 1 ||
        minimumSupportedBuild > latestBuild || !releaseUrl.startsWith('https://')) {
      throw ArgumentError('invalid_update_policy');
    }
    return {'updateAvailable': installedBuild < latestBuild,
      'updateRequired': installedBuild < minimumSupportedBuild,
      'latestBuild': latestBuild, 'minimumSupportedBuild': minimumSupportedBuild,
      'releaseUrl': releaseUrl};
  }
}
