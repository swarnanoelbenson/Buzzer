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
├── Buzzer/                         Main app source code (71 Swift files)
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
│   │   ├── ParentLoginView.swift       Email + password login for parents
│   │   ├── StudentLoginView.swift      Email + password login for students
│   │   ├── AdminLoginView.swift        Email OTP login for admins (via WAC API)
│   │   └── ParentOnboardingView.swift  First-time profile setup for new parents
│   │
│   ├── Driver Portal
│   │   ├── DriverPortalView.swift      Main driver hub. Shows today's routes.
│   │   ├── DriverScheduleView.swift    Driver's assigned routes.
│   │   ├── DriverAllRoutesView.swift   Expanded view of all route details.
│   │   ├── TripDetailView.swift        Detailed view of a single trip.
│   │   ├── SessionSelectionView.swift  Choose pickup or dropoff session.
│   │   ├── AttendanceTrackingView.swift Mark students on/off bus.
│   │   ├── SessionDetailView.swift     View a completed session's records.
│   │   ├── SessionHistoryView.swift    List of past sessions.
│   │   ├── SessionReviewView.swift     Post-session review screen.
│   │   ├── UnmarkedReviewView.swift    Review students not yet marked.
│   │   └── FinalCheckView.swift        Final confirmation before closing session.
│   │
│   ├── Parent Portal
│   │   ├── ParentPortalView.swift      Main parent hub. Shows children's bus status.
│   │   ├── PassengerNoteView.swift     Create a note for the driver.
│   │   ├── PassengerNotesListView.swift List all notes created by this parent.
│   │   ├── PassengerNoteManager.swift  Core Data storage for passenger notes.
│   │   └── ProfileView.swift           Parent account settings.
│   │
│   ├── Student Portal
│   │   └── StudentPortalView.swift     Student's view of their route and status.
│   │
│   ├── Admin Portal
│   │   ├── AdminPortalView.swift       Admin hub. Four tabs.
│   │   ├── AdminDriversView.swift      List and add drivers.
│   │   ├── AdminScheduleView.swift     List and create routes with student entries.
│   │   ├── AdminStudentsView.swift     Read-only view of all students by route.
│   │   └── AdminLogsView.swift         View activity log with role filter.
│   │
│   ├── Shared Components
│   │   ├── ListsView.swift             Manage attendance lists (legacy local use).
│   │   ├── ListDetailView.swift        View a list's attendees.
│   │   ├── CreateListView.swift        Create a new list.
│   │   ├── AddAttendeeView.swift       Add a student to a list.
│   │   ├── EditAttendeeView.swift      Edit a student in a list.
│   │   ├── AttendeeProfileView.swift   View a student's profile.
│   │   └── IncompleteSessionSheet.swift Sheet shown when a session was interrupted.
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
| FirebaseAuth              | User authentication (phone OTP, email, custom token)      |
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

| Role    | Login Method                          | Portal                   |
|---------|---------------------------------------|--------------------------|
| Driver  | Phone number + SMS OTP (Firebase)     | `DriverPortalView`       |
| Parent  | Email + password (Firebase)           | `ParentPortalView`       |
| Student | Email + password (Firebase)           | `StudentPortalView`      |
| Admin   | Email + 6-digit OTP (via WAC API)     | `AdminPortalView`        |

`RootView.swift` reads `authManager.currentRole` and shows the correct portal.
`AuthManager.swift` determines the role by checking Firestore collections after login.

---

## 5. Key Files and Functions

### `BuzzerApp.swift`
The app entry point.
Initialises Firebase.
Sets up FCM (Firebase Cloud Messaging) for push notifications.
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

`sendOTP(to phoneNumber: String)` — Step 1 of driver login. Sends an SMS OTP using Firebase PhoneAuthProvider.

`verifyOTP(verificationID:code:)` — Step 2 of driver login. Creates a phone auth credential and signs in.

`signInParent(email:password:)` — Signs in a parent with email and password.

`signInStudent(email:password:)` — Signs in a student with email and password.

