# Phase 3 Testing Guide

## 🧪 Complete Testing Checklist

---

## Pre-Testing Setup

1. ✅ Ensure Phase 2 is complete (can record sessions)
2. ✅ Create test list: "Test Route"
3. ✅ Add 10 test attendees
4. ✅ Record 3 sessions:
   - Pick-up today (mark 7 present, 3 absent)
   - Drop-off today (mark 9 present, 1 absent)
   - Pick-up yesterday (mark 5 present, 5 absent)

**Note**: To create "yesterday" session, you may need to temporarily modify system date or accept that this test is optional.

---

## Test Case 1: View Session History

### Steps
1. Open "Test Route" list
2. Tap clock icon (🕐) in top left of toolbar
3. Session History view appears

### Expected Results
- ✅ Title shows "Session History"
- ✅ Filter bar at top with segmented control
- ✅ Sessions grouped by date
- ✅ "Today" section with 2 sessions (pick-up and drop-off)
- ✅ If yesterday session exists, "Yesterday" section with 1 session
- ✅ Sessions show type icon (↑ green or ↓ orange)
- ✅ Sessions show time (e.g., "3:15 PM")
- ✅ Sessions show counts (e.g., "✓ 7 present ✗ 3 absent")

---

## Test Case 2: Filter by Session Type

### Steps
1. In session history, tap segmented control
2. Select "Pick-Up"
3. Observe list updates
4. Select "Drop-Off"
5. Observe list updates
6. Select "All"

### Expected Results
- ✅ "Pick-Up" filter shows only pick-up sessions
- ✅ Drop-off sessions disappear
- ✅ "Drop-Off" filter shows only drop-off sessions
- ✅ Pick-up sessions disappear
- ✅ "All" shows all sessions again
- ✅ Filter updates instantly (no delay)
- ✅ Section headers update if dates change

---

## Test Case 3: Filter by Date

### Steps
1. In session history, tap "Filter by Date" button
2. Date picker sheet appears
3. Select today's date
4. Tap "Done"
5. Verify only today's sessions show
6. Tap "Filter by Date" again
7. Select a date with no sessions
8. Tap "Done"

### Expected Results
- ✅ Date picker shows calendar interface
- ✅ Future dates are disabled
- ✅ Can select any past date
- ✅ After selecting today, only today's sessions visible
- ✅ "Filter by Date" button shows selected date
- ✅ When selecting date with no sessions, empty state appears
- ✅ Empty state says "No sessions found on [date]"

---

## Test Case 4: Clear Date Filter

### Steps
1. Filter by a specific past date
2. Verify "Clear Date Filter" button appears
3. Tap "Clear Date Filter"
4. Verify all sessions appear again

### Expected Results
- ✅ "Clear Date Filter" button appears when date ≠ today
- ✅ Button has blue text with X icon
- ✅ Tapping button resets filter to today
- ✅ All sessions reappear
- ✅ Button disappears after clearing

---

## Test Case 5: View Session Details

### Steps
1. In session history, tap on a session
2. Session Detail view appears
3. Review all sections

### Expected Results
- ✅ Navigation title: "Session Details"
- ✅ Export button in toolbar (top right)
- ✅ **Session Information section**:
  - Session Type with icon (↑ Pick-Up or ↓ Drop-Off)
  - Date (long format, e.g., "March 4, 2026")
  - Time (HH:MM:SS, e.g., "15:30:45")
  - List name
- ✅ **Summary section**:
  - Present count (green checkmark)
  - Absent count (red X)
  - Total count (gray icon)
  - Attendance rate % (color-coded)
- ✅ **Attendance Details section**:
  - All attendees listed
  - Status icons (✓ or ✗)
  - Timestamps for present attendees
  - "Absent" text for absent attendees

---

## Test Case 6: Attendance Rate Calculation

### Steps
1. View session with 90%+ attendance
2. Note attendance rate color
3. View session with 70-89% attendance
4. Note attendance rate color
5. View session with <70% attendance
6. Note attendance rate color

