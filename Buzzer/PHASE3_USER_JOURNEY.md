# Buzzer - Complete User Journey (Phases 1-3)

## 📱 Updated User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                                   │
│                              ↓                                       │
│                    ┌─────────────────┐                              │
│                    │   Lists View    │  [Main Screen]               │
│                    └─────────────────┘                              │
│                            │                                         │
│                      [Tap List]                                      │
│                            ↓                                         │
│                    ┌─────────────────┐                              │
│                    │ List Detail     │                              │
│                    │ View            │                              │
│                    └─────────────────┘                              │
│                            │                                         │
│          ┌─────────────────┼─────────────────┐                     │
│          │                 │                 │                      │
│    [Tap 🕐]          [Tap ▶️]          [Edit List]                  │
│          │                 │                 │                      │
│          ↓                 ↓                 ↓                      │
│  ┌───────────────┐  ┌──────────────┐  Add/Remove                   │
│  │ Session       │  │ Session      │  Attendees                    │
│  │ History       │  │ Selection    │                               │
│  │ ← NEW         │  │              │                               │
│  └───────────────┘  └──────────────┘                               │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         Pick-Up / Drop-Off                               │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         ┌──────────────┐                                │
│          │         │ Attendance   │                                │
│          │         │ Tracking     │                                │
│          │         └──────────────┘                                │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         ┌──────────────┐                                │
│          │         │ Session      │                                │
│          │         │ Complete     │                                │
│          │         └──────────────┘                                │
│          │                 │                                        │
│          │           [Save & Exit]                                  │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         Session Saved                                    │
│          │         to Core Data                                     │
│          │                 │                                        │
│          │                 ↓                                        │
│          ├─────────────────┘                                       │
│          │                                                          │
│          ↓                                                          │
│  ┌────────────────────────────────────┐                           │
│  │   Session History View             │  ← NEW (Phase 3)           │
│  │                                    │                            │
│  │  Filter: [All] [Pick-Up] [Drop-Off]│                           │
│  │  Date: Mar 4, 2026  [Calendar]     │                            │
│  │                                    │                            │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │                            │
│  │                                    │                            │
│  │  Today                             │                            │
│  │  ↑ Pick-Up          3:15 PM        │ ← Tap                      │
│  │  ✓ 8 present  ✗ 2 absent          │   to                       │
│  │                                    │   view                     │
│  │  ↓ Drop-Off         5:30 PM        │   details                  │
│  │  ✓ 9 present  ✗ 1 absent          │                            │
│  │                                    │                            │
│  │  Yesterday                         │                            │
│  │  ↑ Pick-Up          8:00 AM        │                            │
│  │  ✓ 5 present  ✗ 5 absent          │                            │
│  │                                    │                            │
│  └────────────────────────────────────┘                           │
│                    │                                                │
│              [Tap Session]                                          │
│                    ↓                                                │
│  ┌────────────────────────────────────┐                           │
│  │   Session Detail View              │  ← NEW (Phase 3)           │
│  │                                    │                            │
│  │  Session Information               │                            │
│  │  ↑ Session Type    Pick-Up         │                            │
│  │  📅 Date           March 4, 2026   │                            │
│  │  🕐 Time           15:15:30         │                            │
│  │  📋 List           Morning Route    │                            │
│  │                                    │                            │
│  │  Summary                           │                            │
│  │  ✓ Present         8               │                            │
│  │  ✗ Absent          2               │                            │
│  │  👥 Total          10               │                            │
│  │  📊 Attendance     80%   [Orange]  │ ← Color-coded              │
│  │                                    │                            │
│  │  Attendance Details                │                            │
│  │  ✓ Alice Anderson  08:15:30        │                            │
│  │  ✓ Bob Brown       08:16:12        │                            │
│  │  ✗ Charlie Chen    Absent          │                            │
│  │  ✓ Diana Davis     08:17:45        │                            │
│  │  ...                               │                            │
│  │                                    │                            │
│  │  [Export] ← Phase 4                │                            │
│  └────────────────────────────────────┘                           │
│                    │                                                │
│                 [Back]                                              │
│                    ↓                                                │
│         Return to Session History                                   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Phase 3 Feature Access Map

### List Detail View (Updated)
```
┌─────────────────────────────────────┐
│ 🕐 Morning Route A      [▶️] [Edit] │ ← Clock icon NEW
├─────────────────────────────────────┤
│                                     │
│  1. Alice Anderson          [✏️]    │
│  2. Bob Brown               [✏️]    │
│  3. Charlie Chen            [✏️]    │
│  ...                                │
│                                     │
├─────────────────────────────────────┤
│  [    Add    ]  [  Remove  ]       │
└─────────────────────────────────────┘
```

