//
//  IMPLEMENTATION_NOTES.md
//  Buzzer
//
//  Phase 1 Implementation Notes
//

# Phase 1 Implementation - Technical Notes

## File Structure

```
Buzzer/
├── BuzzerApp.swift                 // App entry point with Core Data injection
├── ContentView.swift               // (Legacy - can be deleted)
│
├── Models/
│   └── Models.swift                // Swift data models (AttendeeList, Attendee, etc.)
│
├── Persistence/
│   ├── PersistenceController.swift // Core Data stack
│   ├── DataManager.swift           // CRUD operations & business logic
│   └── Buzzer.xcdatamodeld/        // Core Data model definition
│
└── Views/
    ├── ListsView.swift             // Main screen (list of all lists)
    ├── ListDetailView.swift        // Individual list with attendees
    ├── CreateListView.swift        // Modal for creating lists
    ├── AddAttendeeView.swift       // Modal for adding attendees
    └── EditAttendeeView.swift      // Modal for editing attendees
```

---

## Key Implementation Details

### 1. Core Data Integration

**PersistenceController** is a singleton that manages the Core Data stack:
```swift
PersistenceController.shared
```

It's injected at the app level:
```swift
@StateObject private var dataManager = DataManager(persistenceController: .shared)
```

### 2. DataManager Pattern

**DataManager** acts as the interface between SwiftUI and Core Data:
- Converts Core Data entities → Swift structs (for UI)
- Converts Swift structs → Core Data entities (for persistence)
- Publishes changes via `@Published var lists: [AttendeeList]`

This keeps Core Data entities out of SwiftUI views (cleaner separation).

### 3. Reordering Implementation

The reorder logic uses SwiftUI's native `.onMove` modifier:
```swift
.onMove { source, destination in
    moveAttendee(from: source, to: destination, in: currentList)
}
```

Behind the scenes, we:
1. Reorder the array
2. Update `orderIndex` for each attendee
3. Persist to Core Data
4. Refresh the UI

### 4. Confirmation Dialogs

All destructive actions (delete list, remove attendee) show alerts:
```swift
.alert("Delete List", isPresented: $showDeleteConfirmation, presenting: listToDelete) { list in
    Button("Cancel", role: .cancel) { }
    Button("Delete", role: .destructive) { 
        dataManager.deleteList(list)
    }
}
```

This follows Apple's HIG for safe destructive actions.

### 5. Empty States

Both `ListsView` and `ListDetailView` have empty state views:
- Helpful icon
- Clear message
- Call-to-action button

This improves UX for first-time users.

---

## Design Patterns Used

### 1. **MVVM (Model-View-ViewModel)**
- **Model**: Core Data entities + Swift structs
- **View**: SwiftUI views
- **ViewModel**: DataManager (acts as view model)

### 2. **Repository Pattern**
DataManager abstracts persistence layer:
- Views don't know about Core Data
- Easy to swap persistence mechanism later
- Testable (can inject mock PersistenceController)

### 3. **Dependency Injection**
PersistenceController injected via initializer:
```swift
DataManager(persistenceController: .shared)
```

Enables testing with in-memory stores.

### 4. **Observer Pattern**
SwiftUI's `@Published` + `@ObservedObject` for reactive UI:
```swift
@Published var lists: [AttendeeList] = []
```

---

## Xcode Project Configuration

### Required Capabilities
✅ None (Phase 1 is fully local)

### Minimum Deployment Target
iOS 15.0 (set in project settings)

### Core Data Model
The `.xcdatamodeld` file must be added to the project:
1. Select file in Xcode
2. Ensure target membership includes "Buzzer"
3. Model name must match `NSPersistentContainer(name: "Buzzer")`

### Info.plist
No special entries required for Phase 1.

---

## Testing Strategy

### Unit Tests (Future)
- Test DataManager CRUD operations
- Use in-memory Core Data store:
```swift
PersistenceController(inMemory: true)
```

### UI Tests (Future)
- Test list creation flow
- Test attendee reordering
- Test delete confirmations

