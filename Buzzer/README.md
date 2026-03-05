# Buzzer - Bus Attendance Tracking App

## Project Status

**Current Phase**: Phase 3 ✅ Complete  
**Progress**: 3 of 6 phases (50%)  
**Last Updated**: March 4, 2026

---

## Completed Phases

### ✅ Phase 1: List Management
- Create, edit, and delete attendance lists
- Add, edit, and remove attendees
- Drag-and-drop reordering
- Core Data persistence
- Full dark mode support

### ✅ Phase 2: Pick-Up & Drop-Off Attendance
- Session type selection (pick-up/drop-off)
- Large Present/Absent buttons
- Auto-advance functionality
- Timestamp capture (HH:MM:SS)
- Right swipe to undo
- Session review with summary
- Haptic feedback

### ✅ Phase 3: Session History & Viewing
- View all past sessions for any list
- Filter by session type (All/Pick-Up/Drop-Off)
- Filter by specific date
- Sessions grouped by date
- Attendance rate calculation with color coding
- Detailed session view with timestamps
- Smart empty states

---

## Quick Start

### Run the App
1. Open `Buzzer.xcodeproj` in Xcode
2. Select iPhone simulator (iOS 15.0+)
3. Run (⌘R)

### Basic Usage
1. **Create a list**: Tap "+" → Enter name
2. **Add attendees**: Open list → Tap "Add" → Enter names
3. **Reorder**: Tap "Edit" → Drag attendees
4. **Start session**: Tap play button → Choose Pick-Up or Drop-Off
5. **Track attendance**: Tap Present (green) or Absent (red)
6. **Review**: See summary when complete
7. **View history**: Tap clock icon → Filter and view past sessions

---

## Phase 1: List Management ✅

### Features
- **Create Lists**: Add new attendance lists with custom names
- **View All Lists**: Browse all created lists with attendee counts and creation dates
- **Delete Lists**: Remove lists with confirmation dialog
- **Persistent Storage**: All data saved locally using Core Data

### ✅ Attendee Management
- **Add Attendees**: Add individual attendees to any list
- **Edit Attendees**: Modify attendee names with inline editing
- **Remove Attendees**: Delete attendees with confirmation: *"Are you sure you want to remove [Attendee Name]?"*
- **Drag-and-Drop Reordering**: Reorder attendees to match physical pickup order
- **Empty State Handling**: Helpful prompts when lists or attendees are empty

### ✅ UI/UX Features
- **Apple-Inspired Design**: Clean, minimalist interface following HIG
- **Dark Mode Support**: Full support for light and dark appearance
- **Accessibility**: Large touch targets (44x44 points minimum)
- **Intuitive Navigation**: Clear information hierarchy
- **Bottom Action Bar**: Add and Remove buttons positioned at bottom of list
- **Confirmation Dialogs**: Prevent accidental deletions

---

## Phase 2: Pick-Up & Drop-Off Attendance ✅

### Features

#### ✅ Session Management
- **Session Selection**: Choose between Pick-Up (green) or Drop-Off (orange)
- **Recent Session Display**: Shows when last session occurred
- **Empty List Prevention**: Cannot start session on empty lists
- **Session State**: Active session management with progress tracking

#### ✅ Attendance Tracking
- **Large Attendee Display**: 48pt centered attendee name
- **Present Button**: Large green button (right side, 180pt height)
- **Absent Button**: Large red button (left side, 180pt height)
- **Auto-Advance**: Automatically moves to next attendee after selection
- **Haptic Feedback**: Tactile confirmation on button tap
- **Progress Bar**: Shows "X of Y" with visual progress indicator
- **Live Summary**: Running count of present/absent attendees

#### ✅ Timestamp Capture
- **Automatic Capture**: Timestamp recorded when marking Present
- **Format**: HH:MM:SS (24-hour format)
- **Storage**: Date object in Core Data
- **Display**: Human-readable format in reviews

#### ✅ Undo & Correction
- **Right Swipe Gesture**: Swipe right to go back to previous attendee
- **Status Preservation**: Can review and change previous selections
- **Smooth Animations**: Animated transitions during undo

#### ✅ Session Completion
- **Automatic Detection**: Knows when all attendees are processed
- **Summary Screen**: Shows total present/absent counts
- **Review Option**: Detailed session review with timestamps
- **Save & Exit**: Saves all records to Core Data

#### ✅ Session Review
- **Summary Statistics**: Total present, absent, and total count
- **Detailed List**: All attendees with status indicators
- **Timestamp Display**: Shows exact time for present attendees
- **Visual Indicators**: Green checkmark (present), red X (absent)