### Session History View (NEW)
```
┌─────────────────────────────────────┐
│ ← Session History                   │
├─────────────────────────────────────┤
│  Filter: [All][Pick-Up][Drop-Off]  │ ← Segmented control
│                                     │
│  📅 Filter by Date: Mar 4, 2026     │ ← Tap for calendar
│  ───────────────────────────────    │
│  Clear Date Filter                  │ ← Appears when filtered
├─────────────────────────────────────┤
│                                     │
│  Today                              │ ← Smart grouping
│  ┌───────────────────────────────┐ │
│  │ ↑ Pick-Up          3:15 PM    │ │ ← Tap to view detail
│  │ ✓ 8 present  ✗ 2 absent       │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ ↓ Drop-Off         5:30 PM    │ │
│  │ ✓ 9 present  ✗ 1 absent       │ │
│  └───────────────────────────────┘ │
│                                     │
│  Yesterday                          │
│  ┌───────────────────────────────┐ │
│  │ ↑ Pick-Up          8:00 AM    │ │
│  │ ✓ 5 present  ✗ 5 absent       │ │
│  └───────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### Session Detail View (NEW)
```
┌─────────────────────────────────────┐
│ ← Session Details           [↗️]    │ ← Export (Phase 4)
├─────────────────────────────────────┤
│  Session Information                │
│  ┌─────────────────────────────┐  │
│  │ ↑ Session Type   Pick-Up    │  │
│  │ 📅 Date         Mar 4, 2026  │  │
│  │ 🕐 Time         15:15:30     │  │
│  │ 📋 List         Morning Rte  │  │
│  └─────────────────────────────┘  │
│                                     │
│  Summary                            │
│  ┌─────────────────────────────┐  │
│  │ ✓ Present            8      │  │
│  │ ✗ Absent             2      │  │
│  │ 👥 Total            10      │  │
│  │ 📊 Attendance       80%     │  │ ← Orange color
│  └─────────────────────────────┘  │
│                                     │
│  Attendance Details                 │
│  ┌─────────────────────────────┐  │
│  │ ✓ Alice Anderson            │  │
│  │   08:15:30                  │  │
│  │                             │  │
│  │ ✓ Bob Brown                 │  │
│  │   08:16:12                  │  │
│  │                             │  │
│  │ ✗ Charlie Chen              │  │
│  │   Absent                    │  │
│  │                             │  │
│  │ ✓ Diana Davis               │  │
│  │   08:17:45                  │  │
│  └─────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Date Picker Sheet (NEW)
```
┌─────────────────────────────────────┐
│ Select Date                  [Done] │
├─────────────────────────────────────┤
│                                     │
│     March 2026                      │
│  Su Mo Tu We Th Fr Sa              │
│                     1               │
│   2  3  4  5  6  7  8              │ ← 4 is selected
│   9 10 11 12 13 14 15              │
│  16 17 18 19 20 21 22              │
│  23 24 25 26 27 28 29              │
│  30 31                              │
│                                     │
│  (Future dates disabled)            │
│                                     │
└─────────────────────────────────────┘
```

---

## 🔄 Phase 3 State Transitions

### Filter State Machine
```
Initial State (All Sessions, Today)
    │
    ├→ [Select Filter Type]
    │     ├→ All
    │     ├→ Pick-Up
    │     └→ Drop-Off
    │
    ├→ [Select Date]
    │     └→ Calendar Picker
    │           ├→ Select Past Date
    │           └→ Done
    │
    ├→ [Clear Date Filter]
    │     └→ Reset to Today
    │
    └→ [Clear All Filters]
          └→ Reset to Initial State
```

### Navigation Flow
```
List Detail
    │
    ├→ [Tap Clock Icon]
    │     │
    │     ↓
    │  Session History
    │     │
    │     ├→ [Filter by Type/Date]
    │     │     └→ List Updates
    │     │
    │     ├→ [Tap Session]
    │     │     │
    │     │     ↓
    │     │  Session Detail
    │     │     │
    │     │     ├→ [View Info/Stats]
    │     │     ├→ [Export] (Phase 4)
    │     │     └→ [Back]
    │     │           │
    │     │           ↓
    │     │     Session History
    │     │
    │     └→ [Back]
    │           │
    │           ↓
    │     List Detail
    │
    └→ [Other Actions...]
```

---

## 📊 Data Relationships (Updated for Phase 3)

