# Buzzer - Development Roadmap

## ✅ Phase 1: List Management (COMPLETE)
**Status**: Shipped  
**Completion Date**: March 4, 2026

### Delivered Features
- [x] Create/edit/delete attendance lists
- [x] Add/edit/remove attendees
- [x] Drag-and-drop reordering
- [x] Core Data local persistence
- [x] Dark mode support
- [x] Confirmation dialogs
- [x] Empty state handling
- [x] Bottom action bar

---

## 🚧 Phase 2: Pick-Up & Drop-Off Attendance
**Status**: Not Started  
**Priority**: High  
**Estimated Timeline**: 1-2 weeks

### Features to Build

#### 2.1 Session Selection Screen
- [ ] Screen to select list
- [ ] Button: "Start Pick-Up" (green)
- [ ] Button: "Start Drop-Off" (orange)
- [ ] Show last session date/time
- [ ] Disable if list is empty

#### 2.2 Attendance Tracking View
- [ ] Large centered attendee name (48pt font)
- [ ] Two prominent buttons:
  - [ ] Green "Present" button (right side, 200x80pt)
  - [ ] Red "Absent" button (left side, 200x80pt)
- [ ] Auto-advance on button tap
- [ ] Haptic feedback on selection
- [ ] Progress indicator (e.g., "5 of 12")
- [ ] Right swipe gesture to undo last entry
- [ ] "Stop" button (top left) with confirmation

#### 2.3 Timestamp Capture
- [ ] Capture timestamp on "Present" tap
- [ ] Format: HH:MM:SS (24-hour)
- [ ] Store in ISO 8601 for database
- [ ] Display formatted time in session review

