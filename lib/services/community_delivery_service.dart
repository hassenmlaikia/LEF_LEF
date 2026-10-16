/// PASS138 policy/data helpers for community, event and delivery workflows.
/// These helpers validate local input only. Permissions, ticket uniqueness,
/// emergency actions, location sharing and ledger integrity require trusted
/// backend enforcement before production use.
class CommunityDeliveryService {
  CommunityDeliveryService._();

  static String _required(String value, String code, {int max = 200}) {
    final v = value.trim();
    if (v.isEmpty || v.length > max) throw ArgumentError(code);
    return v;
  }

  static Map<String, dynamic> group({required String ownerId, required String title,
      required List<String> memberIds, required DateTime createdAt}) {
    final owner = _required(ownerId, 'invalid_group_owner');
    final name = _required(title, 'invalid_group_title', max: 100);
    final members = memberIds.map((x) => x.trim()).where((x) => x.isNotEmpty).toSet();
    members.add(owner);
    if (members.length > 500) throw ArgumentError('group_member_limit');
    return {'ownerId': owner, 'title': name, 'memberIds': List.unmodifiable(members),
      'createdAt': createdAt.toUtc().toIso8601String(), 'status': 'active'};
  }

  static Map<String, dynamic> voiceMessage({required String senderId, required String mediaUrl,
      required int durationSeconds, required DateTime createdAt}) {
    if (_required(senderId, 'invalid_sender').isEmpty || !mediaUrl.startsWith('https://') ||
        durationSeconds < 1 || durationSeconds > 600) throw ArgumentError('invalid_voice_message');
    return {'senderId': senderId, 'mediaUrl': mediaUrl, 'durationSeconds': durationSeconds,
      'createdAt': createdAt.toUtc().toIso8601String(), 'status': 'sent'};
  }

  static Map<String, dynamic> callSession({required String callerId, required String calleeId,
      required String mediaType, required DateTime createdAt}) {
    if (callerId.trim().isEmpty || calleeId.trim().isEmpty || callerId == calleeId ||
        !const {'audio', 'video'}.contains(mediaType)) throw ArgumentError('invalid_call_session');
    return {'callerId': callerId, 'calleeId': calleeId, 'mediaType': mediaType,
      'createdAt': createdAt.toUtc().toIso8601String(), 'status': 'ringing',
      'requiresPermissionCheck': true};
  }

  static Map<String, dynamic> threadedReply({required String postId, required String commentId,
      required String authorId, required String text, required DateTime createdAt}) {
    final body = _required(text, 'invalid_reply', max: 4000);
    return {'postId': _required(postId, 'invalid_post_id'), 'parentCommentId': _required(commentId, 'invalid_parent_comment'),
      'authorId': _required(authorId, 'invalid_author'), 'text': body,
      'createdAt': createdAt.toUtc().toIso8601String()};
  }

  static Map<String, dynamic> poll({required String creatorId, required String question,
      required List<String> options, required DateTime closesAt, required DateTime now}) {
    final q = _required(question, 'invalid_poll_question', max: 500);
    final cleaned = options.map((x) => x.trim()).toList();
    if (cleaned.length < 2 || cleaned.length > 10 || cleaned.any((x) => x.isEmpty || x.length > 120) ||
        cleaned.toSet().length != cleaned.length || !closesAt.isAfter(now)) throw ArgumentError('invalid_poll');
    return {'creatorId': _required(creatorId, 'invalid_poll_creator'), 'question': q,
      'options': List.unmodifiable(cleaned), 'closesAt': closesAt.toUtc().toIso8601String(),
      'oneVotePerUser': true, 'status': 'open'};
  }

  static List<String> hashtags(String text, {int maxTags = 20}) {
    final matches = RegExp(r'(?<!\w)#([\p{L}\p{N}_]{1,50})', unicode: true)
        .allMatches(text).map((m) => m.group(1)!.toLowerCase()).toSet().toList();
    if (maxTags < 1 || maxTags > 50 || matches.length > maxTags) throw ArgumentError('hashtag_limit');
    return List.unmodifiable(matches);
  }