### Complete Schema
```
AttendeeListEntity
    ├─ id: UUID
    ├─ name: String
    ├─ createdDate: Date
    │
    ├─→ attendees [AttendeeEntity]
    │       ├─ id: UUID
    │       ├─ name: String
    │       ├─ orderIndex: Int16
    │       │
    │       └─→ records [AttendanceRecordEntity]
    │
    └─→ sessions [AttendanceSessionEntity]  ← Used in Phase 3
            ├─ id: UUID
            ├─ sessionType: String ("pickup" or "dropoff")
            ├─ createdDate: Date
            │
            └─→ records [AttendanceRecordEntity]
                    ├─ id: UUID
                    ├─ status: String ("present" or "absent")
                    ├─ timestamp: Date? (nil if absent)
                    │
                    ├─→ attendee: AttendeeEntity
                    └─→ session: AttendanceSessionEntity
```

### Phase 3 Queries
```
// Fetch all sessions for a list
fetchSessions(for list: AttendeeList)
    ↓
Core Data: fetch AttendanceSessionEntity
    WHERE list.id == listId
    ORDER BY createdDate DESC
    ↓
Convert → [AttendanceSession]

// Filter sessions
filteredSessions = sessions.filter { session in
    typeMatches && dateMatches
}

// Group by date
groupedSessions = Dictionary(grouping: filteredSessions) { session in
    Calendar.current.startOfDay(for: session.createdDate)
}
```

---

## 🎨 Phase 3 Color Coding

### Session Type Colors
```
Pick-Up Sessions:
    Icon: ↑ (arrow.up.circle.fill)
    Color: Green
    
Drop-Off Sessions:
    Icon: ↓ (arrow.down.circle.fill)
    Color: Orange
```

### Attendance Rate Colors
```
90-100%:  Green   (Excellent)
70-89%:   Orange  (Good)
0-69%:    Red     (Needs Attention)
```

### Status Indicators
```
Present:  ✓ Green checkmark.circle.fill
Absent:   ✗ Red xmark.circle.fill
```

---

## 🔍 Empty State Messages

### Context-Aware Messages

**No Sessions Recorded**:
```
┌─────────────────────────────────┐
│     🕐                          │
│                                 │
│  No Sessions Found              │
│                                 │
│  No attendance sessions have    │
│  been recorded yet. Start a     │
│  pick-up or drop-off session    │
│  to track attendance.           │
└─────────────────────────────────┘
```

**Filter Active, No Matches**:
```
┌─────────────────────────────────┐
│     🕐                          │
│                                 │
│  No Sessions Found              │
│                                 │
│  No pick-up sessions found.     │
│  Try changing your filter.      │
│                                 │
│  [Clear Filters]                │
└─────────────────────────────────┘
```

**Date Filter, No Matches**:
```
┌─────────────────────────────────┐
│     🕐                          │
│                                 │
│  No Sessions Found              │
│                                 │
│  No sessions found on           │
│  March 4, 2026.                 │
│  Try a different date.          │
│                                 │
│  [Clear Filters]                │
└─────────────────────────────────┘
```

---

## ⌨️ Keyboard Shortcuts (Future iPad Support)

```
Session History View:
⌘1 - Filter: All
⌘2 - Filter: Pick-Up
⌘3 - Filter: Drop-Off
⌘D - Open Date Picker
⌘R - Clear Filters
Return - Open Selected Session

Session Detail View:
⌘E - Export (Phase 4)
Esc - Back to History
```

---

## 📈 Performance Optimizations

### Filtering Strategy
```
✅ In-Memory Filtering
   - No database queries on filter change
   - Instant response
   - Computed properties

✅ Lazy Loading
   - List only renders visible rows
   - Smooth scrolling with 100+ sessions

✅ Grouping On-Demand
   - Dictionary grouping computed when needed
   - Cached until filters change
```

---

## 🎯 Complete User Journey Example

### Scenario: View Yesterday's Pick-Up Session

```
1. User opens "Morning Route A" list
   └→ List Detail View appears

2. User taps clock icon (🕐)
   └→ Session History View appears
   └→ Shows all sessions grouped by date

3. User sees:
   Today (2 sessions)
   Yesterday (1 session)

4. User wants only pick-ups, taps "Pick-Up" filter
   └→ Drop-off sessions hide
   └→ Only pick-up sessions visible

5. User taps yesterday's pick-up session
   └→ Session Detail View appears

6. User sees:
   - Session Type: Pick-Up (green ↑)
   - Date: March 3, 2026
   - Time: 08:15:30
   - Attendance Rate: 90% (green)
   - 9 present, 1 absent

7. User scrolls attendee list
   └→ Sees all attendees in order
   └→ Each shows status and timestamp

8. User taps back
   └→ Returns to Session History

9. User taps back again
   └→ Returns to List Detail
```

---

**Last Updated**: March 4, 2026  
**Phases Complete**: 1, 2, 3  
**Document Version**: 3.0  
**Status**: ✅ Complete