#### 2.4 Session Management
- [ ] Create `AttendanceSession` on "Start"
- [ ] Link to selected list
- [ ] Store session type (pickup/dropoff)
- [ ] Save records incrementally (don't wait for "Stop")
- [ ] Handle interruptions (phone call, backgrounding)
- [ ] Auto-resume on return to app

#### 2.5 Session Review
- [ ] Summary screen after "Stop"
- [ ] Show: X present, Y absent
- [ ] List all attendees with status
- [ ] Option to edit/fix mistakes
- [ ] "Done" button to return to home

### Files to Create
```
Views/
├── SessionSelectionView.swift       // Choose list + session type
├── AttendanceTrackingView.swift     // Main tracking interface
├── SessionReviewView.swift          // Post-session summary
└── SessionProgressView.swift        // Progress indicator component

Managers/
├── SessionManager.swift             // Session state management
└── TimestampFormatter.swift         // Date/time utilities

Extensions/
└── DataManager+Sessions.swift       // Session CRUD operations
```

### DataManager New Methods
```swift
// Session operations
func startSession(for list: AttendeeList, type: SessionType) -> AttendanceSession
func recordAttendance(attendee: Attendee, status: AttendanceStatus, in session: AttendanceSession)
func undoLastRecord(in session: AttendanceSession)
func stopSession(_ session: AttendanceSession)
func fetchSessions(for list: AttendeeList) -> [AttendanceSession]
func fetchRecentSession(for list: AttendeeList, type: SessionType) -> AttendanceSession?
```

---

## 📋 Phase 3: Historical Session Viewing
**Status**: Not Started  
**Priority**: Medium  
**Estimated Timeline**: 3-5 days

### Features to Build

#### 3.1 Session History View
- [ ] Show all sessions for a list
- [ ] Group by date
- [ ] Show session type badge (pickup/dropoff)
- [ ] Tap to view session details
- [ ] Search by date
- [ ] Filter by session type

#### 3.2 Session Detail View
- [ ] Date and time of session
- [ ] Session type (pickup/dropoff)
- [ ] List of attendees with status
- [ ] Timestamps for present attendees
- [ ] Total present/absent counts
- [ ] Option to export this session

### Files to Create
```
Views/
├── SessionHistoryView.swift         // List of past sessions
└── SessionDetailView.swift          // Individual session view
```

---

## 📊 Phase 4: CSV Report Generation
**Status**: Not Started  
**Priority**: High  
**Estimated Timeline**: 1 week

### Features to Build

#### 4.1 Report Generation
- [ ] "Generate Report" button on list detail
- [ ] Date picker for historical reports
- [ ] Date range picker for multi-day reports
- [ ] "Today's Report" quick action
- [ ] "This Week" quick action
- [ ] "Custom Range" with calendars

#### 4.2 CSV Format Implementation
- [ ] Generate CSV with header row
- [ ] Format timestamps as HH:MM:SS
- [ ] Handle "Absent" text for missing timestamps
- [ ] Include report metadata (date, list name)
- [ ] Support date range format
- [ ] Proper escaping of special characters

#### 4.3 File Export
- [ ] Save to Files app
- [ ] Share sheet integration
- [ ] Email attachment support
- [ ] AirDrop support
- [ ] iCloud Drive option
- [ ] Naming convention: `YYYY-MM-DD_ListName.csv`

#### 4.4 Data Retention
- [ ] Display storage usage
- [ ] 90-day local retention policy
- [ ] Auto-export before deletion
- [ ] Manual archive option
- [ ] Restore from backup

### Files to Create
```
Utilities/
├── CSVGenerator.swift               // CSV formatting logic
├── ReportBuilder.swift              // Report data aggregation
└── FileExporter.swift               // File save/share handling

Views/
├── ReportConfigurationView.swift    // Date picker, options
└── StorageManagementView.swift      // Data retention UI
```

### DataManager New Methods
```swift
// Report operations
func fetchRecords(for list: AttendeeList, date: Date) -> [AttendanceRecord]
func fetchRecords(for list: AttendeeList, from: Date, to: Date) -> [AttendanceRecord]
func exportToCSV(list: AttendeeList, date: Date) -> URL
func exportToCSV(list: AttendeeList, from: Date, to: Date) -> URL
func cleanupOldRecords(before date: Date)
```

---

## 🔐 Phase 5: Firebase Authentication
**Status**: Not Started  
**Priority**: Medium  
**Estimated Timeline**: 3-5 days

### Features to Build

#### 5.1 Firebase Setup
- [ ] Add Firebase SDK (SPM or CocoaPods)
- [ ] Configure Firebase project
- [ ] Download GoogleService-Info.plist
- [ ] Initialize Firebase in app

#### 5.2 Authentication Flows
- [ ] Login screen (email/password)
- [ ] Sign-up screen
- [ ] Password reset flow
- [ ] Email verification
- [ ] Session persistence (Keychain)
- [ ] Auto-login on launch

#### 5.3 User Isolation
- [ ] Tag all Core Data entities with userId
- [ ] Filter queries by current user
- [ ] Prevent cross-user data access
- [ ] Handle account switching

#### 5.4 Optional: Biometric Auth
- [ ] Face ID unlock
- [ ] Touch ID unlock
- [ ] Settings toggle
- [ ] Fallback to password

### Files to Create
```
Authentication/
├── AuthenticationManager.swift      // Firebase Auth wrapper
├── LoginView.swift                  // Login screen
├── SignUpView.swift                 // Registration screen
└── PasswordResetView.swift          // Forgot password

Utilities/
└── KeychainHelper.swift             // Secure storage
```

### Core Data Schema Changes
```swift
// Add userId to all entities
AttendeeListEntity.userId: String
```

---

## ☁️ Phase 6: CloudKit Sync (Optional)
**Status**: Not Started  
**Priority**: Low  
**Estimated Timeline**: 1-2 weeks

### Features to Build

#### 6.1 CloudKit Integration
- [ ] Enable CloudKit in capabilities
- [ ] Configure iCloud container
- [ ] Set up CloudKit schema
- [ ] Implement sync manager

#### 6.2 Sync Logic
- [ ] Upload on "Stop" button
- [ ] Background sync (app backgrounding)
- [ ] Conflict resolution (last-write-wins)
- [ ] Retry with exponential backoff
- [ ] Sync status indicator

#### 6.3 Offline Handling
- [ ] Queue changes for later sync
- [ ] Show sync status (synced/pending/error)
- [ ] Manual sync trigger
- [ ] Handle sync errors gracefully

### Files to Create
```
Cloud/
├── CloudKitManager.swift            // CloudKit operations
├── SyncEngine.swift                 // Sync coordination
└── ConflictResolver.swift           // Merge strategies
```

---

## 🎨 Phase 7: UX Refinements
**Status**: Not Started  
**Priority**: Low  
**Estimated Timeline**: Ongoing

### Enhancements to Build

#### 7.1 Onboarding
- [ ] Welcome screen on first launch
- [ ] Feature walkthrough
- [ ] Sample data option
- [ ] Skip option

#### 7.2 Settings
- [ ] App settings screen
- [ ] Dark mode preference (auto/light/dark)
- [ ] Haptic feedback toggle
- [ ] Sound effects toggle
- [ ] Export all data
- [ ] Clear all data (with confirmation)

#### 7.3 Performance
- [ ] Pagination for large lists
- [ ] Lazy loading of sessions
- [ ] Image compression (if profile photos added)
- [ ] Database indexing

#### 7.4 Accessibility
- [ ] VoiceOver optimization
- [ ] Dynamic Type support
- [ ] Reduced Motion support
- [ ] High Contrast mode

---

## 🐛 Known Issues / Technical Debt

### Phase 1
- [ ] No list name editing from main screen (only via detail)
- [ ] No bulk attendee import
- [ ] No attendee search in large lists
- [ ] ContentView.swift unused (legacy from template)

### Future Considerations
- [ ] iPad optimization (split view, multitasking)
- [ ] Widget support (Today view)
- [ ] Siri Shortcuts integration
- [ ] Apple Watch companion app
- [ ] macOS Catalyst version

---

## 📈 Success Metrics

### Phase 2 Goals
- [ ] Record attendance for 50+ attendees in < 2 minutes
- [ ] Zero data loss during session interruptions
- [ ] < 0.5 seconds per attendee (tap to advance)
- [ ] 95%+ accuracy (minimal undo usage)

### Phase 4 Goals
- [ ] Generate CSV in < 1 second (100 attendees)
- [ ] Email export works 100% of time
- [ ] 90-day retention with zero manual intervention

### Overall App Goals
- [ ] 4.5+ stars in App Store
- [ ] < 0.1% crash rate
- [ ] < 5 seconds cold launch time
- [ ] < 50 MB app size

---

## 🔄 Version History

### v1.0 (Current) - March 4, 2026
- ✅ List management
- ✅ Attendee CRUD
- ✅ Reordering
- ✅ Core Data persistence

### v2.0 (Planned) - Target: March 18, 2026
- ⏳ Pick-up attendance
- ⏳ Drop-off attendance
- ⏳ Session management

### v3.0 (Planned) - Target: April 1, 2026
- ⏳ CSV reports
- ⏳ Historical viewing
- ⏳ Data retention

### v4.0 (Planned) - Target: April 15, 2026
- ⏳ Firebase Auth
- ⏳ Multi-user support
- ⏳ CloudKit sync

---

## 📞 Contact & Support

**Developer**: Noel Benson  
**Project**: Buzzer - Bus Attendance Tracker  
**Repository**: [Link to repo]  
**Documentation**: See README.md

---

*Last Updated: March 4, 2026*  
*Current Phase: 1 of 7 (List Management)*  
*Status: Phase 1 Complete ✅*