### Expected Results
- ✅ 90%+ attendance rate: **Green** text
- ✅ 70-89% attendance rate: **Orange** text
- ✅ <70% attendance rate: **Red** text
- ✅ Percentage calculated correctly:
  - 7/10 present = 70%
  - 9/10 present = 90%
  - 5/10 present = 50%

---

## Test Case 7: Attendee Order in Session Detail

### Steps
1. Open session detail
2. Note the order of attendees
3. Go back to list
4. Check original attendee order
5. Verify they match

### Expected Results
- ✅ Attendees in session detail appear in same order as list
- ✅ NOT sorted alphabetically
- ✅ NOT sorted by status (present/absent)
- ✅ Order matches pickup/dropoff order from original list

---

## Test Case 8: Empty State - No Sessions

### Steps
1. Create new list "Empty List"
2. Add 5 attendees
3. Tap clock icon to view history
4. Observe empty state

### Expected Results
- ✅ Empty state appears with clock icon
- ✅ Title: "No Sessions Found"
- ✅ Message: "No attendance sessions have been recorded yet..."
- ✅ Helpful text explaining next steps
- ✅ No "Clear Filters" button (since there are no sessions)

---

## Test Case 9: Empty State - Filter Active

### Steps
1. Go to session history with sessions
2. Filter by "Pick-Up"
3. If only drop-off sessions exist, observe empty state
4. Verify message

### Expected Results
- ✅ Empty state appears
- ✅ Message mentions filter type: "No pick-up sessions found"
- ✅ "Clear Filters" button appears
- ✅ Tapping "Clear Filters" resets to "All" and today's date
- ✅ Sessions reappear

---

## Test Case 10: Export Button (Placeholder)

### Steps
1. Open session detail
2. Tap export button (top right)
3. Export sheet appears

### Expected Results
- ✅ Sheet titled "Export Session"
- ✅ Message: "Export functionality will be available in Phase 4"
- ✅ Shows session summary (type, date, attendee count)
- ✅ Footer text about Phase 4
- ✅ "Done" button dismisses sheet
- ✅ No actual export happens (expected)

---

## Test Case 11: Navigation Flow

### Steps
1. Lists screen → Select list
2. List detail → Tap clock icon
3. Session history → Tap session
4. Session detail → Tap back
5. Session history → Tap back
6. List detail

### Expected Results
- ✅ Navigation is smooth and logical
- ✅ Back button labeled correctly at each level
- ✅ No navigation stack issues
- ✅ Can navigate forward and back freely
- ✅ State preserved when going back

---

## Test Case 12: Dark Mode

### Steps
1. Go to Settings → Display → Dark Mode
2. Return to app
3. Navigate to session history
4. View session details

### Expected Results
- ✅ All text readable in dark mode
- ✅ Filter bar has correct background
- ✅ Session rows have good contrast
- ✅ Icons visible and clear
- ✅ Attendance rate colors still clear
- ✅ Empty state readable

---

## Test Case 13: Large Session Count

### Steps
1. Record 10+ sessions (mix of pick-up and drop-off)
2. View session history
3. Scroll through list
4. Filter by type
5. Filter by different dates

### Expected Results
- ✅ List scrolls smoothly
- ✅ No lag or stuttering
- ✅ Filtering remains fast
- ✅ Sections update correctly
- ✅ All sessions load properly

---

## Test Case 14: Session with 100% Attendance

### Steps
1. Record session where all attendees marked Present
2. View session detail
3. Check attendance rate

### Expected Results
- ✅ Attendance rate shows 100%
- ✅ Color is green
- ✅ Absent count is 0
- ✅ Present count equals total
- ✅ All attendees show timestamps

---

## Test Case 15: Session with 0% Attendance

### Steps
1. Record session where all attendees marked Absent
2. View session detail
3. Check attendance rate

### Expected Results
- ✅ Attendance rate shows 0%
- ✅ Color is red
- ✅ Present count is 0
- ✅ Absent count equals total
- ✅ All attendees show "Absent" text
- ✅ No timestamps displayed

---

