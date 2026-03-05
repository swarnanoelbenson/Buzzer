# Buzzer - Complete User Journey (Phases 1 & 2)

## 📱 User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APP LAUNCH                                   │
│                              ↓                                       │
│                    ┌─────────────────┐                              │
│                    │   Lists View    │  [Main Screen]               │
│                    │  (All Lists)    │                              │
│                    └─────────────────┘                              │
│                            │                                         │
│          ┌─────────────────┼─────────────────┐                     │
│          │                 │                 │                      │
│     [Tap List]        [Tap +]         [Swipe Left]                 │
│          │                 │                 │                      │
│          ↓                 ↓                 ↓                      │
│  ┌───────────────┐  ┌──────────────┐  [Delete List?]              │
│  │ List Detail   │  │ Create List  │  Confirm → Delete             │
│  │  View         │  │    Modal     │                               │
│  └───────────────┘  └──────────────┘                               │
│          │                 │                                        │
│          │                 ↓                                        │
│          │           Enter Name                                     │
│          │                 │                                        │
│          │           [Tap Create]                                   │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         List Created                                     │
│          │                 │                                        │
│          │                 ↓                                        │
│          │         Back to Lists                                    │
│          │                                                          │
│          ↓                                                          │
│  ┌─────────────────────────────────────┐                          │
│  │      List Detail View                │                          │
│  │  - List name                         │                          │
│  │  - Attendee list (ordered)           │                          │
│  │  - [Add] [Remove] buttons at bottom  │                          │
│  │  - [Edit] button top right           │                          │
│  │  - [▶️ Play] button top right         │  ← NEW (Phase 2)        │
│  └─────────────────────────────────────┘                          │
│          │                                                          │
│  ┌───────┼───────┬───────────┬──────────┬──────────┐             │
│  │       │       │           │          │          │              │
│ [Add] [Remove] [Edit] [Tap Pencil] [Tap Play]                     │
│  │       │       │           │          │                          │
│  ↓       ↓       ↓           ↓          ↓                          │
│ Add    Remove  Enable    Edit      Session                         │
│Modal   Last    Drag &   Attendee  Selection                        │
│       Attendee  Drop      Modal    ← NEW                           │
│                                     (Phase 2)                       │
│                                        │                            │
│                                        ↓                            │
│                    ┌────────────────────────────────┐              │
│                    │   Session Selection View       │              │
│                    │                                │              │
│                    │  [Start Pick-Up]    (Green)    │              │
│                    │  Last: 2 hours ago             │              │
│                    │                                │              │
│                    │  ─────────────────             │              │
│                    │                                │              │
│                    │  [Start Drop-Off]  (Orange)    │              │
│                    │  Last: 1 hour ago              │              │
│                    └────────────────────────────────┘              │
│                            │           │                            │
│                      [Pick-Up]    [Drop-Off]                        │
│                            │           │                            │
│                            └─────┬─────┘                           │
│                                  ↓                                  │
│                    ┌────────────────────────────────┐              │
│                    │  Attendance Tracking View      │              │
│                    │                                │              │
│                    │  Progress: 3 of 10  ✓5  ✗2    │              │
│                    │  ═══════════════════           │              │
│                    │                                │              │
│                    │         John Smith             │ ← 48pt       │
│                    │                                │              │
│                    │                                │              │
│                    │  ┌─────────┐  ┌─────────┐    │              │
│                    │  │    ✗    │  │    ✓    │    │              │
│                    │  │ Absent  │  │ Present │    │ ← 180pt      │
│                    │  │  (Red)  │  │ (Green) │    │              │
│                    │  └─────────┘  └─────────┘    │              │
│                    │                                │              │
│                    │  [Swipe Right to Undo] →      │              │
│                    └────────────────────────────────┘              │
│                                  │                                  │
│                    ┌─────────────┼──────────────┐                 │
│                    │             │              │                  │
│              [Tap Present]  [Tap Absent]  [Stop Button]           │
│                    │             │              │                  │
│              Haptic        Haptic         Confirm?                 │
│              Feedback      Feedback           │                    │
│                    │             │             │                   │
│              Record with   Record      Save Partial                │
│              Timestamp     Absent      Session                     │
│              (14:32:18)                  │                         │
│                    │             │       │                          │
│              Auto-advance  Auto-advance │                          │
│                    │             │       │                          │
│                    └──────┬──────┘       │                         │
│                           │              │                          │
│                    Next Attendee         │                          │
│                           │              │                          │
│                    [Repeat Until         │                          │
│                     All Done]            │                          │
│                           │              │                          │
│                           ↓              ↓                          │
│                    ┌────────────────────────────────┐              │
│                    │  Completion Screen             │              │
│                    │                                │              │
│                    │       ✓                        │              │
│                    │  Session Complete!             │              │
│                    │                                │              │
│                    │    7          3                │              │
│                    │  Present    Absent             │              │
│                    │                                │              │
│                    │  [Review Session]              │              │
│                    │  [Save & Exit]                 │              │
│                    └────────────────────────────────┘              │
│                           │              │                          │
│                   [Review Session]  [Save & Exit]                  │
│                           │              │                          │
│                           ↓              ↓                          │
│                  ┌──────────────┐   Save to                        │
│                  │ Session      │   Core Data                       │
│                  │ Review Modal │       │                           │
│                  │              │       ↓                           │
│                  │ Summary:     │   Return to                       │
│                  │ - 7 Present  │   List Detail                     │
│                  │ - 3 Absent   │                                   │
│                  │              │                                   │
│                  │ Details:     │                                   │
│                  │ ✓ Alice 8:15 │                                   │
│                  │ ✓ Bob 8:16   │                                   │
│                  │ ✗ Charlie    │                                   │
│                  │ ...          │                                   │
│                  │              │                                   │
│                  │  [Done]      │                                   │
│                  └──────────────┘                                   │
│                           │                                         │
│                      Back to                                        │
│                   Completion Screen                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Feature Access Map