---

## Architecture

### Core Components

#### 1. Data Layer
- **`PersistenceController.swift`**: Core Data stack management
- **`Buzzer.xcdatamodeld`**: Core Data model definitions
- **`Models.swift`**: Swift structs for type-safe data handling
- **`DataManager.swift`**: Business logic and CRUD operations (lists + sessions)
- **`SessionManager.swift`**: Session state management (Phase 2)

#### 2. View Layer - List Management (Phase 1)
- **`ListsView.swift`**: Main screen showing all lists
- **`ListDetailView.swift`**: Individual list with attendees + play button
- **`CreateListView.swift`**: Modal for creating new lists
- **`AddAttendeeView.swift`**: Modal for adding attendees
- **`EditAttendeeView.swift`**: Modal for editing attendee names

#### 3. View Layer - Attendance Tracking (Phase 2)
- **`SessionSelectionView.swift`**: Choose pick-up or drop-off
- **`AttendanceTrackingView.swift`**: Main tracking interface
- **`SessionReviewView.swift`**: Post-session summary

#### 4. Utilities (Phase 2)
- **`TimestampFormatter.swift`**: Date/time formatting utilities

#### 5. App Entry
- **`BuzzerApp.swift`**: App configuration with Core Data injection

---

## Data Model

### Core Data Entities

```
AttendeeListEntity
├── id: UUID
├── name: String
├── createdDate: Date
├── attendees: [AttendeeEntity]
└── sessions: [AttendanceSessionEntity]

AttendeeEntity
├── id: UUID
├── name: String
├── orderIndex: Int16
├── list: AttendeeListEntity
└── records: [AttendanceRecordEntity]

AttendanceSessionEntity (Phase 2)
AttendanceRecordEntity (Phase 2)
```

### Swift Models

```swift
AttendeeList
├── id: UUID
├── name: String
├── createdDate: Date
└── attendees: [Attendee]

Attendee
├── id: UUID
├── name: String
└── orderIndex: Int
```

---

## User Flows

### Creating a List
1. Launch app → Tap "+" button
2. Enter list name (e.g., "Morning Route A")
3. Tap "Create"
4. List appears in main view

### Managing Attendees
1. Select a list from main view
2. Tap "Add" button at bottom
3. Enter attendee name
4. Tap "Add"
5. Attendee appears in list

### Reordering Attendees
1. Open a list
2. Tap "Edit" button
3. Drag attendees to desired order
4. Tap "Done"
5. Order persists automatically

### Editing Attendee Names
1. Open a list
2. Tap pencil icon next to attendee
3. Modify name
4. Tap "Save"

### Removing Attendees
1. Open a list
2. Tap "Remove" button (removes last attendee)
   OR
   Tap "Edit" → Swipe left → Tap "Delete"
3. Confirm deletion in alert dialog

### Starting an Attendance Session (Phase 2)
1. Open a list
2. Tap play button (▶️) in toolbar
3. Choose "Start Pick-Up" or "Start Drop-Off"
4. Session begins

### Recording Attendance (Phase 2)
1. Large attendee name appears
2. Tap "Present" (green) or "Absent" (red)
3. Haptic feedback confirms
4. Auto-advance to next attendee
5. Repeat for all attendees

### Correcting Mistakes (Phase 2)
1. Swipe right during session
2. Returns to previous attendee
3. Change their status
4. Auto-advance continues

### Completing a Session (Phase 2)
1. After last attendee, completion screen appears
2. Review summary (X present, Y absent)
3. Optional: Tap "Review Session" for details
4. Tap "Save & Exit" to save and return

---

## Technical Details

### Persistence
- **Framework**: Core Data
- **Storage**: SQLite on device
- **Auto-Save**: Changes saved immediately
- **Merge Policy**: Property object trump merge policy
- **Sessions**: Linked to lists with cascade delete

### Threading
- All Core Data operations on main context
- Automatic change propagation via `automaticallyMergesChangesFromParent`

### State Management
- `@StateObject` for DataManager and SessionManager lifecycle
- `@EnvironmentObject` for dependency injection
- `@Published` for reactive UI updates
- `ObservableObject` for session state

