# BusMate — TODO List

**Last updated:** 13 October 2025

---

## Legal & Compliance

### Before App Store submission

- [ ] **ToS §5 — Apple App Store terms**  
  Review Apple's current App Store Review Guidelines and Developer Agreement for any required clauses (e.g. in-app purchase handling, subscription management). Add any required text to `terms-of-service.ts` §5.

- [ ] **Lawyer review — both documents**  
  Send `privacy-policy.ts` and `terms-of-service.ts` to a qualified Australian lawyer for review and approval. Do NOT set `notReviewed: false` or publish either document until approval is received.

- [ ] **Provider DPAs — review before publication**  
  Each provider entry in `privacy-policy.ts` §14 has a `CONFIRM` note. Before publication, verify and review:
  - Google Cloud / Firebase DPA (cloud.google.com/terms/data-processing-addendum)
  - Supabase DPA (supabase.com/privacy)
  - Resend DPA (check Resend's legal documentation)
  - Vercel DPA (vercel.com/legal/dpa)

- [ ] **Provider subprocessor lists — review before publication**  
  Each provider entry in `privacy-policy.ts` §14 has a `CONFIRM` note for subprocessors. Before publication, review:
  - Google Cloud subprocessor list (cloud.google.com/terms/subprocessors)
  - Supabase subprocessor list (in Supabase privacy documentation)
  - Resend infrastructure / subprocessor list
  - Vercel subprocessor list (vercel.com/legal/privacy-policy)

- [ ] **Publish legal documents on website**  
  Deploy `privacy-policy.ts` and `terms-of-service.ts` content to busmate.com.au/privacy-policy and busmate.com.au/terms-of-service before any user can be asked to accept them.

- [ ] **Update document version strings in app**  
  After the lawyer-approved versions are published, update `kTermsVersion` and `kPrivacyPolicyVersion` in `LegalDocument.swift` to match the published version strings. These are used to stamp `consent_records` in Firestore.

- [ ] **Firestore security rules — `consent_records` collection**  
  Add security rules so that:
  - A user can only read/write their own `consent_records/{userId}` document
  - No user can delete or overwrite an existing consent record

- [ ] **WAC (web admin console) — consent gate after admin signup**  
  The user requested a consent gate on the web admin console after signup. This was built for the iOS app. The WAC equivalent still needs to be built: after an admin completes signup on `busmate-admin.vercel.app`, show a ToS + Privacy acceptance modal before they can access any functionality. Write the same `consent_records/{userId}` document to Firestore on acceptance.

---

## iOS App

- [ ] **Handle consent re-acceptance when document versions change**  
  Currently, `consent_records/{userId}` is checked only for existence. When ToS or Privacy Policy versions are updated, existing users should be re-prompted if their recorded version is older than the current version. Update `hasConsent(userId:)` in `FirestoreService` to compare stored versions against `LegalDocument.termsOfService.version` and `LegalDocument.privacyPolicy.version`.

- [ ] **Admin portal — account creation by BusMate**  
  Admin accounts are created manually by BusMate (not self-registered). Ensure each admin is walked through the consent gate on their first login. This is handled automatically by `FirstLoginConsentGateView` — verify it works correctly for the admin role.

- [ ] **Test consent gate on all four portals**  
  Manually verify the consent gate appears on first login and does not appear on subsequent logins for:
  - [ ] Admin portal (OTP / magic link login)
  - [ ] Driver portal (email + password)
  - [ ] Parent portal (email + password)
  - [ ] Student portal (email + password)

- [ ] **Offline / network error handling on consent gate**  
  If Firestore write fails in `FirstLoginConsentGateView`, the user sees an error message and can retry. Verify this works correctly when the device has no network connection.

---

## Infrastructure

- [ ] **Verify Firebase region in console**  
  Confirm that the `busmate-de66c` Firebase project is configured to `australia-southeast2` in the Firebase Console (Firestore location settings).

- [ ] **Verify Supabase region in dashboard**  
  Confirm that the Supabase project is set to `ap-southeast-2` (Sydney) primary, with `ap-northeast-1` (Tokyo) as backup/replica.

- [ ] **Verify Vercel deployment region**  
  Confirm that the `busmate-admin` Vercel project is set to `ap-southeast-2 / syd1` (Sydney) in the Vercel dashboard.

---

## Before Going Live with First Paying School

- [ ] Complete all items in **Legal & Compliance** above
- [ ] Execute a Subscription Agreement with the school
- [ ] Ensure the school has been briefed on their own obligations (privacy notices to parents/guardians, consent for student data, etc.)
- [ ] Test the full sign-in flow end-to-end for each role on a real device

---

## Deferred / Not Yet Started

- [ ] **WAC consent gate** (see Legal section above)
- [ ] **ToS §5 App Store terms** — deferred until App Store submission
- [ ] **Version-aware re-consent** — deferred until documents are finalised and versioned
