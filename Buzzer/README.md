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
│   │   ├── DriverLoginView.swift       Phone OTP login for drivers
│   │   ├── ParentLoginView.swift       Phone OTP login for parents
│   │   ├── AdminLoginView.swift        Email magic link (real device) or OTP (simulator)
│   │   └── StudentLoginView.swift      Phone OTP login for students (file lives at project root)
│   │
│   ├── Driver Portal
│   │   ├── DriverPortalView.swift      Main driver hub. Two tabs: Schedule and All Routes.
│   │   ├── DriverScheduleView.swift    Today's assigned trips.
│   │   ├── DriverAllRoutesView.swift   All trips across all dates, grouped by date.
│   │   └── TripDetailView.swift        Detailed view of a single trip. Mark students on/off bus.
│   │
│   ├── Parent Portal
│   │   ├── ParentPortalView.swift      Main parent hub. Real-time child bus status.
│   │   ├── PassengerNoteView.swift     Create a note for the driver.
│   │   ├── PassengerNotesListView.swift List all notes created by this parent.
│   │   ├── PassengerNoteManager.swift  Core Data storage for passenger notes.
│   │   └── ProfileView.swift           Parent account settings.
│   │
│   ├── Student Portal
│   │   └── StudentPortalView.swift     Student's view of their route, driver, schedule, and notes. (file lives at project root)
│   │
│   ├── Admin Portal
│   │   ├── AdminPortalView.swift       Admin hub. Sidebar navigation.
│   │   ├── AdminDashboardView.swift    Today's operations overview.
│   │   ├── AdminDriversView.swift      List, add, and view drivers.
│   │   ├── AdminScheduleView.swift     List, create, and manage routes with inline student entry.
│   │   ├── AdminStudentsView.swift     Read-only view of all students by route.
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
| FirebaseAuth              | User authentication (phone OTP, custom token)             |
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

| Role    | Login Method                                            | Portal                   |
|---------|---------------------------------------------------------|--------------------------|
| Driver  | Phone number + SMS OTP (Firebase PhoneAuth)             | `DriverPortalView`       |
| Parent  | Phone number + SMS OTP (Firebase PhoneAuth)             | `ParentPortalView`       |
| Student | Phone number + SMS OTP (Firebase PhoneAuth)             | `StudentPortalView`      |
| Admin   | Email magic link (real device) or email OTP (simulator) | `AdminPortalView`        |

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

`sendOTP(to phoneNumber: String)` — Step 1 of driver/parent/student login. Sends an SMS OTP using Firebase PhoneAuthProvider.

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

`fetchTodaysTrips(forStudentIds:schoolId:)` — Returns today's trips containing any of the given student IDs (used in parent portal).

`startTrip(id:)` — Sets a trip's status to `inProgress` and records `startedAt`.

`updateStudentStatus(tripId:studentId:status:)` — Updates a student's status in a trip's `studentRecords` array. If all students are resolved, auto-sets the trip status to `completed`.

`fetchStudents(for parentId:childIds:)` — Returns all student documents linked to a parent.

`fetchActiveNotes(for studentId:)` — Returns non-deleted passenger notes for a student that haven't expired yet.

`addPassengerNote(_:)` — Writes a passenger note to the `passengerNotes` collection.

`logActivity(schoolId:actorId:actorName:actorRole:action:metadata:)` — Writes an entry to the `activityLog` collection.

### `FirestoreModels.swift`
Swift structs that map to Firestore documents. All structs conform to `Codable` and `Identifiable`.
Every entity has a required `schoolId: String` field (FK → `schools/{schoolId}`) so data is fully isolated between schools.

| Struct                    | Firestore Collection | Purpose                                        |
|---------------------------|----------------------|------------------------------------------------|
| `School`                  | `schools`            | Root entity. One per school.                   |
| `Driver`                  | `drivers`            | Driver profile, bus registration, and status   |
| `Student`                 | `students`           | Student profile, route, stop locations, and schedule |
| `Parent`                  | `parents`            | Parent profile, linked children, FCM token     |
| `Route`                   | `routes`             | Bus route with driver ID, student IDs, and dates |
| `Trip`                    | `trips`              | One trip instance (pickup or dropoff) per day  |
| `StudentTripRecord`       | (embedded in Trip)   | One student's status snapshot within a trip    |
| `FirestorePassengerNote`  | `passengerNotes`     | Note from a parent (or admin) to a driver      |
| `ActivityLog`             | `activityLog`        | Audit log entry                                |