### Haptic Feedback (Phase 2)
- Medium impact on Present/Absent tap
- Non-blocking (doesn't delay UI)
- Provides tactile confirmation

---

## Design Decisions

### Why Core Data?
- Native iOS framework (no third-party dependencies)
- Robust relationship management
- Efficient queries and filtering
- Built-in migration support
- Proven production stability

### Why SwiftUI?
- Modern declarative syntax
- Built-in dark mode support
- Automatic accessibility features
- Less boilerplate than UIKit
- Native support for lists and navigation

### Why Local-First?
- Works offline (no network required)
- Instant responsiveness
- Privacy-focused (data stays on device)
- Aligns with Phase 6 CloudKit sync strategy

---

## Testing Checklist

### ✅ Acceptance Criteria (Phase 1)
- [x] User can create and name lists
- [x] User can add attendees to lists
- [x] User can remove attendees with confirmation
- [x] User can reorder attendees (drag-and-drop)
- [x] Add and Remove buttons positioned at bottom
- [x] State persists across app launches
- [x] Dark mode works correctly
- [x] Empty states display helpful messages
- [x] Confirmation dialogs prevent accidental deletions
- [x] UI is intuitive for non-technical users

### ✅ Acceptance Criteria (Phase 2)
- [x] User can select Pick-Up or Drop-Off session type
- [x] Large, centered attendee name displayed (48pt)
- [x] Green "Present" button on right side (180pt)
- [x] Red "Absent" button on left side (180pt)
- [x] Auto-advance after button tap
- [x] Timestamp captured in HH:MM:SS format (Present only)
- [x] Right swipe to undo and go back
- [x] "Stop" button saves all records
- [x] Progress indicator shows X of Y
- [x] Live summary shows present/absent counts
- [x] Haptic feedback on selection
- [x] Completion screen after all attendees
- [x] Session review shows all details
- [x] Data persists to Core Data

---

## Documentation

### Phase 1 (List Management)
- **README.md** - This file (comprehensive overview)
- **QUICKSTART.md** - Quick start guide
- **IMPLEMENTATION_NOTES.md** - Technical implementation details

### Phase 2 (Attendance Tracking)
- **PHASE2_SUMMARY.md** - Phase 2 completion summary
- **PHASE2_NOTES.md** - Full technical documentation
- **PHASE2_TESTING.md** - Comprehensive testing guide (16 test cases)

### Project Planning
- **TODO.md** - Complete roadmap for all phases

---

## Next Steps: Phase 3

### Session History (Upcoming)
- View past sessions for any list
- Filter by date and session type
- Tap to view session details
- Historical attendance patterns

### Required New Files
- `SessionHistoryView.swift`
- `SessionDetailView.swift`

**Estimated Timeline**: 3-5 days

---

## Known Limitations

### Phase 1 & 2 Complete
1. **No Session History View**: Can save sessions but can't view past sessions (Phase 3)
2. **No CSV Export**: Can't export reports yet (Phase 4)
3. **No Multi-User Support**: Single device only (Phase 5 - Firebase Auth)
4. **No Cloud Sync**: Local storage only (Phase 6 - CloudKit)

All limitations are **expected** and will be addressed in future phases.

---

## Installation

### Requirements
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

### Setup
1. Open `Buzzer.xcodeproj` in Xcode
2. Select target device/simulator
3. Build and run (⌘R)
4. No additional configuration needed

---

## Code Quality

### Best Practices
✅ SOLID principles
✅ Separation of concerns
✅ Type-safe Swift models
✅ Error handling with try-catch
✅ SwiftUI lifecycle management
✅ Reusable components
✅ Consistent naming conventions
✅ MVVM architecture (SessionManager as ViewModel)
✅ ObservableObject pattern

### Performance
✅ Efficient Core Data queries
✅ Minimal view re-renders
✅ Lazy loading with List
✅ Optimized relationship fetching
✅ Haptic feedback non-blocking
✅ Smooth animations (0.3s transitions)
✅ Tested with 50+ attendees (no lag)

---

## File Count

**Total Files**: 21
- **Core Data**: 2 (PersistenceController, xcdatamodeld)
- **Models**: 1 (Models.swift)
- **Managers**: 2 (DataManager, SessionManager)
- **Views (Phase 1)**: 5
- **Views (Phase 2)**: 3
- **Utilities**: 1 (TimestampFormatter)
- **App**: 1 (BuzzerApp)
- **Documentation**: 6
- **Legacy**: 1 (ContentView - unused)

---

## Support

For questions or issues, contact the development team.

**Project**: Buzzer - Bus Attendance Tracker  
**Phase**: 2 of 6 (Attendance Tracking)  
**Status**: ✅ Complete  
**Last Updated**: March 4, 2026  
**Next**: Phase 3 - Session History
