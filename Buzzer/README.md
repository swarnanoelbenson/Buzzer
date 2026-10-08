# BusMate — iOS App

**Project name:** BusMate (also referred to as Buzzer in the Xcode project)
**Purpose:** iOS app for school bus management. Serves four user roles: Driver, Parent, Student, Admin.
**Platform:** iOS 17.0+
**Language:** Swift
**UI Framework:** SwiftUI
**Backend:** Firebase (Firestore + Auth + Cloud Messaging)

---

## 1. Directory Structure

```
Buzzer/                             Xcode project root
├── Buzzer.xcodeproj/               Xcode project file
├── Buzzer/                         Main app source code
│   ├── BuzzerApp.swift             App entry point
│   ├── RootView.swift              Role-based navigation root
│   ├── AuthManager.swift           Authentication state manager
│   ├── FirestoreService.swift      All Firestore read/write operations
│   ├── FirestoreModels.swift       Codable data model structs
│   ├── FirestoreConfig.swift       Firebase initialisation config
│   ├── NotificationService.swift   Push notification handler (FCM)
│   │
│   ├── Login Views
│   │   ├── LoginSelectionView.swift    Choose user type (Driver/Parent/Student/Admin)
│   │   ├── DriverLoginView.swift       Email + setup code login for drivers
│   │   ├── ParentLoginView.swift       Phone OTP login for parents
│   │   ├── AdminLoginView.swift        Email magic link (real device) or OTP (simulator)
│   │   └── StudentLoginView.swift      Email + setup code login for students (project root)
│   │
│   ├── Driver Portal
│   │   ├── DriverPortalView.swift      Main driver hub. Dashboard with driver card,
│   │   │                               upcoming schedule list, search/filter/sort,
│   │   │                               and "Last 3 Days" history sheet.
│   │   └── TripDetailView.swift        Single trip view. Start trip, mark students
│   │                                   on/off/absent, per-student notes (driver CRUD).
│   │
│   ├── Parent Portal
│   │   ├── ParentPortalView.swift      Left-right pager (one page per child). Each page:
│   │   │                               Notes card (parent add/edit/delete own notes),
│   │   │                               Live Status card, Student Summary, Driver, Bus cards.
│   │   ├── PassengerNoteView.swift     Legacy note view (unused in new flow).
│   │   ├── PassengerNotesListView.swift Legacy note list (unused in new flow).
│   │   ├── PassengerNoteManager.swift  Core Data storage for passenger notes (legacy).
│   │   └── ProfileView.swift           Parent account settings.
│   │
│   ├── Student Portal
│   │   └── StudentPortalView.swift     Same card layout as parent portal but notes are
│   │                                   read-only. Shows all notes written about this
│   │                                   student (by any creator). (file lives at project root)
│   │
│   ├── Admin Portal
│   │   ├── AdminPortalView.swift       Admin hub. Sidebar navigation.
│   │   ├── AdminDashboardView.swift    Today's operations overview.
│   │   ├── AdminDriversView.swift      List, add, and view drivers.
│   │   ├── AdminScheduleView.swift     List, create, and manage routes with inline student entry.
│   │   ├── AdminStudentsView.swift     View all students by route. Admin can add/delete notes.
│   │   └── AdminLogsView.swift         View activity log with role filter.
│   │
│   ├── Developer / Admin Tools
│   │   ├── DeveloperMenuView.swift     Hidden debug menu for developers.
│   │   ├── DemoSeeder.swift            Seeds Firestore with sample data.
│   │   └── DemoModeManager.swift       Toggle between demo and production mode.
│   │
│   ├── Core Data Entities
│   │   ├── AttendanceSessionEntity+CoreDataClass.swift
│   │   ├── AttendanceSessionEntity+CoreDataProperties.swift
│   │   ├── AttendanceRecordEntity+CoreDataClass.swift
│   │   ├── AttendanceRecordEntity+CoreDataProperties.swift
│   │   ├── AttendeeEntity+CoreDataClass.swift
│   │   ├── AttendeeEntity+CoreDataProperties.swift
│   │   ├── AttendeeListEntity+CoreDataClass.swift
│   │   ├── AttendeeListEntity+CoreDataProperties.swift
│   │   ├── PassengerNoteEntity+CoreDataClass.swift
│   │   └── PassengerNoteEntity+CoreDataProperties.swift
│   │
│   ├── Utilities
│   │   ├── DataManager.swift           Core Data manager. Manages local storage.
│   │   ├── SessionManager.swift        Manages the state of an active trip session.
│   │   ├── TimestampFormatter.swift    Formats dates and times for display.
│   │   ├── AccessibilityHelpers.swift  Accessibility modifiers and utilities.
│   │   ├── StringExtensions.swift      Swift String helper extensions.
│   │   ├── CSVGenerator.swift          Generates CSV reports from session data.
│   │   ├── Models.swift                Shared Swift enums and structs.
│   │   └── PersistenceController.swift Core Data stack initialisation.
│   │
│   ├── Assets.xcassets/                App icons, colours, images.
│   ├── GoogleService-Info.plist        Firebase configuration file.
│   └── BusMate-Info.plist              App background modes (push notifications).
│
├── StudentPortalView.swift             Student portal (at project root — not inside Buzzer/)
├── StudentLoginView.swift              Student login (at project root — not inside Buzzer/)
├── ParentOnboardingView.swift          First-time parent onboarding (at project root)
├── BuzzerTests/                        Unit tests
│   └── BuzzerTests.swift
├── BusMate.entitlements                App entitlements (push notifications)
└── README.md                           This file
```