### Manual Testing Checklist
- [ ] Create multiple lists
- [ ] Add 10+ attendees to a list
- [ ] Reorder attendees (drag-and-drop)
- [ ] Edit attendee names
- [ ] Delete attendees (confirm dialog appears)
- [ ] Delete lists (confirm dialog appears)
- [ ] Force quit app and relaunch (data persists)
- [ ] Toggle dark mode (UI adapts)
- [ ] Test on iPhone SE (smallest screen)
- [ ] Test on iPhone Pro Max (largest screen)

---

## Common Issues & Solutions

### Issue: Core Data Entity Not Found
**Symptom**: "Failed to load Core Data stack" error

**Solution**: 
1. Ensure `.xcdatamodeld` file is in project
2. Check target membership
3. Verify model name matches container name

### Issue: UI Not Updating
**Symptom**: Changes don't appear immediately

**Solution**:
1. Ensure `save()` is called in DataManager
2. Check `fetchLists()` is called after mutations
3. Verify `@Published` on `lists` property

### Issue: Reordering Doesn't Persist
**Symptom**: Order resets after relaunch

**Solution**:
1. Ensure `orderIndex` is updated
2. Call `save()` after reordering
3. Check sort descriptor in fetch request

### Issue: Dark Mode Colors Wrong
**Symptom**: Text unreadable in dark mode

**Solution**:
Use semantic colors:
- `.primary` (not `.black`)
- `.secondary` (not `.gray`)
- `.accentColor` (system accent)

---

## Performance Considerations

### Current Implementation
- **Fetch Strategy**: Fetch all lists on app launch
- **Refresh Strategy**: Re-fetch after every mutation
- **Sort**: In-memory sorting via `orderIndex`

### Scalability Limits
- ✅ < 50 lists: No issues
- ⚠️ 50-200 lists: Minor lag on low-end devices
- ❌ > 200 lists: Consider pagination

### Optimization Opportunities (Phase 2)
1. **NSFetchedResultsController**: Automatic change tracking
2. **Batch Updates**: Update multiple attendees at once
3. **Predicate Caching**: Cache common fetch requests
4. **Lazy Loading**: Only fetch visible lists

---

## Code Style Guidelines

### Naming Conventions
- **Views**: `[Feature]View.swift` (e.g., `ListsView`)
- **Models**: `[Entity]` (e.g., `AttendeeList`)
- **Core Data Entities**: `[Entity]Entity` (e.g., `AttendeeListEntity`)
- **Managers**: `[Feature]Manager` (e.g., `DataManager`)

### SwiftUI Best Practices
- Extract complex views into computed properties
- Use `@State` for local state
- Use `@StateObject` for view-owned objects
- Use `@EnvironmentObject` for shared dependencies
- Prefer `@FocusState` over manual keyboard handling

### Comments
- Document public APIs
- Explain complex algorithms
- Add `// MARK:` for organization
- No redundant comments (code should be self-documenting)

---

## Phase 2 Preparation

### Files to Create
1. `AttendanceSessionView.swift` - Main attendance tracking UI
2. `SessionManager.swift` - Session state management
3. `TimestampFormatter.swift` - Date/time utilities

### DataManager Extensions
Add methods:
- `startSession(for list:, type:)` → AttendanceSession
- `recordAttendance(attendee:, status:, session:)`
- `stopSession(_ session:)`
- `fetchSessions(for list:) → [AttendanceSession]`

### Core Data Changes
No schema changes needed (already prepared in Phase 1).

---

## Credits

**Developer**: Noel Benson  
**Framework**: SwiftUI + Core Data  
**Platform**: iOS 15.0+  
**Design**: Apple Human Interface Guidelines  
**Architecture**: MVVM + Repository Pattern

---

## Version History

### v1.0 - Phase 1 (March 4, 2026)
✅ List management
✅ Attendee CRUD operations
✅ Drag-and-drop reordering
✅ Core Data persistence
✅ Dark mode support
✅ Confirmation dialogs
✅ Empty states

### Upcoming: v2.0 - Phase 2
⏳ Pick-up attendance tracking
⏳ Drop-off attendance tracking
⏳ Session management
⏳ Timestamp capture
