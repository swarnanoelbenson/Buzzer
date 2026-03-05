# 🚌 Buzzer - Bus Attendance Tracking App

**Platform**: iOS 15.0+  
**Language**: Swift  
**Framework**: SwiftUI + Core Data  
**Current Phase**: Phase 1 & 2 Complete

---

## 📱 What is Buzzer?

Buzzer is a lightweight iOS attendance-tracking app designed for bus drivers to manage pick-up and drop-off attendance. The app features a clean, intuitive interface optimized for users with low technical literacy.

---

## ✅ Current Features

### Phase 1: List Management
- **Create Lists**: Add attendance lists with custom names
- **Manage Attendees**: Add, edit, and remove attendees
- **Reorder**: Drag-and-drop to match physical pickup order
- **Persistent Storage**: All data saved locally with Core Data
- **Dark Mode**: Full support for light and dark appearance
- **Confirmation Dialogs**: Prevent accidental deletions

### Phase 2: Attendance Tracking
- **Pick-Up & Drop-Off**: Separate session types
- **Large Buttons**: Green "Present" and Red "Absent" buttons
- **Auto-Advance**: Automatically moves to next attendee
- **Timestamps**: Captures time (HH:MM:SS) for present attendees
- **Undo**: Swipe right to correct mistakes
- **Progress Tracking**: Shows X of Y with visual progress bar
- **Session Summary**: Displays present/absent counts
- **Haptic Feedback**: Tactile confirmation on actions

---

## 🚀 Getting Started

### Requirements
- Xcode 13.0+
- iOS 15.0+ device or simulator
- macOS 12.0+ (for development)

### Installation
1. Clone or download the repository
2. Open `Buzzer.xcodeproj` in Xcode
3. Select an iOS simulator or connected device
4. Run the app (⌘R)

### First Steps
1. **Create a list**: Tap the "+" button in the top-right
2. **Add attendees**: Open a list → Tap "Add" → Enter attendee names
3. **Reorder**: Tap "Edit" → Drag attendees to reorder
4. **Start a session**: Tap the play ▶️ icon → Choose Pick-Up or Drop-Off
5. **Track attendance**: Tap Present (green) or Absent (red) for each attendee
6. **Review**: View summary when complete

---

## 📐 Architecture

### Tech Stack
- **UI**: SwiftUI
- **Data Persistence**: Core Data
- **State Management**: ObservableObject + @Published
- **Navigation**: NavigationStack with .navigationDestination

### Core Components

#### Data Layer
- `Models.swift` - Swift structs for app data
- `DataManager.swift` - Core Data operations manager
- `PersistenceController.swift` - Core Data stack setup
- `Buzzer.xcdatamodeld` - Core Data schema

#### View Layer
- `ListsView.swift` - Main list browser
- `ListDetailView.swift` - Attendee management
- `SessionSelectionView.swift` - Pick-up/Drop-off chooser
- `AttendanceTrackingView.swift` - Attendance recording UI

#### Business Logic
- `SessionManager.swift` - Manages attendance session state

---

## 🗂️ Data Model

### Core Entities

**AttendeeList**
- `id`: UUID
- `name`: String
- `createdDate`: Date
- `attendees`: [Attendee]

**Attendee**
- `id`: UUID
- `name`: String
- `orderIndex`: Int

**AttendanceSession**
- `id`: UUID
- `listId`: UUID
- `sessionType`: Enum (pickup, dropoff)
- `createdDate`: Date
- `records`: [AttendanceRecord]

**AttendanceRecord**
- `id`: UUID
- `attendeeId`: UUID
- `status`: Enum (present, absent)
- `timestamp`: Date? (nil if absent)

---

## 🎨 Design Philosophy

### Apple Human Interface Guidelines
- Minimalist, clean interface
- Large touch targets (44x44 points minimum)
- Clear visual hierarchy
- Generous whitespace
- System colors and SF Symbols

### Color Coding
- **Green**: Pick-up, Present status
- **Orange**: Drop-off
- **Red**: Absent status
- **Blue**: Primary actions (system accent)

### Accessibility
- High contrast in light mode (readable in sunlight)
- Soft colors in dark mode (reduced eye strain)
- Large, readable text
- VoiceOver compatible
- Dynamic Type support

---

## 🔄 User Flow

```
App Launch
  ↓
ListsView (Browse all lists)
  ↓
ListDetailView (Manage attendees)
  ↓
SessionSelectionView (Choose Pick-Up or Drop-Off)
  ↓
AttendanceTrackingView (Record attendance)
  ↓
Session Summary → Back to List
```

---

## 🛠️ Development Status

### ✅ Completed
- [x] Phase 1: List Management
- [x] Phase 2: Pick-Up & Drop-Off Attendance

### 🚧 Future Phases (Not Yet Implemented)
- [ ] Phase 3: Session History & Viewing
- [ ] Phase 4: CSV Report Generation
- [ ] Phase 5: Dark Mode Refinements (already implemented)
- [ ] Phase 6: Cloud Backup & Sync

---

## 📝 Known Limitations

- Sessions are saved but cannot be viewed yet (Phase 3 feature)
- No CSV export (Phase 4 feature)
- No cloud backup (Phase 6 feature)
- Local device storage only

---

## 🧪 Testing

### Manual Testing Checklist
- [ ] Create a new list
- [ ] Add multiple attendees
- [ ] Reorder attendees via drag-and-drop
- [ ] Edit attendee name
- [ ] Delete attendee with confirmation
- [ ] Start pick-up session
- [ ] Record attendance (present/absent)
- [ ] Verify timestamps on present records
- [ ] Complete session and view summary
- [ ] Start drop-off session
- [ ] Verify session saves to Core Data
- [ ] Force quit and relaunch (data should persist)

---

## 🐛 Troubleshooting

### Common Issues

**App crashes on launch**
- Delete and reinstall the app
- Clean build folder (⌘⇧K) and rebuild

**Attendees not saving**
- Check Console logs for Core Data errors
- Verify `Buzzer.xcdatamodeld` is included in target

**Navigation issues**
- Ensure all views are wrapped in `NavigationView`/`NavigationStack`
- Check that `@EnvironmentObject` is properly injected

---

## 📄 License

This project is for educational and internal use.

---

## 👤 Author

**Noel Benson**  
Created: March 3, 2026  
Last Updated: March 5, 2026

---

## 📞 Support

For questions or issues, refer to:
- `CLEANUP_COMPLETE.md` - Recent cleanup documentation
- Original specification document
- Apple's [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- Apple's [Core Data Documentation](https://developer.apple.com/documentation/coredata/)

---

**Happy Tracking! 🚌✅**