---

## 2. Languages Used

| Language | Purpose                             |
|----------|-------------------------------------|
| Swift    | All application code                |
| SwiftUI  | All UI screens and components       |

---

## 3. Libraries Used

All dependencies are managed via Swift Package Manager (SPM).

| Library                   | Purpose                                                   |
|---------------------------|-----------------------------------------------------------|
| FirebaseCore              | Firebase SDK initialisation                               |
| FirebaseAuth              | User authentication (phone OTP, email OTP, custom token)  |
| FirebaseFirestore         | Cloud database reads and writes                           |
| FirebaseMessaging         | Push notifications via FCM                                |
| Core Data                 | Local on-device data storage (Apple framework)            |
| SwiftUI                   | UI framework (Apple framework)                            |
| Foundation                | Core Swift system types (Apple framework)                 |
| UserNotifications         | Local and remote notification handling (Apple framework)  |
| Observation               | `@Observable` macro for state management (Apple, iOS 17+) |

---

## 4. User Roles

The app supports four roles. Each role sees a different portal after login.

| Role    | Login Method                                                           | Portal              |
|---------|------------------------------------------------------------------------|---------------------|
| Driver  | Email + setup code (admin-issued one-time code), then set own password | `DriverPortalView`  |
| Parent  | Phone number + SMS OTP (Firebase PhoneAuth)                            | `ParentPortalView`  |
| Student | Email + setup code (admin-issued one-time code), then set own password | `StudentPortalView` |
| Admin   | Email magic link (real device) or email OTP (simulator)                | `AdminPortalView`   |

`RootView.swift` reads `authManager.currentRole` and shows the correct portal.
`AuthManager.swift` determines the role by checking Firestore collections after login.

---

## 5. Key Files and Functions

### `BuzzerApp.swift`
The app entry point.
Initialises Firebase.
Sets up FCM (Firebase Cloud Messaging) for push notifications.
Handles universal links for admin magic-link sign-in.
Injects `AuthManager` into the SwiftUI environment.
Renders `RootView` as the first screen.

### `RootView.swift`
Reads `authManager.currentRole`.
Shows a loading spinner while auth state is resolving.
Routes to the correct portal: `DriverPortalView`, `ParentPortalView`, `StudentPortalView`, or `AdminPortalView`.
Shows `LoginSelectionView` when no user is signed in.

