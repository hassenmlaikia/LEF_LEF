# LEF_LEF PASS20

Source: LEF_LEF_CORE_COMPLETE_PASS19.zip.

- Replaced Home Discover dead snackbar with real navigation to Explore.
- Added real service/company directory publishing flow from Explore.
- Hardened owner role rule so the existing Owner account cannot demote itself; UID remains immutable.
- Preserved all PASS19 flows.

Verification: static source scan and ZIP integrity. Flutter analyze/build remains UNKNOWN when Flutter SDK is unavailable.
