# Phase 2 Testing Guide

## 🧪 Complete Testing Checklist

---

## Pre-Testing Setup

1. ✅ Build project in Xcode (⌘B)
2. ✅ Select iPhone 15 simulator (or real device)
3. ✅ Run app (⌘R)
4. ✅ Create test list: "Test Route A"
5. ✅ Add 10 test attendees:
   - Alice Anderson
   - Bob Brown
   - Charlie Chen
   - Diana Davis
   - Ethan Evans
   - Fiona Fischer
   - George Garcia
   - Hannah Harris
   - Ian Ibrahim
   - Julia Jackson

---

## Test Case 1: Basic Pick-Up Session

### Steps
1. Open "Test Route A"
2. Tap play button (▶️) in toolbar
3. Tap "Start Pick-Up" (green button)
4. Mark Alice as Present
5. Mark Bob as Present
6. Mark Charlie as Absent
7. Mark Diana as Present
8. Continue through all 10 attendees

### Expected Results
- ✅ Session selection screen shows 10 attendees
- ✅ Large attendee name appears centered
- ✅ Progress shows "1 of 10", then "2 of 10", etc.
- ✅ Present counter increases (1, 2, 3...)
- ✅ Absent counter increases when marking absent
- ✅ Haptic feedback on each tap
- ✅ Smooth auto-advance animation
- ✅ After 10th attendee, completion screen shows
- ✅ Completion shows correct totals (e.g., "7 Present, 3 Absent")

---

## Test Case 2: Drop-Off Session

### Steps
1. Open "Test Route A"
2. Tap play button
3. Tap "Start Drop-Off" (orange button)
4. Mark all attendees as Present
5. Complete session

### Expected Results
- ✅ Orange color theme (vs green for pick-up)
- ✅ Title shows "Drop-Off"
- ✅ All attendees marked Present
- ✅ Completion shows "10 Present, 0 Absent"
- ✅ Can save successfully

---

## Test Case 3: Undo with Right Swipe

### Steps
1. Start a pick-up session
2. Mark Alice as Present
3. **Swipe right** on Bob's screen
4. Verify Alice appears again
5. Verify Alice still shows "Marked Present"
6. Change Alice to Absent
7. Verify it advances to Bob
8. Mark Bob as Present
9. Continue normally

### Expected Results
- ✅ Right swipe goes back to previous attendee
- ✅ Previous status is still shown
- ✅ Can change status
- ✅ Auto-advance still works
- ✅ Progress bar updates correctly

---

## Test Case 4: Stop Session Early

### Steps
1. Start a pick-up session
2. Mark only 3 attendees
3. Tap "Stop" button (top left, red)
4. Alert appears: "Stop Session?"
5. Tap "Stop"
6. Verify returns to list detail view

### Expected Results
- ✅ Confirmation alert appears
- ✅ Can cancel and continue session
- ✅ Stop saves partial session
- ✅ Returns to list view
- ✅ No crash or data loss

---

## Test Case 5: Session Review

### Steps
1. Complete a full session (all 10 attendees)
2. On completion screen, tap "Review Session"
3. Examine summary section
4. Scroll through attendee details
5. Tap "Done"

### Expected Results
- ✅ Summary shows correct totals
- ✅ Present attendees show green checkmark
- ✅ Absent attendees show red X
- ✅ Present attendees show timestamp (e.g., "14:32:18")
- ✅ Absent attendees show "Absent" text
- ✅ Can dismiss review

---

## Test Case 6: Timestamp Accuracy

### Steps
1. Start a session
2. Mark Alice as Present at 2:00:00 PM
3. **Wait 1 minute**
4. Mark Bob as Present at 2:01:00 PM
5. Complete session
6. Review session
7. Check timestamps

### Expected Results
- ✅ Alice timestamp ≈ 14:00:00
- ✅ Bob timestamp ≈ 14:01:00
- ✅ Timestamps differ by ~1 minute
- ✅ Format is HH:MM:SS (24-hour)

---

## Test Case 7: Empty List Prevention

### Steps
1. Create new list: "Empty Route"
2. Don't add any attendees
3. Tap play button
4. Observe session selection screen

### Expected Results
- ✅ Warning message appears
- ✅ "Start Pick-Up" button is disabled (grayed out)
- ✅ "Start Drop-Off" button is disabled
- ✅ Shows "Add attendees to this list before starting a session"

---

## Test Case 8: Large List Performance

### Steps
1. Create new list: "Big Route"
2. Add 50 attendees (use names: Person 1, Person 2, ... Person 50)
3. Start pick-up session
4. Mark all 50 as Present as fast as possible
5. Time the process
6. Complete session

### Expected Results
- ✅ No lag or stuttering
- ✅ Smooth animations throughout
- ✅ Can complete 50 attendees in < 2 minutes
- ✅ Save completes in < 1 second
- ✅ No crash

---

## Test Case 9: Multiple Sessions Per Day

### Steps
1. Complete a pick-up session
2. Immediately start another pick-up session
3. Complete it
4. Start a drop-off session
5. Complete it