### `AuthManager.swift`
`@Observable` class. Runs on the main actor.

**Properties:**
- `currentRole: UserRole` — the active user's role (`.driver`, `.parent`, `.student`, `.admin`, `.none`)
- `currentUserId: String?` — the Firestore document ID for the active user
- `isLoading: Bool` — true while checking auth state on app launch

**Key functions:**

`listenToAuthState()` — Adds a Firebase Auth listener. Called on init. When Firebase fires, calls `resolveRole(for:)`.

`resolveRole(for uid: String)` — Checks Firestore collections in order (drivers → parents → students → schools) to find the user's role. Sets `currentRole` and `currentUserId`.

`sendOTP(to phoneNumber: String)` — Step 1 of parent login. Sends an SMS OTP using Firebase PhoneAuthProvider.

`verifyOTP(verificationID:code:)` — Step 2 of phone OTP login. Creates a phone auth credential and signs in.

`signInWithCustomToken(_:)` — Signs in an admin using a custom token returned by the WAC API.

`saveFCMToken(_:)` — Saves the device's FCM token to the user's Firestore document so the server can send push notifications to this device.

`signOut()` — Signs out the current user and resets `currentRole` to `.none`.

### `FirestoreService.swift`
Central service for all Firestore operations.
Accessed via `FirestoreService.shared` singleton.

**Key functions:**

`fetchAllDrivers(schoolId:)` — Returns all active drivers for a school.

`fetchRoutes(for driverId:schoolId:)` — Returns all active routes assigned to a driver.

`fetchTodaysTrips(for driverId:schoolId:)` — Returns today's trips for a driver.

`fetchTodaysTrips(forStudentIds:schoolId:)` — Returns today's trips containing any of the given student IDs (used in parent/student portal).

`fetchAllTrips(for driverId:schoolId:)` — Returns all upcoming trips (today + future) for a driver, sorted by date ascending.

`fetchRecentCompletedTrips(for driverId:schoolId:)` — Returns completed trips from the last 3 days for the driver history view.

`startTrip(id:)` — Sets a trip's status to `inProgress` and records `startedAt`.

`updateStudentStatus(tripId:studentId:status:)` — Updates a student's status in a trip's `studentRecords` array. If all students are resolved, auto-sets the trip status to `completed`.

`fetchStudents(for parentId:childIds:)` — Returns all student documents linked to a parent.

`fetchActiveNotes(for studentId:)` — Returns non-deleted passenger notes for a student that haven't expired yet.

`addPassengerNote(_:)` — Writes a passenger note to the `passengerNotes` collection. Returns the `DocumentReference` so the caller can build a complete local model with the Firestore-assigned ID.

`updatePassengerNote(id:noteText:fromDate:toDate:type:)` — Updates an existing note's text, date range, and trip type.

`deletePassengerNote(id:)` — Soft-deletes a passenger note by setting `isDeleted = true`.

`logActivity(schoolId:actorId:actorName:actorRole:action:metadata:)` — Writes an entry to the `activityLog` collection.

### `FirestoreModels.swift`
Swift structs that map to Firestore documents. All structs conform to `Codable` and `Identifiable`.
Every entity has a required `schoolId: String` field (FK → `schools/{schoolId}`) so data is fully isolated between schools.

| Struct                    | Firestore Collection | Purpose                                              |
|---------------------------|----------------------|------------------------------------------------------|
| `School`                  | `schools`            | Root entity. One per school.                         |
| `Driver`                  | `drivers`            | Driver profile, bus registration, and status         |
| `Student`                 | `students`           | Student profile, route, stop locations, and schedule |
| `Parent`                  | `parents`            | Parent profile, linked children, FCM token           |
| `Route`                   | `routes`             | Bus route with driver ID, student IDs, and dates     |
| `Trip`                    | `trips`              | One trip instance (pickup or dropoff) per day        |
| `StudentTripRecord`       | (embedded in Trip)   | One student's status snapshot within a trip          |
| `FirestorePassengerNote`  | `passengerNotes`     | Note from parent, driver, or admin about a student   |
| `ActivityLog`             | `activityLog`        | Audit log entry                                      |