`signInWithCustomToken(_:)` — Signs in an admin using a custom token returned by the WAC API.

`saveFCMToken(_:)` — Saves the device's FCM token to the user's Firestore document so the server can send push notifications to this device.

`signOut()` — Signs out the current user and resets `currentRole` to `.none`.

### `FirestoreService.swift`
Central service for all Firestore operations.
Accessed via `FirestoreService.shared` singleton.

**Key functions:**

`fetchDriverRoutes(driverId:)` — Returns all active routes assigned to a driver.

`fetchTodayTrips(for routeId:)` — Returns today's pickup and dropoff trip documents for a route.

`startTrip(tripId:)` — Sets a trip's status to `inProgress` and records `startedAt`.

`updateStudentStatus(tripId:studentId:status:)` — Updates a student's status in a trip's `studentRecords` array. If all students are marked, sets the trip status to `completed`.

`fetchStudentsForParent(parentId:)` — Returns all student documents linked to a parent.

`createPassengerNote(_:)` — Writes a passenger note to Firestore.

`logActivity(actorId:actorName:actorRole:action:metadata:)` — Writes an entry to the `activityLog` collection.

### `FirestoreModels.swift`
Swift structs that map to Firestore documents. All structs conform to `Codable` and `Identifiable`.

| Struct                 | Firestore Collection | Purpose                                   |
|------------------------|----------------------|-------------------------------------------|
| `Driver`               | `drivers`            | Driver profile and status                 |
| `Student`              | `students`           | Student profile, route, and schedule      |
| `Parent`               | `parents`            | Parent profile and linked children        |
| `Route`                | `routes`             | Bus route with driver and student IDs     |
| `Trip`                 | `trips`              | One trip instance (pickup or dropoff)     |
| `StudentTripRecord`    | (inside Trip)        | One student's status within a trip        |
| `FirestorePassengerNote` | `passengerNotes`  | Note from a parent to a driver            |
| `ActivityLog`          | `activityLog`        | Audit log entry                           |

### `NotificationService.swift`
Handles sending push notifications via FCM.
Does not send directly to FCM. Writes a document to the `notificationQueue` Firestore collection.
A Firebase Cloud Function watches this collection and sends the actual FCM message.

`sendNotification(studentId:studentName:status:tripType:driverName:parentTokens:)` — Builds the notification payload and writes it to `notificationQueue`.

### `SessionManager.swift`
Manages the state of an active attendance session (pickup or dropoff).
Tracks the current attendee index, attendance records, and session progress.

`startSession(for list:type:)` — Begins a new session.

`recordAttendance(for attendee:status:)` — Records present or absent for a student.

`advanceToNext()` — Moves to the next student in the list.

`stopSession()` — Ends the session and saves to Core Data.

### `DataManager.swift`
Manages the Core Data stack for local storage.
Handles creating, reading, updating, and deleting attendance lists, sessions, and passenger notes locally.

### `DeveloperMenuView.swift`
A hidden debug menu. Access it from the login selection screen.
Functions: seed demo data, clear all local data, switch Firebase environment.
Remove before App Store submission.

---

## 6. Firestore Collections

| Collection        | Documents                | Key Fields                                                           |
|-------------------|--------------------------|----------------------------------------------------------------------|
| `drivers`         | One per driver           | `name`, `phone`, `busRegistration`, `isActive`, `fcmToken`          |
| `students`        | One per student          | `name`, `grade`, `stopAddress`, `routeId`, `authorisedParentIds[]`  |
| `parents`         | One per parent           | `name`, `phone`, `childIds[]`, `fcmToken`, `profileCompleted`       |
| `routes`          | One per bus route        | `name`, `driverId`, `studentIds[]`, `scheduledDays[]`, `isActive`   |
| `trips`           | One per trip per day     | `routeId`, `driverId`, `date`, `type`, `status`, `studentRecords[]` |
| `passengerNotes`  | One per note             | `studentId`, `noteText`, `fromDate`, `toDate`, `isDeleted`          |
| `activityLog`     | One per logged action    | `actorId`, `actorRole`, `action`, `timestamp`                       |
| `notificationQueue` | One per notification   | `studentId`, `status`, `title`, `body`, `parentTokens[]`, `sent`    |
| `schools`         | One per school           | `email`, `adminUid`, `schoolName`                                   |
| `adminOtps`       | One per OTP request      | `otp`, `expiresAt`, `schoolName`                                    |