### Main Screen (Lists View)
```
┌─────────────────────────────────────┐
│  Buzzer                         [+] │ ← Create new list
├─────────────────────────────────────┤
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Morning Route A        Mar 4  │ │ ← Tap to open
│  │ 👥 12 attendees              │ │ ← Swipe left to delete
│  └───────────────────────────────┘ │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Evening Route B        Mar 3  │ │
│  │ 👥 8 attendees               │ │
│  └───────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### List Detail View
```
┌─────────────────────────────────────┐
│ ← Morning Route A   [Edit] [▶️]     │
├─────────────────────────────────────┤
│                                     │
│  1. Alice Anderson          [✏️]    │ ← Tap pencil to edit
│  2. Bob Brown               [✏️]    │ ← Drag to reorder (Edit mode)
│  3. Charlie Chen            [✏️]    │
│  4. Diana Davis             [✏️]    │
│  ...                                │
│                                     │
├─────────────────────────────────────┤
│  [    Add    ]  [  Remove  ]       │ ← Bottom action bar
└─────────────────────────────────────┘
```

### Session Selection
```
┌─────────────────────────────────────┐
│ ← Start Session                     │
├─────────────────────────────────────┤
│                                     │
│           🚌                        │
│     Morning Route A                 │
│      12 attendees                   │
│                                     │
│                                     │
│  ┌─────────────────────────────┐  │
│  │   ↑  Start Pick-Up          │  │ ← Green
│  └─────────────────────────────┘  │
│  Last pick-up: 2 hours ago         │
│                                     │
│  ─────────────────────────────────  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │   ↓  Start Drop-Off         │  │ ← Orange
│  └─────────────────────────────┘  │
│  Last drop-off: 1 hour ago         │
│                                     │
└─────────────────────────────────────┘
```

### Attendance Tracking
```
┌─────────────────────────────────────┐
│ [Stop] Pick-Up                      │ ← Red stop button
├─────────────────────────────────────┤
│  3 of 12            ✓ 2    ✗ 1     │ ← Progress + summary
│  ════════                           │
├─────────────────────────────────────┤
│                                     │
│                                     │
│          Alice Anderson             │ ← 48pt centered
│                                     │
│          Marked Present             │ ← If already marked
│            at 2:15 PM               │
│                                     │
│                                     │
│  ┌──────────────┐  ┌──────────────┐│
│  │              │  │              ││
│  │      ✗       │  │      ✓       ││ ← 180pt tall
│  │              │  │              ││
│  │   Absent     │  │   Present    ││
│  │              │  │              ││
│  └──────────────┘  └──────────────┘│
│                                     │
│  ← Swipe right to undo              │
└─────────────────────────────────────┘
```

### Session Completion
```
┌─────────────────────────────────────┐
│                                     │
│              ✓                      │
│                                     │
│      Session Complete!              │
│                                     │
│                                     │
│        7          3                 │
│      Present    Absent              │
│                                     │
│                                     │
│  ┌─────────────────────────────┐  │
│  │    Review Session           │  │
│  └─────────────────────────────┘  │
│                                     │
│  ┌─────────────────────────────┐  │
│  │    Save & Exit              │  │ ← Green
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