Key fields on `Student`: `stopAddressAM`, `stopAddressPM` (separate morning and afternoon stops), `orderAM`, `orderPM` (stop sequence numbers for the driver app).
`StudentTripRecord` mirrors `stopAddressAM`, `stopAddressPM`, `orderAM`, `orderPM` as a snapshot at trip-creation time.
`Driver` includes `busRegistration` (the bus assigned to that driver). `Route` also includes `busRegistration?` (the bus running this route). Bus rego is globally unique across all schools.

`FirestorePassengerNote` uses `createdById` (Firebase Auth UID), `createdByName`, and `createdByRole` (`"parent"` | `"driver"` | `"admin"`) to track who wrote each note. Note cards are colour-coded: blue = driver, orange = parent, purple = admin.

**Note permissions:**
- Parents — create, edit, delete their own notes
- Drivers — create, edit, delete their own notes
- Admins — create, edit, delete any note
- Students — read-only (see all notes written about them)

### `NotificationService.swift`
Handles sending push notifications via FCM.
Does not call FCM directly. Writes a document to the `notificationQueue` Firestore collection.
A Firebase Cloud Function watches this collection and sends the actual FCM message to the parent's device.

`notifyParents(studentId:studentName:status:tripType:driverName:)` — Builds the notification payload (title + body) based on student status and trip type, then writes it to `notificationQueue`.

### `ParentPortalView.swift`
Left-right `TabView` pager — one full-screen page per linked child.
Page dots shown at top when the parent has more than one child.
Each child page contains five cards (scrollable):
1. **Notes** — all active notes for this child, colour-coded by creator role. Parent can add, edit (own), delete (own).
2. **Today's Status** — real-time pick-up and drop-off status rows with live Firestore listener.
3. **Student Summary** — name, grade, term, year, date range, AM stop + time, PM stop + time.
4. **Driver** — driver name and phone number.
5. **Bus** — bus registration number.

### `StudentPortalView.swift`
Same card layout as the parent portal (Notes, Status, Student Summary, Driver, Bus).
Notes are read-only — students can see all notes written about them by any creator (parent, driver, admin) but cannot add or modify notes.
Has a real-time Firestore listener for live trip status updates.

### `DriverPortalView.swift`
Single dashboard (no tabs). Contains:
- **Search bar** — filters the schedule list by route name.
- **Filter chips** — All / Pick-up / Drop-off.
- **Sort chips** — Date ↑ / Date ↓ / Pick-up First / Drop-off First.
- **Driver card** — name, phone, bus registration.
- **Upcoming schedule list** — all future trips (today included), each pickup and dropoff shown as a separate row.
- **"Last 3 Days" nav bar button** — opens `DriverHistoryView` sheet with the last 3 days of completed trips.

### `TripDetailView.swift`
Detailed view of a single trip.
Shows route name, date, student count, and trip status badge.
Start button (changes trip status to `inProgress`).
Progress bar while in progress.
Per-student `StudentTripCard` components — each card shows student name, stop, timestamp, action buttons (On Bus / Off Bus / Absent), and a collapsible notes section.
Drivers can add notes for a student (with date range picker), edit or delete their own notes.

### `ParentOnboardingView.swift`
Two-step first-login flow shown to parents whose `profileCompleted == false`.
Step 1: Shows linked children's names, grades, and scheduled pick-up/drop-off times for review.
Step 2: Prompts the parent to enter their name and select their relationship to the child.
On completion, writes `profileCompleted = true` to the parent's Firestore document, then navigates to `ParentPortalView`.

### `DeveloperMenuView.swift`
A hidden debug menu accessible from the login selection screen.
Functions: seed demo data, clear all local data, switch Firebase environment.
Remove before App Store submission.