---

## 7. Authentication Flows

### Driver Login
```
DriverLoginView enters phone number
       │
       ▼
authManager.sendOTP(to: phoneNumber)
  Firebase PhoneAuthProvider sends SMS to the number
       │
       ▼
Driver enters SMS code
       │
       ▼
authManager.verifyOTP(verificationID:code:)
  Firebase Auth signs in the driver
       │
       ▼
AuthManager.resolveRole() checks drivers collection
Sets currentRole = .driver
Shows DriverPortalView
```

### Parent Login
```
ParentLoginView enters email + password
       │
       ▼
authManager.signInParent(email:password:)
  Firebase Auth signs in the parent
       │
       ▼
AuthManager.resolveRole() checks parents collection
If profileCompleted == false → shows ParentOnboardingView
Else → sets currentRole = .parent → shows ParentPortalView
```

### Admin Login
```
AdminLoginView enters email
       │
       ▼
POST https://busmate-admin.vercel.app/api/admin-otp/send
  WAC API checks schools collection
  WAC API sends OTP email via Resend
       │
       ▼
Admin enters 6-digit OTP
       │
       ▼
POST https://busmate-admin.vercel.app/api/admin-otp/verify
  WAC API validates OTP
  WAC API returns Firebase custom token
       │
       ▼
authManager.signInWithCustomToken(token)
  Firebase Auth signs in the admin
       │
       ▼
AuthManager.resolveRole() checks schools collection
Sets currentRole = .admin
Shows AdminPortalView
```

---

## 8. Push Notifications (FCM)

**Flow:**
```
Driver marks student as onBus / offBus / absent
       │
       ▼
NotificationService.sendNotification() writes to notificationQueue collection
       │
       ▼
Firebase Cloud Function (deployed separately) detects new document
Cloud Function sends FCM message to parent device tokens
       │
       ▼
Parent device receives push notification
```

**FCM token lifecycle:**
- On login, `authManager.saveCurrentFCMToken()` saves the current token to Firestore.
- When FCM refreshes the token, `AuthManager.listenForTokenRefresh()` saves the new token.

---

## 9. Data Storage: Firestore vs Core Data

The app uses two separate storage systems.

| Storage    | What it stores                                                       |
|------------|----------------------------------------------------------------------|
| Firestore  | All live operational data: drivers, students, parents, routes, trips |
| Core Data  | Local attendance lists and sessions used by the driver's offline flow |

Core Data provides a local fallback so drivers can record attendance even without internet.
Data syncs to Firestore when the session ends and connectivity is available.

---

## 10. External Services

### Firebase Auth
- **Purpose:** User authentication for all four roles.
- **Methods:** Phone OTP (driver), email+password (parent, student), custom token (admin).
- **Config file:** `GoogleService-Info.plist`

### Firebase Firestore
- **Purpose:** Primary cloud database.
- **Database name:** `busmate-db`
- **Project ID:** `busmate-de66c`

### Firebase Cloud Messaging (FCM)
- **Purpose:** Push notifications to parents when their child's bus status changes.
- **Setup:** `BusMate.entitlements` enables push notifications. `BuzzerApp.swift` registers the device.

### WAC API (Web Admin Console)
- **Purpose:** Admin OTP authentication. The app calls two WAC API routes directly.
- **Endpoints used:**
  - `POST /api/admin-otp/send` — Request OTP
  - `POST /api/admin-otp/verify` — Verify OTP, receive custom token
- **Base URL:** `https://busmate-admin.vercel.app`

---

## 11. App Capabilities

Set in `BusMate.entitlements`:

| Capability          | Value         | Purpose                               |
|---------------------|---------------|---------------------------------------|
| Push Notifications  | development   | Receive FCM push notifications        |

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
