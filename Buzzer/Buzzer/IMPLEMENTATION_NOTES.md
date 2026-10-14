# BusMate iOS — Implementation Notes

**Last updated:** 13 October 2025  
**Developer:** Noel Benson Swarna (ABN 19 833 739 158)

---

## Architecture Overview

BusMate is a school transport management platform. The iOS app is built with SwiftUI + Firebase and supports four distinct portals — Admin, Driver, Parent, and Student — each behind role-based authentication.

```
BuzzerApp
└── RootView
    ├── LoginSelectionView          ← role picker (unauthenticated)
    ├── AdminPortalView             ← admin tab dashboard + sidebar
    ├── DriverPortalView            ← driver trip list + attendance
    ├── ParentPortalView            ← child tracker, live status
    └── StudentPortalView           ← read-only child tracker
    
    Overlays (always on top of portals):
    ├── FirstLoginConsentGateView   ← ToS + Privacy acceptance (first login only)
    └── AppLockView                 ← Face ID / Touch ID gate (every foreground)
```

### Key Services

| File | Responsibility |
|---|---|
| `AuthManager.swift` | Firebase Auth state, role resolution, consent flag |
| `FirestoreService.swift` | All Firestore read/write operations |
| `AppLockManager.swift` | Biometric lock state |
| `NotificationService.swift` | FCM push notification registration |

### Firebase Collections

| Collection | Contents |
|---|---|
| `schools` | School docs; `adminUid` field links to Firebase Auth UID |
| `drivers` | Driver docs; `email`, `isActive`, `passwordSet`, `dateOfBirth` |
| `parents` | Parent docs; `email`, `isActive`, `passwordSet`, `dateOfBirth`, `childIds` |
| `students` | Student records; created by admins/parents |
| `routes` | Bus routes per school |
| `trips` | Individual trip instances with `studentRecords` array |
| `passengerNotes` | Soft-deletable notes attached to students |
| `activityLog` | Admin/driver action audit trail |
| `consent_records` | **Legal** — one doc per userId, written on first-login consent |

---

## Authentication Flow

1. User selects role on `LoginSelectionView`
2. Email + password sign-in (`EmailSignInView`) or admin OTP/magic link (`AdminLoginView`)
3. First-time users go through `PasswordSetupView` (`passwordSet == false`)
4. `AuthManager.resolveRole()` determines role from Firestore after Firebase Auth success
5. **`checkConsentIfNeeded()`** checks `consent_records/{userId}` — sets `consentRequired = true` if no record exists
6. `RootView` shows `FirstLoginConsentGateView` overlay if `consentRequired == true`
7. On consent acceptance, `consent_records/{userId}` is written, gate dismissed
8. `AppLockView` biometric gate fires every time app returns to foreground

---

## Legal & Compliance — What Has Been Built

### Documents (website — `busmate-website/src/content/legal/`)

| File | Status |
|---|---|
| `privacy-policy.ts` | Draft v0.1.0 — awaiting lawyer review |
| `terms-of-service.ts` | Draft v0.1.0 — awaiting lawyer review |

Both documents are governed by Australian law (Privacy Act 1988 (Cth), Australian Privacy Principles, Spam Act 2003 (Cth), Australian Consumer Law). `notReviewed: true` flag is set on both and must not be changed until a qualified Australian lawyer approves them.

### iOS Legal Infrastructure (`Buzzer/Legal/`)

| File | Purpose |
|---|---|
| `LegalDocument.swift` | Enum of approved documents with validated HTTPS URLs |
| `LegalDocumentPresenter.swift` | `@Observable` state driver for in-app document sheets |
| `SafariView.swift` | `SFSafariViewController` wrapper (URL-allowlisted to busmate.com.au) |
| `RegistrationConsentView.swift` | Reusable clickwrap control + `ConsentRecord` struct |
| `FirstLoginConsentGateView.swift` | Full-screen first-login consent gate |
| `LegalAndPrivacyView.swift` | Settings screen for viewing legal docs in-app |
| `DeleteAccountView.swift` | In-app account deletion (APP 11.2 compliance) |
| `AccountDeletionService.swift` | Firestore soft-delete + Firebase Auth deletion |
| `MailComposeView.swift` | In-app mail composer for support/legal contact |

### Consent Gate — How It Works

On every first login (any portal), `RootView` shows `FirstLoginConsentGateView` as a full-screen overlay. The user sees:

- Links to open the current Terms of Service and Privacy Policy in Safari
- Version numbers for each document
- A checkbox: "I agree to the Terms of Service and acknowledge that I have read the Privacy Policy"
- A "Continue to BusMate" button (disabled until the checkbox is ticked)

On acceptance, the following is written to Firestore `consent_records/{userId}`:

```
{
  userId:               String   // Firebase Auth UID
  termsVersion:         String   // e.g. "1.0"
  privacyPolicyVersion: String   // e.g. "1.0"
  acceptedAt:           String   // ISO 8601 UTC timestamp
  recordedAt:           Timestamp // Firestore server timestamp
}
```

The gate is never shown again once a record exists for the user.

### Age Enforcement

Minimum ages are enforced at account creation time in the admin UI:

| Role | Minimum Age | Enforced In |
|---|---|---|
| Administrator | 21 years | Admin accounts created by BusMate manually |
| Driver | 21 years | `AddDriverSheet` — DoB `DatePicker` with `...maxDateOfBirth` range |
| Parent / Guardian | 18 years | `AddStudentEntrySheet` — DoB `DatePicker` with `...maxDateOfBirth` range |
| Student | None | Records created by admins/parents; no direct accounts |

---

## Infrastructure Regions (Confirmed 13 Oct 2025)

| Provider | Service | Region |
|---|---|---|
| Firebase / Google | Auth, Firestore, Storage, FCM | `australia-southeast2` (Melbourne) |
| Supabase | Website demo request DB | `ap-southeast-2` primary (Sydney) / `ap-northeast-1` replica (Tokyo) |
| Resend | Transactional email | `ap-northeast-1` (Tokyo) |
| Vercel | Website hosting | `ap-southeast-2 / syd1` (Sydney) |

---

## Open Placeholders in Legal Documents

The header comments in both `.ts` files track every unresolved item. Summary as at 13 October 2025:

### Terms of Service (`terms-of-service.ts`)

| § | Status | Notes |
|---|---|---|
| §1 Acceptance logging | **Done** | `FirstLoginConsentGateView` + `consent_records` Firestore collection |
| §3 Minimum ages | **Done** | Confirmed: admin 21, driver 21, parent 18, student none |
| §4/§10/§19 Contract name | **Done** | "Subscription Agreement" throughout |
| §5 App Store terms | **Pending** | Review Apple's current App Store Review Guidelines before submission |
| §7 Cancellation terms | **Done** | No lock-in, 30-day notice, no refund on customer cancellation |
| §16 Liability cap | **Done** | AUD $500 flat aggregate cap confirmed |

### Privacy Policy (`privacy-policy.ts`)

| § | Status | Notes |
|---|---|---|
| §5 Analytics/marketing | **Done** | No tools in use; section will need updating if any are added |
| §10 Retention schedule | **Done** | 12mo active / 7yr attendance / 3yr support / 90d logs |
| §13 Contract name | **Done** | "Subscription Agreement" throughout |
| Provider DPAs | **Pending** | Each provider's DPA must be reviewed before publication (marked CONFIRM inline) |
| Provider subprocessor lists | **Pending** | Each provider's subprocessor list must be verified (marked CONFIRM inline) |

---

## Remaining TODO

See the TODO section below.

---

## Code Style

- SwiftUI with `@Observable` (not `ObservableObject`) for all services
- `async`/`await` throughout — no Combine
- `@Environment` for dependency injection into views
- `@MainActor` on all `@Observable` classes that touch UI state
- 4-space indentation, PascalCase types, camelCase properties

---

## Version History

### Current (October 2025)
- Multi-portal Firebase architecture (Admin, Driver, Parent, Student)
- Role-based auth with `AuthManager`
- Biometric app lock (`AppLockManager`)
- Full legal infrastructure: consent gate, in-app document viewer, account deletion
- Age enforcement at account creation (driver 21+, parent 18+)
- First-login ToS + Privacy acceptance gate with Firestore write
- Admin portal: dashboard, drivers, students, schedule, logs
- Driver portal: trip list, attendance tracking, substitute driver assignment
- Parent portal: live bus status, child tracker, passenger notes
- Student portal: read-only tracker
- Report generation: CSV + XLSX export

### Earlier phases (pre-Firebase)
- Phase 1: Core Data attendance lists
- Phase 2: Pick-up / drop-off session tracking
