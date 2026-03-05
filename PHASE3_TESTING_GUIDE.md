# 🧪 Phase 3 Testing Guide

**Quick testing steps to verify Phase 3 Session History works correctly**

---

## Prerequisites

Before testing Phase 3, you need some session data. If you don't have any:

1. Create a list with at least 3-5 attendees
2. Start a Pick-Up session and record attendance
3. Complete the session
4. Start a Drop-Off session and record attendance
5. Complete the session

Now you're ready to test Phase 3!

---

## Test 1: Access Session History ✅

### Steps:
1. Open any list that has attendees
2. Look for **clock icon** (🕐) in the top-left of the toolbar

### Expected Result:
- ✅ Clock icon is visible
- ✅ Clock icon is tappable

### Test:
3. Tap the clock icon

### Expected Result:
- ✅ Navigates to "Session History" screen
- ✅ Back button works to return to list detail

---

## Test 2: View Session List ✅

### On Session History screen:

### Expected Results:
- ✅ Sessions are grouped by date (e.g., "Today", "Yesterday", "March 4, 2026")
- ✅ Pick-up sessions have **green** arrow-up icon
- ✅ Drop-off sessions have **orange** arrow-down icon
- ✅ Each session shows:
  - Session type (Pick-Up or Drop-Off)
  - Time (e.g., "8:15 AM")
  - Present count with green checkmark
  - Absent count with red X
- ✅ Most recent sessions appear at the top

---

## Test 3: Filter by Session Type ✅

### Steps:
1. On Session History screen, look at the segmented control
2. It should show: **[All | Pick-Up | Drop-Off]**

### Test All Types:
3. Tap "All" → Should show both pick-up and drop-off sessions ✅
4. Tap "Pick-Up" → Should show only pick-up sessions (green icons) ✅
5. Tap "Drop-Off" → Should show only drop-off sessions (orange icons) ✅
6. Tap "All" again → Shows all sessions again ✅

---

## Test 4: Filter by Date ✅

### Steps:
1. Tap the **"Filter by Date: Today"** button

### Expected Result:
- ✅ Date picker sheet appears
- ✅ Calendar is displayed
- ✅ Cannot select future dates
- ✅ Today is highlighted

### Test Date Selection:
2. Select a **past date** (e.g., yesterday or a few days ago)
3. Tap "Done"

### Expected Result:
- ✅ Date filter updates to selected date
- ✅ Only sessions from that date are shown
- ✅ **"Clear Date Filter"** button appears

### Test Clear Filter:
4. Tap "Clear Date Filter"

### Expected Result:
- ✅ Filter resets to "Today"
- ✅ "Clear Date Filter" button disappears
- ✅ All today's sessions are shown

---

## Test 5: View Session Details ✅

### Steps:
1. From Session History, tap on **any session**

### Expected Result:
- ✅ Navigates to "Session Details" screen
- ✅ Back button returns to history

### Verify Session Information Section:
- ✅ **Session Type**: Shows "Pick-Up" or "Drop-Off" with correct icon
- ✅ **Date**: Shows full date (e.g., "March 5, 2026")
- ✅ **Time**: Shows time in HH:MM:SS format
- ✅ **List**: Shows list name

### Verify Summary Section:
- ✅ **Present**: Shows count with green checkmark
- ✅ **Absent**: Shows count with red X
- ✅ **Total**: Shows total attendee count
- ✅ **Attendance Rate**: Shows percentage with color:
  - Green if ≥90%
  - Orange if 70-89%
  - Red if <70%

### Verify Attendance Details Section:
- ✅ All attendees listed
- ✅ **Present attendees**: Green checkmark + name + timestamp (HH:MM:SS)
- ✅ **Absent attendees**: Red X + name + "Absent"
- ✅ Attendees in same order as the list

---

## Test 6: Empty States ✅