---

## 6. Firestore Collections

| Collection          | Documents                | Key Fields                                                                    |
|---------------------|--------------------------|-------------------------------------------------------------------------------|
| `schools`           | One per school           | `schoolName`, `adminUid`, `fcmToken`                                          |
| `drivers`           | One per driver           | `schoolId`, `name`, `phone`, `email`, `busRegistration`, `isActive`, `passwordSet` |
| `students`          | One per student          | `schoolId`, `name`, `grade`, `stopAddressAM`, `stopAddressPM`, `orderAM`, `orderPM`, `routeId`, `authorisedParentIds[]`, `email`, `passwordSet` |
| `parents`           | One per parent           | `schoolId`, `name`, `phone`, `childIds[]`, `fcmToken`, `profileCompleted`     |
| `routes`            | One per bus route        | `schoolId`, `name`, `driverId`, `busRegistration?`, `studentIds[]`, `scheduledDays[]`, `isActive` |
| `trips`             | One per trip per day     | `schoolId`, `routeId`, `driverId`, `substituteDriverId?`, `date`, `type`, `status`, `studentRecords[]` |
| `passengerNotes`    | One per note             | `schoolId`, `studentId`, `noteText`, `fromDate`, `toDate`, `createdById`, `createdByName`, `createdByRole`, `isDeleted` |
| `activityLog`       | One per logged action    | `schoolId`, `actorId`, `actorRole`, `action`, `timestamp`                     |
| `notificationQueue` | One per notification     | `studentId`, `studentName`, `status`, `tripType`, `title`, `body`, `sent`     |
| `setupCodes`        | One per pending setup    | `code`, `expiresAt` (keyed by `schoolId:email`) — used for driver/student first-time login |

---

## 7. Authentication Flows

### Driver / Student Login (email + setup code)
```
DriverLoginView / StudentLoginView: select school, enter email
       │
       ▼
Admin sends a setup code to the driver/student via the admin web console
WAC API writes a time-limited code to setupCodes/{schoolId:email}
       │
       ▼
User enters 6-character setup code
       │
       ▼
POST /api/auth/verify-setup-code
  WAC API validates code, finds the user's Firestore doc
  Returns firestoreDocId, role, and either a custom token (existing Auth account)
  or a needsSignUp flag (new user who must set a password)
       │
       ▼
If needsSignUp: user sets a password, app calls Firebase createUserWithEmail
If existing:    app signs in with the custom token
       │
       ▼
AuthManager.resolveRole() sets currentRole → DriverPortalView / StudentPortalView
```

### Parent Login
```
ParentLoginView enters phone number
       │
       ▼
FirestoreService.fetchParentByPhone() verifies the number exists in the parents collection
       │
       ▼
authManager.sendOTP(to: normalisedPhone)
  Firebase PhoneAuthProvider sends SMS OTP
       │
       ▼
Parent enters 6-digit OTP
       │
       ▼
authManager.verifyOTP(verificationID:code:)
  Firebase Auth signs in the parent
       │
       ▼
AuthManager.resolveRole() checks parents collection
If profileCompleted == false → ParentOnboardingView
Else → sets currentRole = .parent → ParentPortalView
```

### Admin Login (real device — magic link)
```
AdminLoginView enters email
       │
       ▼
POST https://busmate-admin.vercel.app/api/admin-signin-link/send
  WAC API checks schools collection, generates 64-char token
  WAC API sends magic link email via Resend
       │
       ▼
Admin taps link in email → universal link opens app
       │
       ▼
BuzzerApp.swift handles the URL, calls authManager.handleMagicLink(url:)
POST https://busmate-admin.vercel.app/api/admin-signin-link/verify
  WAC API validates token, returns Firebase custom token
       │
       ▼
authManager.signInWithCustomToken(token)
  Firebase Auth signs in the admin
       │
       ▼
AuthManager.resolveRole() checks schools collection
Sets currentRole = .admin → AdminPortalView
```

