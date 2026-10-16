#!/usr/bin/env python3
"""Offline structural checks for PASS137; not a Dart compiler or backend test."""
from pathlib import Path
import json, re, sys
root = Path(__file__).resolve().parents[1]
service = root / 'lib/services/trust_safety_release_service.dart'
s = service.read_text()
groups = {
 'consent/privacy': ['consentReceipt', 'privacyConsent'],
 'abuse/block/mute/follow': ['rateLimitAllows', 'userBlock', 'muteRule', 'followerRequest'],
 'drafts/media/moderation': ['postDraft', 'validateMedia', 'moderationCase'],
 'notification policy/retries': ['notificationPolicy', 'notificationRetrySchedule'],
 'timezone/data export/retention': ['timeZone', 'userDataExportRequest', 'retentionPolicy'],
 'security incidents/feature rollout/release gate/updates': ['securityIncident', 'featureEnabled', 'releaseGate', 'updatePolicy'],
}
for label, tokens in groups.items():
    missing = [t for t in tokens if t not in s]
    if missing:
        print(f'FAIL {label}: missing {missing}'); sys.exit(1)
if "version: 1.0.0+77" not in (root/'pubspec.yaml').read_text():
    print('FAIL pubspec version'); sys.exit(1)
if not re.search(r'versionCode\s+77\s*;', (root/'android/app/build.gradle').read_text()):
    print('FAIL Android versionCode'); sys.exit(1)
json.loads((root/'firestore.indexes.json').read_text())
json.loads((root/'android/app/google-services.json').read_text())
print('PASS six PASS137 policy groups and required methods present')
print('PASS pubspec and Android build metadata both 1.0.0+77 / build 77')
print('PASS Firestore index and Google services JSON parse')
print('LIMITATION: does not prove Dart compilation, Firebase rules, backend enforcement, or device runtime')