### Test No Sessions:
1. Create a **new list** with attendees
2. Tap clock icon (don't record any sessions yet)

### Expected Result:
- ✅ Shows empty state
- ✅ Message: "No attendance sessions have been recorded yet..."
- ✅ No "Clear Filters" button

### Test Filtered Empty State:
1. Go to a list with sessions
2. Tap clock icon
3. Filter to "Pick-Up" only (if you only have drop-off sessions, or vice versa)

### Expected Result:
- ✅ Shows empty state
- ✅ Message: "No pick-up sessions found. Try changing your filter."
- ✅ **"Clear Filters"** button is visible
- ✅ Tapping "Clear Filters" resets to "All" and today

### Test Date Filter Empty State:
1. Filter to a date with no sessions

### Expected Result:
- ✅ Shows empty state
- ✅ Message: "No sessions found on [date]. Try a different date."
- ✅ "Clear Filters" button works

---

## Test 7: Multiple Sessions Same Day ✅

### Setup:
1. Record 2-3 sessions on the same day (mix of pick-up and drop-off)

### Verify:
- ✅ All sessions grouped under same date section
- ✅ Sessions sorted by time (most recent first)
- ✅ Each session is distinct and tappable

---

## Test 8: Attendance Rate Color Coding ✅

### Create sessions with different attendance rates:

**High Attendance (≥90%)**:
- Record a session where 9+ out of 10 attendees are present
- Check detail view: **Attendance rate should be GREEN** ✅

**Medium Attendance (70-89%)**:
- Record a session where 7-8 out of 10 attendees are present
- Check detail view: **Attendance rate should be ORANGE** ✅

**Low Attendance (<70%)**:
- Record a session where fewer than 7 out of 10 attendees are present
- Check detail view: **Attendance rate should be RED** ✅

---

## Test 9: Navigation Flow ✅

### Full Navigation Test:
```
1. ListsView
   ↓ Tap a list
2. ListDetailView
   ↓ Tap clock icon 🕐
3. SessionHistoryView
   ↓ Tap a session
4. SessionDetailView
   ↓ Tap back
5. SessionHistoryView
   ↓ Tap back
6. ListDetailView
```

### Expected:
- ✅ All transitions are smooth
- ✅ Back navigation works at every level
- ✅ No crashes or freezes
- ✅ Data loads correctly at each screen

---

## Test 10: Export Button (Phase 4 Placeholder) ✅

### Steps:
1. Open any session detail view
2. Look for **share icon** (⬆️) in top-right

### Expected:
- ✅ Share button is visible
- ✅ Tapping it opens a sheet
- ✅ Sheet shows "Export functionality will be available in Phase 4"
- ✅ Sheet shows session summary (type, date, attendee count)
- ✅ "Done" button closes the sheet

---

## Test 11: Edge Cases ✅

### Empty Session (No Attendees):
- This shouldn't happen normally, but verify app doesn't crash

### Session with All Present:
- ✅ Attendance rate = 100%
- ✅ Color = Green
- ✅ Absent count = 0

### Session with All Absent:
- ✅ Attendance rate = 0%
- ✅ Color = Red
- ✅ Present count = 0
- ✅ All timestamps = nil / "Absent"

### Very Old Sessions:
- ✅ Date displayed correctly (not "Today" or "Yesterday")
- ✅ Grouped under specific date section

---

## Test 12: Dark Mode ✅

### Steps:
1. Enable Dark Mode in iOS Settings or Control Center
2. Navigate through all Phase 3 screens

### Verify:
- ✅ Session History list readable in dark mode
- ✅ Icons and colors still visible
- ✅ Session detail view readable
- ✅ Date picker readable
- ✅ No white text on white backgrounds
- ✅ No black text on black backgrounds

---

## Test 13: Data Persistence ✅

### Steps:
1. View session history
2. Force quit the app (swipe up in app switcher)
3. Relaunch the app
4. Navigate back to session history

### Expected:
- ✅ All sessions still present
- ✅ Filters reset to default (All, Today)
- ✅ Session details still accessible
- ✅ No data loss

---

## Test 14: Performance ✅

### With 10+ Sessions:
- ✅ List scrolls smoothly
- ✅ Filtering is instant
- ✅ Navigation is smooth
- ✅ No lag or stuttering

---

## ✅ Complete Test Summary

If all tests pass, Phase 3 is fully functional! ✅

### Critical Tests (Must Pass):
- [ ] Clock icon appears and works
- [ ] Sessions display correctly
- [ ] Type filter works (All/Pick-Up/Drop-Off)
- [ ] Date filter works
- [ ] Session details show correct information
- [ ] Attendance rate calculated correctly
- [ ] Empty states display properly
- [ ] Navigation works smoothly

### Nice-to-Have Tests:
- [ ] Dark mode looks good
- [ ] Performance is smooth
- [ ] Edge cases handled gracefully

---

## 🐛 Common Issues & Solutions

### Issue: Clock icon not showing
**Solution**: Make sure list has attendees (icon only shows when list is not empty)

### Issue: No sessions in history
**Solution**: Record at least one pick-up or drop-off session first

### Issue: Date filter not working
**Solution**: Make sure you selected a date and tapped "Done"

### Issue: Attendance rate wrong
**Solution**: Check the actual present/absent counts in the session

### Issue: Sessions not grouped correctly
**Solution**: Check that session dates are being saved correctly (might be a timezone issue)

---

**If all tests pass, Phase 3 is ready for production use! 🎉**