## Test Case 16: Multiple Sessions Same Day

### Steps
1. Record 3 sessions today:
   - Pick-up at 8 AM
   - Drop-off at 3 PM
   - Pick-up at 5 PM (if testing allows)
2. View session history

### Expected Results
- ✅ All 3 sessions appear under "Today" section
- ✅ Sessions sorted by time (recent first)
- ✅ Each shows correct time
- ✅ Can distinguish between sessions
- ✅ Can tap and view each individually

---

## Test Case 17: Filter Combination (Type + Date)

### Steps
1. Go to session history
2. Select "Pick-Up" filter
3. Select specific past date
4. Verify only pick-up sessions from that date show
5. Clear filters

### Expected Results
- ✅ Both filters apply simultaneously
- ✅ Only sessions matching BOTH criteria appear
- ✅ If no matches, empty state shows
- ✅ Clearing filters shows all sessions again
- ✅ Filter state doesn't persist between views

---

## Test Case 18: Timestamp Formatting

### Steps
1. View session detail
2. Check timestamp formats
3. Compare to session list time

### Expected Results
- ✅ **Session list**: 12-hour format with AM/PM (e.g., "3:15 PM")
- ✅ **Session detail header**: 24-hour HH:MM:SS (e.g., "15:15:30")
- ✅ **Attendee timestamps**: 24-hour HH:MM:SS (e.g., "08:15:30")
- ✅ All times accurate to the second
- ✅ Times match original recording

---

## Edge Cases

### Edge Case 1: Session Created at Midnight
1. Record session at 12:00 AM
2. Verify it appears in correct date section
3. Check time display

### Edge Case 2: Very Long Attendee Name
1. Add attendee: "Christopher Alexander Montgomery-Wellington III"
2. Record session with them
3. View in history and detail
4. Verify name doesn't overflow

### Edge Case 3: Date Picker Boundaries
1. Open date picker
2. Try to select future date
3. Try to select very old date (5 years ago)
4. Verify behavior

### Edge Case 4: Rapid Filter Changes
1. Rapidly tap between filter types
2. Verify UI updates correctly
3. No crashes or glitches

---

## Performance Benchmarks

| Test | Target | Actual | Status |
|------|--------|--------|--------|
| Load 10 sessions | < 0.1s | ___ | ⏳ |
| Load 50 sessions | < 0.5s | ___ | ⏳ |
| Load 100 sessions | < 1s | ___ | ⏳ |
| Filter by type | Instant | ___ | ⏳ |
| Filter by date | Instant | ___ | ⏳ |
| Open session detail | Instant | ___ | ⏳ |
| Scroll large list | Smooth | ___ | ⏳ |

---

## Bug Report Template

If you find issues, report using this format:

```
**Bug Title**: [Brief description]

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Result**:
[What should happen]

**Actual Result**:
[What actually happened]

**Screenshot/Video**: [If available]

**Device**: iPhone 15 Pro / iOS 17.4 / Simulator

**Severity**: Critical / High / Medium / Low

**Workaround**: [If any]
```

---

## ✅ Final Checklist

Before declaring Phase 3 complete:

- [ ] All 18 test cases pass
- [ ] All edge cases handled
- [ ] No crashes observed
- [ ] Dark mode works perfectly
- [ ] Performance meets targets
- [ ] Navigation is smooth
- [ ] Code compiles with no warnings
- [ ] Documentation is accurate

---

## Known Issues to Watch For

Based on implementation, watch for:

1. **Date Picker Future Dates**: Ensure future dates are disabled
2. **Filter State**: Filters should reset when leaving and returning to view
3. **Empty Sessions**: Handle case where session has no records
4. **Deleted Attendees**: Handle case where attendee was deleted after session
5. **Large Lists**: Performance with 100+ sessions

---

**Tester**: _______________  
**Date**: _______________  
**Device**: _______________  
**iOS Version**: _______________  
**Build**: Phase 3 - Session History  

**Overall Status**: ⏳ Not Started / 🟡 In Progress / ✅ Passed / ❌ Failed

