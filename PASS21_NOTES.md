# LEF_LEF PASS21

Source: LEF_LEF_CORE_COMPLETE_PASS20.zip.

Changes:
- Provider workspace now filters requests by the provider's approved service domain: drivers see passenger/SOS/ambulance services, delivery providers see delivery services, and partners see all service requests.
- Emergency SOS requests are visually marked in the provider queue.
- Fixed role-request error messaging so a failed request is not reported as successfully sent.
- Increased provider request queue visibility to 50 records while retaining Firestore-side authorization.

Verification:
- Source extracted directly from PASS20.
- Dart static marker scan and bracket-balance check performed.
- ZIP integrity tested.
- Flutter analyze/build remain UNKNOWN because Flutter SDK is unavailable in this execution environment.
