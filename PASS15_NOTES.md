# LEF_LEF PASS15

Source: LEF_LEF_CORE_COMPLETE_PASS14.zip.

## Completed
- Added capability model for Owner/Manager/Moderator/provider roles.
- Added real role-request workflow: non-client provider roles are requested and stay Client until Owner/Manager approval.
- Added Owner Control Center pending-request review (approve/reject) and capability visibility.
- Added Firestore rules for roleRequests.
- Added route-stage map message pins for pickup, live service stage and destination; existing provider live-location marker remains active.
- Preserved PASS14 ride pricing, high-value confirmations, GPS pickup and provider tracking.

## Verification
- ZIP/source structure inspected from PASS14 before modification.
- Static Dart/rules scan and ZIP integrity are performed for this pass.
- Flutter analyze/build remain UNKNOWN in this execution environment unless Flutter SDK is available.