Key fields on `Student`: `stopAddressAM`, `stopAddressPM` (separate morning and afternoon stops), `orderAM`, `orderPM` (stop sequence numbers for the driver app).
`StudentTripRecord` mirrors `stopAddressAM`, `stopAddressPM`, `orderAM`, `orderPM` as a snapshot at trip-creation time.
`Driver` includes `busRegistration` (the bus assigned to that driver). `Route` also includes `busRegistration?` (the bus running this route). Bus rego is globally unique across all schools.

### `NotificationService.swift`
Handles sending push notifications via FCM.
Does not call FCM directly. Writes a document to the `notificationQueue` Firestore collection.
A Firebase Cloud Function watches this collection and sends the actual FCM message to the parent's device.

`notifyParents(studentId:studentName:status:tripType:driverName:)` — Builds the notification payload (title + body) based on student status and trip type, then writes it to `notificationQueue`.

### `StudentPortalView.swift`
The student-facing portal. Read-only.
Shows a greeting, driver and bus info, route and stop details, a 14-day schedule calendar strip with scheduled days highlighted, and any active parent notes for the student.
Fetches data on load and supports pull-to-refresh.

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
| `drivers`           | One per driver           | `schoolId`, `name`, `phone`, `busRegistration`, `isActive`, `fcmToken`        |
| `students`          | One per student          | `schoolId`, `name`, `grade`, `stopAddressAM`, `stopAddressPM`, `orderAM`, `orderPM`, `routeId`, `authorisedParentIds[]` |
| `parents`           | One per parent           | `schoolId`, `name`, `phone`, `childIds[]`, `fcmToken`, `profileCompleted`     |
| `routes`            | One per bus route        | `schoolId`, `name`, `driverId`, `busRegistration?`, `studentIds[]`, `scheduledDays[]`, `isActive` |
| `trips`             | One per trip per day     | `schoolId`, `routeId`, `driverId`, `substituteDriverId?`, `date`, `type`, `status`, `studentRecords[]` |
| `passengerNotes`    | One per note             | `schoolId`, `studentId`, `noteText`, `fromDate`, `toDate`, `isDeleted`        |
| `activityLog`       | One per logged action    | `schoolId`, `actorId`, `actorRole`, `action`, `timestamp`                     |
| `notificationQueue` | One per notification     | `studentId`, `studentName`, `status`, `tripType`, `title`, `body`, `sent`     |
| `adminOtps`         | One per OTP request      | `otp`, `expiresAt` (used by iOS admin login on simulator only)                |
| `adminSigninTokens` | One per magic link token | `token`, `expiresAt` (used by WAC and iOS admin login on real devices)        |

---

## 7. Authentication Flows

### Driver Login
```
DriverLoginView: select driver from list, enter phone number
       │
       ▼
FirestoreService.fetchDriver() verifies phone matches Firestore record (last 9 digits)
       │
       ▼
authManager.sendOTP(to: normalisedPhone)
  Firebase PhoneAuthProvider sends SMS OTP
       │
       ▼
Driver enters 6-digit OTP
       │
       ▼
authManager.verifyOTP(verificationID:code:)
  Firebase Auth signs in the driver
       │
       ▼
AuthManager.resolveRole() checks drivers collection
Sets currentRole = .driver → DriverPortalView
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

### Student Login
```
StudentLoginView enters phone number
       │
       ▼
FirestoreService.fetchStudentByPhone() verifies the number exists in the students collection
       │
       ▼
authManager.sendOTP(to: normalisedPhone)
  Firebase PhoneAuthProvider sends SMS OTP
       │
       ▼
Student enters 6-digit OTP
       │
       ▼
authManager.verifyOTP(verificationID:code:)
  Firebase Auth signs in the student
       │
       ▼
AuthManager.resolveRole() checks students collection
Sets currentRole = .student → StudentPortalView
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
- **Methods:** Phone OTP (driver, parent, student), custom token (admin).
- **Config file:** `GoogleService-Info.plist`

### Firebase Firestore
- **Purpose:** Primary cloud database.
- **Database name:** `busmate-db`
- **Project ID:** `busmate-de66c`

### Firebase Cloud Messaging (FCM)
- **Purpose:** Push notifications to parents when their child's bus status changes.
- **Setup:** `BusMate.entitlements` enables push notifications. `BuzzerApp.swift` registers the device.

### WAC API (Web Admin Console)
- **Purpose:** Admin authentication. The app calls WAC API routes for both magic link and OTP flows.
- **Endpoints used:**
  - `POST /api/admin-signin-link/send` — Request magic link (real device)
  - `POST /api/admin-signin-link/verify` — Verify magic link token, receive custom token (real device)
  - `POST /api/admin-otp/send` — Request OTP (simulator fallback)
  - `POST /api/admin-otp/verify` — Verify OTP, receive custom token (simulator fallback)
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