### Session Review
```
┌─────────────────────────────────────┐
│ Session Review              [Done]  │
├─────────────────────────────────────┤
│  Summary                            │
│  ✓ Present           7              │
│  ✗ Absent            3              │
│  👥 Total           12              │
│                                     │
│  Attendance Details                 │
│  ✓ Alice Anderson    08:15:30       │
│  ✓ Bob Brown        08:16:12       │
│  ✗ Charlie Chen     Absent          │
│  ✓ Diana Davis      08:17:45       │
│  ...                                │
└─────────────────────────────────────┘
```

---

## 🔄 State Transitions

### Session State Machine
```
Idle (No Active Session)
    │
    │ [Tap Play → Choose Type]
    ↓
Session Active
    │
    ├→ [Tap Present/Absent]
    │     │
    │     ├→ Record Status
    │     ├→ Haptic Feedback
    │     └→ Auto-Advance
    │
    ├→ [Swipe Right]
    │     └→ Go to Previous
    │
    ├→ [Tap Stop]
    │     └→ Confirm → Save → Idle
    │
    └→ [Complete All]
          └→ Completion Screen
                │
                ├→ [Review Session]
                │     └→ Modal → Back to Completion
                │
                └→ [Save & Exit]
                      └→ Save → Idle
```

---

## 📊 Data Relationships

### Core Data Schema
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
    └─→ sessions [AttendanceSessionEntity]
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

---

## 🎨 Color Coding

### Phase 1 (List Management)
- **Accent Color**: System blue
- **Destructive**: Red (delete actions)
- **Neutral**: Gray (disabled states)

### Phase 2 (Attendance Tracking)
- **Pick-Up**: Green (sessions, present button)
- **Drop-Off**: Orange (sessions)
- **Absent**: Red (absent button)
- **Stop**: Red (stop button)
- **Neutral**: Gray (background, progress)

---

## ⌨️ Keyboard Shortcuts (Future)

For future iPad support:
```
⌘N - New List
⌘E - Edit Mode
⌘P - Start Pick-Up (if list selected)
⌘D - Start Drop-Off (if list selected)
⌘→ - Next Attendee (during session)
⌘← - Previous Attendee (during session)
Space - Mark Present (during session)
X - Mark Absent (during session)
⌘S - Save & Exit (on completion)
```

---

## 🔐 Permissions Required

### Current (Phase 1 & 2)
**None** - App is fully self-contained

### Future Phases
- **Phase 4**: File system access (CSV export)
- **Phase 5**: Network (Firebase Auth)
- **Phase 6**: iCloud (CloudKit sync)

---

**Last Updated**: March 4, 2026  
**Phases Complete**: 1 & 2  
**Document Version**: 1.0