  static Map<String, dynamic> locationShare({required String ownerId, required double latitude,
      required double longitude, required DateTime expiresAt, required DateTime now}) {
    if (ownerId.trim().isEmpty || !latitude.isFinite || !longitude.isFinite || latitude < -90 ||
        latitude > 90 || longitude < -180 || longitude > 180 || !expiresAt.isAfter(now) ||
        expiresAt.difference(now) > const Duration(hours: 24)) throw ArgumentError('invalid_location_share');
    return {'ownerId': ownerId, 'latitude': latitude, 'longitude': longitude,
      'createdAt': now.toUtc().toIso8601String(), 'expiresAt': expiresAt.toUtc().toIso8601String(),
      'sharing': true, 'requiresExplicitConsent': true};
  }

  static Map<String, dynamic> emergencyContact({required String ownerId, required String name,
      required String phone, required int priority}) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[\s()-]'), '');
    if (ownerId.trim().isEmpty || name.trim().isEmpty || name.length > 100 ||
        !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(cleanedPhone) || priority < 1 || priority > 10) {
      throw ArgumentError('invalid_emergency_contact');
    }
    return {'ownerId': ownerId, 'name': name.trim(), 'phone': cleanedPhone, 'priority': priority};
  }

  static Map<String, dynamic> familyLink({required String requesterId, required String targetId,
      required DateTime createdAt}) {
    if (requesterId.trim().isEmpty || targetId.trim().isEmpty || requesterId == targetId) {
      throw ArgumentError('invalid_family_link');
    }
    return {'requesterId': requesterId, 'targetId': targetId,
      'createdAt': createdAt.toUtc().toIso8601String(), 'status': 'pending',
      'permissions': <String>[], 'requiresBothPartiesConsent': true};
  }

  static String calendarEvent({required String eventId, required String title,
      required DateTime startsAt, required DateTime endsAt}) {
    if (eventId.trim().isEmpty || title.trim().isEmpty || !endsAt.isAfter(startsAt)) {
      throw ArgumentError('invalid_calendar_event');
    }
    String stamp(DateTime d) => d.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').replaceAll('.000', '');
    return 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:${eventId.trim()}\r\nSUMMARY:${title.trim().replaceAll(RegExp(r'[\\,;]'), r'\\$&')}\r\nDTSTART:${stamp(startsAt)}\r\nDTEND:${stamp(endsAt)}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n';
  }

  static Map<String, dynamic> companyQr({required String companyId, required String publicUrl,
      required DateTime createdAt}) {
    if (companyId.trim().isEmpty || !publicUrl.startsWith('https://')) throw ArgumentError('invalid_company_qr');
    return {'companyId': companyId, 'publicUrl': publicUrl,
      'createdAt': createdAt.toUtc().toIso8601String(), 'revocable': true,
      'serverMustValidateCompanyStatus': true};
  }

  static Map<String, dynamic> eventTicket({required String eventId, required String ticketId,
      required String holderId, required DateTime issuedAt}) {
    if ([eventId, ticketId, holderId].any((v) => v.trim().isEmpty)) throw ArgumentError('invalid_event_ticket');
    return {'eventId': eventId, 'ticketId': ticketId, 'holderId': holderId,
      'issuedAt': issuedAt.toUtc().toIso8601String(), 'status': 'valid',
      'singleUse': true, 'serverRedemptionRequired': true};
  }

  static Map<String, dynamic> eventWaitlist({required String eventId, required String userId,
      required DateTime joinedAt, required DateTime? offerExpiresAt}) {
    if (eventId.trim().isEmpty || userId.trim().isEmpty ||
        (offerExpiresAt != null && !offerExpiresAt.isAfter(joinedAt))) throw ArgumentError('invalid_event_waitlist');
    return {'eventId': eventId, 'userId': userId, 'joinedAt': joinedAt.toUtc().toIso8601String(),
      'offerExpiresAt': offerExpiresAt?.toUtc().toIso8601String(), 'status': 'waiting'};
  }

  static Map<String, dynamic> providerDocument({required String providerId, required String documentType,
      required DateTime expiresAt, required DateTime now}) {
    if (providerId.trim().isEmpty || !const {'identity', 'license', 'insurance', 'vehicle_inspection'}.contains(documentType)) {
      throw ArgumentError('invalid_provider_document');
    }
    return {'providerId': providerId, 'documentType': documentType,
      'expiresAt': expiresAt.toUtc().toIso8601String(), 'expired': !expiresAt.isAfter(now),
      'backendMustRestrictExpiredProvider': true};
  }

  static Map<String, dynamic> driverSchedule({required String driverId, required List<Map<String, String>> shifts}) {
    if (driverId.trim().isEmpty || shifts.length > 100) throw ArgumentError('invalid_driver_schedule');
    final normalized = <Map<String, String>>[];
    for (final shift in shifts) {
      final day = shift['day'] ?? '', start = shift['start'] ?? '', end = shift['end'] ?? '';
      if (!const {'mon','tue','wed','thu','fri','sat','sun'}.contains(day) ||
          !_clock(start) || !_clock(end) || start == end) throw ArgumentError('invalid_driver_shift');
      normalized.add({'day': day, 'start': start, 'end': end});
    }
    return {'driverId': driverId, 'shifts': List.unmodifiable(normalized), 'timezoneRequired': true};
  }

  static bool _clock(String value) => RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value);

  static Map<String, dynamic> deliveryProof({required String orderId, required String courierId,
      required String proofType, String? proofUrl, String? receiptCode, required DateTime deliveredAt}) {
    if (orderId.trim().isEmpty || courierId.trim().isEmpty || !const {'photo', 'receipt_code'}.contains(proofType) ||
        (proofType == 'photo' && !(proofUrl?.startsWith('https://') ?? false)) ||
        (proofType == 'receipt_code' && (receiptCode == null || receiptCode.trim().length < 4 || receiptCode.length > 32))) {
      throw ArgumentError('invalid_delivery_proof');
    }
    return {'orderId': orderId, 'courierId': courierId, 'proofType': proofType, 'proofUrl': proofUrl,
      'receiptCode': receiptCode, 'deliveredAt': deliveredAt.toUtc().toIso8601String(), 'requiresServerAuthorization': true};
  }

  static Map<String, dynamic> deliveryTimeline({required String orderId, required String status,
      required DateTime occurredAt, String? note}) {
    if (orderId.trim().isEmpty || !const {'placed','accepted','prepared','picked_up','in_transit','delivered','cancelled'}.contains(status) ||
        (note?.length ?? 0) > 500) throw ArgumentError('invalid_delivery_timeline');
    return {'orderId': orderId, 'status': status, 'occurredAt': occurredAt.toUtc().toIso8601String(), 'note': note?.trim()};
  }

  static Map<String, dynamic> loyaltyEntry({required String userId, required int points,
      required String reason, required String referenceId, required DateTime createdAt}) {
    if (userId.trim().isEmpty || points == 0 || points.abs() > 1000000 || reason.trim().isEmpty || referenceId.trim().isEmpty) {
      throw ArgumentError('invalid_loyalty_entry');
    }
    return {'userId': userId, 'points': points, 'reason': reason.trim(), 'referenceId': referenceId,
      'createdAt': createdAt.toUtc().toIso8601String(), 'immutableLedgerEntry': true,
      'backendMustPreventDuplicateReference': true};
  }

  static Map<String, dynamic> moderationAssessment({required String contentId, required String classifier,
      required double riskScore, required DateTime assessedAt}) {
    if (contentId.trim().isEmpty || classifier.trim().isEmpty || !riskScore.isFinite || riskScore < 0 || riskScore > 1) {
      throw ArgumentError('invalid_moderation_assessment');
    }
    return {'contentId': contentId, 'classifier': classifier, 'riskScore': riskScore,
      'assessedAt': assessedAt.toUtc().toIso8601String(), 'requiresHumanReview': riskScore >= 0.65,
      'automatedDecisionAloneMustNotEnforceHighImpactAction': true};
  }

  static Map<String, dynamic> serviceStatus({required String serviceId, required String status,
      required DateTime updatedAt, String? publicMessage}) {
    if (serviceId.trim().isEmpty || !const {'operational','degraded','outage','maintenance'}.contains(status) ||
        (publicMessage?.length ?? 0) > 1000) throw ArgumentError('invalid_service_status');
    return {'serviceId': serviceId, 'status': status, 'updatedAt': updatedAt.toUtc().toIso8601String(),
      'publicMessage': publicMessage?.trim()};
  }
}