### Expected Results
- ✅ Can start sessions immediately after finishing
- ✅ Each session is independent
- ✅ No data mixing between sessions
- ✅ All sessions save correctly
- ✅ Recent session display updates

---

## Test Case 10: Dark Mode

### Steps
1. Go to Settings → Display → Dark Mode
2. Return to app
3. Start a session
4. Mark some attendees

### Expected Results
- ✅ All text is readable
- ✅ Buttons have good contrast
- ✅ Progress bar is visible
- ✅ No white/bright flashes
- ✅ Green and red buttons still clear

---

## Test Case 11: Session Interruption (Background)

### Steps
1. Start a session
2. Mark 3 attendees
3. Swipe up to home screen (background app)
4. Wait 10 seconds
5. Return to app

### Expected Results
- ✅ Session still active
- ✅ Progress preserved (still on 4th attendee)
- ✅ Previous statuses preserved
- ✅ Can continue marking attendance
- ⚠️ If session reset, this is acceptable but note it

---

## Test Case 12: Session Interruption (Force Quit)

### Steps
1. Start a session
2. Mark 5 attendees
3. Swipe up to app switcher
4. Swipe up on app to force quit
5. Relaunch app
6. Open the list

### Expected Results
- ⚠️ Session is NOT saved (expected - session not stopped)
- ✅ App doesn't crash
- ✅ Can start new session
- ✅ Previous complete sessions still intact

---

## Test Case 13: Recent Session Display

### Steps
1. Complete a pick-up session
2. Exit to list view
3. Tap play button again
4. Observe session selection screen

### Expected Results
- ✅ Shows "Last pick-up: [time]" (e.g., "2 minutes ago")
- ✅ Drop-off shows no recent session (if never done)
- ✅ After completing drop-off, shows recent for both

---

## Test Case 14: Navigation Flow

### Steps
1. Lists screen → Select a list
2. List detail → Tap play button
3. Session selection → Start Pick-Up
4. Attendance tracking → Complete session
5. Completion screen → Tap "Review Session"
6. Session review → Tap "Done"
7. Completion screen → Tap "Save & Exit"
8. List detail → Tap back
9. Lists screen

### Expected Results
- ✅ Navigation is logical and clear
- ✅ Can't swipe back during session (back button hidden)
- ✅ All navigation animations smooth
- ✅ Returns to correct screen after save

---

## Test Case 15: Accessibility (VoiceOver)

### Steps
1. Settings → Accessibility → VoiceOver → On
2. Navigate to a list
3. Start a session
4. Use VoiceOver to select Present/Absent

### Expected Results
- ✅ All buttons have labels
- ✅ "Present" button reads "Present"
- ✅ "Absent" button reads "Absent"
- ✅ Progress is announced
- ✅ Can complete session with VoiceOver

---

## Test Case 16: Landscape Orientation (iPhone)

### Steps
1. Start a session
2. Rotate device to landscape
3. Mark some attendees

### Expected Results
- ✅ Layout adapts to landscape
- ✅ Buttons still accessible
- ✅ Text still readable
- ⚠️ If some clipping, note it (lower priority)

---

## Edge Cases

### Edge Case 1: Single Attendee List
1. Create list with 1 attendee
2. Start session
3. Mark as Present
4. Should immediately show completion

### Edge Case 2: Rapid Tapping
1. Start session
2. Tap Present button 10 times rapidly
3. Should only advance once per attendee

### Edge Case 3: Long Names
1. Add attendee: "Christopher Alexander Montgomery-Wellington III"
2. Start session
3. Verify name doesn't overflow

### Edge Case 4: Special Characters
1. Add attendee: "José María O'Brien-Müller"
2. Start session
3. Verify name displays correctly

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

## Performance Benchmarks

| Test | Target | Actual | Status |
|------|--------|--------|--------|
| 10 attendees | < 30 seconds | ___ | ⏳ |
| 25 attendees | < 1 minute | ___ | ⏳ |
| 50 attendees | < 2 minutes | ___ | ⏳ |
| Session save | < 0.5 seconds | ___ | ⏳ |
| Auto-advance | < 0.3 seconds | ___ | ⏳ |
| Undo swipe | Instant | ___ | ⏳ |

---

## ✅ Final Checklist

Before declaring Phase 2 complete:

- [ ] All 16 test cases pass
- [ ] All edge cases handled
- [ ] No crashes observed
- [ ] Dark mode works perfectly
- [ ] Performance meets targets
- [ ] VoiceOver works
- [ ] Code compiles with no warnings
- [ ] Documentation is accurate

---

## Known Issues to Watch For

Based on implementation, watch for:

1. **Swipe Back During Session**: Back button is hidden, but swipe gesture might still work
2. **Memory with Large Sessions**: 100+ attendees might cause slight delay
3. **Timestamp Precision**: Device time used, not server time
4. **Background State**: Session state might reset if backgrounded for long time

---

**Tester**: _______________  
**Date**: _______________  
**Device**: _______________  
**iOS Version**: _______________  
**Build**: Phase 2 - Attendance Tracking  

**Overall Status**: ⏳ Not Started / 🟡 In Progress / ✅ Passed / ❌ Failed
