# PASS93 — Provider application and document verification

- Replaced the simple role-request tap with a dedicated application form for Driver, Delivery Provider, and Partner.
- Collects applicant name and phone; driver/delivery applications collect vehicle type, model, plate; partner applications collect company name and registration/tax identifier.
- Requires identity plus driving licence, vehicle registration, and insurance for driver/delivery applications; requires identity and company registration for partner applications.
- Uploads documents to private `roleApplications/{uid}/{requestId}/...` Storage paths (10 MiB maximum each) and stores paths, not public download URLs, in the Firestore request.
- Owner review cards now show applicant and vehicle/company details and allow the authorized reviewer to inspect uploaded document images before approving/rejecting.
- Approval marks the provider verified, copies submitted vehicle data into the user profile, and forces availability off until the provider turns it on.
- Ride discovery/offer/accept client logic and Firestore provider access now require `providerVerified == true`; a provider cannot self-enable availability before approval.
- Firestore request creation validates required identity/contact/document fields; Storage rules restrict application documents to the applicant and bootstrap owner.

Validation: static audit and ZIP integrity checks are run for this pass. Flutter analyze/build, Firebase emulator tests, and deployment of Firestore/Storage rules are not available in this environment; deploy both rules files to Firebase before relying on server-side enforcement.