### Admin Login (simulator fallback — email OTP)
```
AdminLoginView enters email
       │
       ▼
POST https://busmate-admin.vercel.app/api/admin-otp/send
  WAC API checks schools collection, sends 6-digit OTP email via Resend
       │
       ▼
Admin enters 6-digit OTP
       │
       ▼
POST https://busmate-admin.vercel.app/api/admin-otp/verify
  WAC API validates OTP, returns Firebase custom token
       │
       ▼
authManager.signInWithCustomToken(token) → AdminPortalView
```

---

## 8. Push Notifications (FCM)

**Flow:**
```
Driver marks student as onBus / offBus / absent
       │
       ▼
NotificationService.notifyParents() writes to notificationQueue collection
       │
       ▼
Firebase Cloud Function detects new document
Cloud Function fetches parent FCM tokens from parents collection
Cloud Function sends FCM message to parent devices
       │
       ▼
Parent device receives push notification
```

**FCM token lifecycle:**
- On login, `authManager.saveFCMToken()` saves the current device token to Firestore.
- When FCM refreshes the token, `BuzzerApp.swift` posts a notification and `AuthManager` saves the new token.

---

## 9. Data Storage: Firestore vs Core Data

The app uses two separate storage systems.

| Storage    | What it stores                                                                        |
|------------|---------------------------------------------------------------------------------------|
| Firestore  | All live operational data: drivers, students, parents, routes, trips, passenger notes |
| Core Data  | Local attendance lists and sessions (legacy driver offline flow)                      |

---

## 10. External Services

### Firebase Auth
- **Purpose:** User authentication for all four roles.
- **Methods:** Phone OTP (parent), email + setup code (driver, student), custom token (admin).
- **Config file:** `GoogleService-Info.plist`

### Firebase Firestore
- **Purpose:** Primary cloud database.
- **Database name:** `busmate-db`
- **Project ID:** `busmate-de66c`

### Firebase Cloud Messaging (FCM)
- **Purpose:** Push notifications to parents when their child's bus status changes.
- **Setup:** `BusMate.entitlements` enables push notifications. `BuzzerApp.swift` registers the device.

### WAC API (Web Admin Console)
- **Purpose:** Admin authentication and driver/student account setup.
- **Endpoints used:**
  - `POST /api/admin-signin-link/send` — Request magic link (real device)
  - `POST /api/admin-signin-link/verify` — Verify magic link token, receive custom token (real device)
  - `POST /api/admin-otp/send` — Request OTP (simulator fallback)
  - `POST /api/admin-otp/verify` — Verify OTP, receive custom token (simulator fallback)
  - `POST /api/auth/verify-setup-code` — Verify driver/student setup code, receive custom token or needsSignUp flag
- **Base URL:** `https://busmate-admin.vercel.app`

---

## 11. App Capabilities

Set in `BusMate.entitlements`:

| Capability          | Value         | Purpose                               |
|---------------------|---------------|---------------------------------------|
| Push Notifications  | development   | Receive FCM push notifications        |
| Associated Domains  | webcredentials, applinks | Universal links for admin magic-link sign-in |

---

## 12. Build and Run

### Requirements
- macOS 14+
- Xcode 15+
- iOS 17.0+ simulator or physical device
- Firebase project access (for Firestore reads)

### Steps
1. Open `Buzzer.xcodeproj` in Xcode.
2. Select the **BusMate** target.
3. Go to **Signing & Capabilities** and select your Apple Developer Team.
4. Select a simulator or connected device.
5. Press Run (⌘R).

### Firebase configuration
`GoogleService-Info.plist` is already included in the project.
It points to the `busmate-de66c` Firebase project.
Do not commit changes to this file without team approval.

---

## 13. Developer Menu

A hidden developer menu is available on the login selection screen.
Tap the small "Developer Menu" text at the bottom of the screen.
Use this menu to seed demo data or reset the app state during development.
Remove this button before submitting to the App Store.
