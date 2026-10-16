#!/usr/bin/env python3
"""Offline static checks for PASS136; does not replace Dart/Flutter/Firebase tests."""
from pathlib import Path
import json, re, sys
root = Path(__file__).resolve().parents[1]
service = root / 'lib/services/business_platform_service.dart'
source = service.read_text()
checks = {
    'subscription plans and renewal grace': ['subscriptionPlans', 'renewalGraceEnd', 'subscriptionState'],
    'invoice tax calculation': ['calculateInvoice', 'taxRatePercent', 'invalid_invoice_amount'],
    'promotion/coupon/referral rules': ['promotionIsActive', 'couponCanBeUsed', 'referralEligible'],
    'multilingual content and service comparison': ['localizedContent', 'compareServices'],
    'saved search and support tickets': ['savedSearch', 'supportTicket'],
    'accessibility/offline/storage': ['accessibilityPreferences', 'offlineCachePolicy', 'storageSummary'],
    'session/account deletion/backup': ['sessionExpiry', 'accountDeletionRequest', 'backupManifest'],
}
for label, tokens in checks.items():
    missing = [token for token in tokens if token not in source]
    if missing:
        print(f'FAIL {label}: missing {missing}')
        sys.exit(1)
rules = (root / 'firestore.rules').read_text()
for token in ['match /savedSearches/{searchId}', 'match /platformPreferences/{preferenceId}', 'match /supportTickets/{ticketId}']:
    if token not in rules:
        print('FAIL missing rules: ' + token); sys.exit(1)
pub = (root / 'pubspec.yaml').read_text()
gradle = (root / 'android/app/build.gradle').read_text()
if 'version: 1.0.0+76' not in pub or 'versionCode 76' not in gradle:
    print('FAIL version metadata mismatch'); sys.exit(1)
json.loads((root / 'firestore.indexes.json').read_text())
json.loads((root / 'android/app/google-services.json').read_text())
print('PASS PASS136 service coverage tokens: 7 groups')
print('PASS PASS136 Firestore rule blocks: 3')
print('PASS version metadata: 1.0.0+76 / versionCode 76')
print('PASS JSON parsing: firestore.indexes.json, google-services.json')
print('LIMITATION: static token checks do not prove Dart compilation, rule compilation, or runtime behavior')
