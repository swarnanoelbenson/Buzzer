# 🧪 Phase 4 Testing Guide

**Quick testing steps to verify Phase 4 CSV Export works correctly**

---

## Prerequisites

Before testing Phase 4, you need:
1. At least one list with attendees
2. At least 2-3 recorded sessions (pick-up and drop-off)
3. iOS device or simulator with Files app

---

## Test 1: Export Single Session ✅

### Steps:
1. Navigate to **Session History** (tap clock icon in list detail)
2. Tap any session to open **Session Detail**
3. Look for **share icon** (⬆️) in top-right toolbar

### Expected:
- ✅ Share icon is visible
- ✅ Tap opens "Export Session" sheet

### On Export Sheet:
4. Verify session summary displays:
   - ✅ Session Type (Pick-Up or Drop-Off) with color
   - ✅ Date
   - ✅ Time
   - ✅ Attendee count
   - ✅ Present count
   - ✅ Absent count

5. Tap **"Export as CSV"** button

### Expected:
- ✅ iOS Share Sheet appears
- ✅ File preview shows CSV icon

### Test Saving:
6. Tap **"Save to Files"**
7. Choose **"On My iPhone"** or **"iCloud Drive"**
8. Tap **"Save"**

### Expected:
- ✅ File saves successfully
- ✅ Success message appears (or sheet dismisses)

### Verify File:
9. Open **Files app**
10. Navigate to where you saved the file
11. Tap the CSV file

### Expected:
- ✅ File opens (preview or in Numbers if installed)
- ✅ Contains header with metadata
- ✅ Contains column headers
- ✅ Contains attendee data
- ✅ Timestamps formatted as HH:MM:SS
- ✅ "Absent" shown for absent attendees
- ✅ Attendees in correct order

---

## Test 2: Email CSV File ✅

### Steps:
1. Open Session Detail
2. Tap share icon ⬆️
3. Tap "Export as CSV"
4. In Share Sheet, tap **"Mail"**

### Expected:
- ✅ Email compose window opens
- ✅ CSV file attached
- ✅ Filename visible in attachment
- ✅ Can add recipient and send

---

## Test 3: AirDrop CSV File ✅

### Steps:
1. Have another Apple device nearby with AirDrop enabled
2. Export a session CSV
3. In Share Sheet, tap **AirDrop**
4. Select the other device

### Expected:
- ✅ File transfers successfully
- ✅ Recipient receives CSV file
- ✅ File opens correctly on receiving device

---

## Test 4: Generate Today's Report ✅

### Steps:
1. Navigate to **Session History**
2. Tap **share icon** (⬆️) in top-right toolbar

### Expected:
- ✅ "Generate Report" sheet opens

### On Report Generation View:
3. Verify default settings:
   - ✅ Report Type: "Today" (default)
   - ✅ List name shown in preview
   - ✅ Sessions count shown
   - ✅ Filename preview shown

4. Tap **"Generate & Export CSV"**

### Expected:
- ✅ Loading indicator appears briefly
- ✅ Share Sheet opens
- ✅ File ready to share

5. Save to Files app

### Verify Today's Report Format:
6. Open the saved file

### Expected:
- ✅ Header shows "Report Date: [Today's Date]"
- ✅ Columns: Serial Number, Attendee Name, Pick-up Timestamp, Drop-off Timestamp
- ✅ Each attendee has one row
- ✅ Pick-up time in column 3 (if present at pick-up)
- ✅ Drop-off time in column 4 (if present at drop-off)
- ✅ "Absent" if not present

---

## Test 5: Generate Yesterday's Report ✅

### Setup:
If you don't have yesterday's sessions, skip this test or record some manually changing system date (not recommended).

### Steps:
1. Open Report Generation view
2. Change **Report Type** to **"Yesterday"**

### Expected:
- ✅ Description updates
- ✅ Session count updates (0 if no yesterday sessions)

3. If sessions exist, tap "Generate & Export CSV"

### Expected:
- ✅ Share Sheet appears
- ✅ File contains only yesterday's sessions

---

## Test 6: Generate This Week Report ✅

### Steps:
1. Open Report Generation view
2. Change **Report Type** to **"This Week"**

### Expected:
- ✅ Description: "Export sessions from the last 7 days"
- ✅ Session count shows all sessions from last 7 days

3. Tap "Generate & Export CSV"
4. Save and open file

### Expected:
- ✅ Header shows "All Sessions" or date range
- ✅ Columns: Serial Number, Attendee Name, Date, Session Type, Status, Timestamp
- ✅ Multiple sessions per attendee (if they have multiple)
- ✅ Sessions sorted chronologically (oldest first)
- ✅ Date column shows YYYY-MM-DD format

---

## Test 7: Generate This Month Report ✅

### Steps:
1. Open Report Generation view
2. Change **Report Type** to **"This Month"**

### Expected:
- ✅ Description: "Export sessions from the last 30 days"
- ✅ Session count updates

3. Generate and verify file format (same as This Week)

---

## Test 8: Generate Date Range Report ✅

### Steps:
1. Open Report Generation view
2. Change **Report Type** to **"Date Range"**

### Expected:
- ✅ Date picker controls appear
- ✅ Start Date and End Date fields visible

3. Tap **"Start Date"**
   - ✅ Date picker appears
   - ✅ Cannot select future dates
   - ✅ Can select past dates

4. Select a date 3-4 days ago
5. Tap **"End Date"**
   - ✅ Date picker appears
   - ✅ Cannot select dates before start date
   - ✅ Cannot select future dates

6. Select today's date
7. Verify preview:
   - ✅ Session count updates
   - ✅ Filename shows "YYYY-MM-DD_to_YYYY-MM-DD_ListName.csv"

8. Tap "Generate & Export CSV"
9. Save and open file

### Expected:
- ✅ Header shows "Date Range: [start] to [end]"
- ✅ Contains only sessions within range
- ✅ Format same as multi-session report

---

## Test 9: Generate All Sessions Report ✅

### Steps:
1. Open Report Generation view
2. Change **Report Type** to **"All Sessions"**

### Expected:
- ✅ Description: "Export all available sessions for this list"
- ✅ Session count shows total sessions ever recorded

3. Tap "Generate & Export CSV"
4. Save and open file

### Expected:
- ✅ Contains ALL sessions
- ✅ Sorted chronologically
- ✅ Complete history of the list

---

## Test 10: Empty Report ✅

### Steps:
1. Create a **new list** with attendees (no sessions)
2. Navigate to Session History (will be empty)
3. Tap share icon ⬆️
4. Try to generate "Today" report

### Expected:
- ✅ Session count shows 0
- ✅ Warning message: "No sessions available for the selected criteria"
- ✅ "Generate & Export CSV" button is **disabled** (grayed out)

---

## Test 11: File Naming ✅

### Single Session Export:
- ✅ Format: `YYYY-MM-DD_HH-MM_Type_ListName.csv`
- ✅ Example: `2026-03-05_08-15_Pickup_Morning_Route.csv`
- ✅ Spaces replaced with underscores
- ✅ Special characters removed

### Today's Report:
- ✅ Format: `YYYY-MM-DD_ListName.csv`
- ✅ Example: `2026-03-05_Morning_Route.csv`

### Date Range:
- ✅ Format: `YYYY-MM-DD_to_YYYY-MM-DD_ListName.csv`
- ✅ Example: `2026-03-01_to_2026-03-05_Morning_Route.csv`

### All Sessions:
- ✅ Format: `YYYY-MM-DD_All_Sessions_ListName.csv`
- ✅ Example: `2026-03-05_All_Sessions_Morning_Route.csv`

---

## Test 12: CSV Content Validation ✅

### Open Any Exported CSV in Text Editor:

### Check Header:
- ✅ `Report Generated: YYYY-MM-DD HH:MM:SS`
- ✅ `List: [List Name]`
- ✅ Other metadata as appropriate
- ✅ Blank line after metadata

### Check Column Headers:
- ✅ First row after metadata
- ✅ Comma-separated
- ✅ Correct columns for report type

### Check Data Rows:
- ✅ Serial numbers start at 1
- ✅ Attendee names in double quotes: `"John Doe"`
- ✅ Names with commas properly escaped: `"Smith, John"`
- ✅ Timestamps in HH:MM:SS format: `08:15:30`
- ✅ Absent shown as: `Absent`
- ✅ Dates in YYYY-MM-DD format: `2026-03-05`

---

## Test 13: Special Characters ✅

### Setup:
1. Create attendees with special names:
   - Name with comma: "Smith, John"
   - Name with quote: `O'Brien`
   - Name with accent: "José García"
   - Name with emoji: "John 😊 Doe"

2. Record a session with these attendees
3. Export the session

### Expected:
- ✅ All names export correctly
- ✅ Commas don't break columns (names quoted)
- ✅ Accents preserved (UTF-8 encoding)
- ✅ Emoji preserved (if supported)
- ✅ CSV opens correctly in spreadsheet app

---

## Test 14: Large Dataset ✅

### Setup:
1. Create a list with 50+ attendees
2. Record multiple sessions
3. Export "All Sessions" report

### Expected:
- ✅ All attendees included
- ✅ No data truncation
- ✅ File opens correctly
- ✅ Scrolling works in spreadsheet app
- ✅ No performance issues during export

---

## Test 15: Share to Other Apps ✅

### Test sharing to various apps:

1. **Numbers** (Apple)
   - ✅ Opens correctly
   - ✅ Columns formatted properly
   - ✅ Data readable

2. **Excel** (Microsoft, if installed)
   - ✅ Opens correctly
   - ✅ No import errors

3. **Google Drive**
   - ✅ Uploads successfully
   - ✅ File accessible from web

4. **Dropbox**
   - ✅ Uploads successfully
   - ✅ Syncs to cloud

5. **Notes** (Apple)
   - ✅ Can attach to note
   - ✅ File remains accessible

---

## Test 16: Error Handling ✅

### Test file creation failure:

This is hard to test without modifying permissions, but verify:
- ✅ If export fails, error alert appears
- ✅ Error message is clear: "Failed to create CSV file. Please try again."
- ✅ "OK" button dismisses alert
- ✅ Can retry export

---

## Test 17: Multiple Exports ✅

### Steps:
1. Export the same session 3 times in a row
2. Save all to Files app

### Expected:
- ✅ Each export creates a new file (doesn't overwrite)
- ✅ System may add numbers to filename (e.g., "file (1).csv", "file (2).csv")
- ✅ All files open correctly
- ✅ No conflicts

---

## Test 18: Cancel Operations ✅

### Test canceling at various points:

1. Open Export Options → Tap "Done"
   - ✅ Sheet dismisses, no export

2. Open Export Options → Tap "Export as CSV" → Cancel share sheet
   - ✅ Returns to Export Options or dismisses

3. Open Report Generation → Tap "Cancel"
   - ✅ Sheet dismisses, no export

4. Open Report Generation → Generate → Cancel share sheet
   - ✅ Returns to Report Generation or dismisses

---

## Test 19: Dark Mode ✅

### Steps:
1. Enable Dark Mode
2. Navigate through export flows

### Expected:
- ✅ All text readable
- ✅ Buttons visible
- ✅ Icons clear
- ✅ Share sheet works normally
- ✅ No white-on-white or black-on-black text

---

## Test 20: Integration Test (Full Flow) ✅

### Complete workflow:
1. ✅ Create a list
2. ✅ Add 5 attendees
3. ✅ Record pick-up session (some present, some absent)
4. ✅ Record drop-off session (different attendance)
5. ✅ Navigate to Session History
6. ✅ Export individual pick-up session → Verify CSV
7. ✅ Export individual drop-off session → Verify CSV
8. ✅ Generate "Today" report → Verify combined format
9. ✅ Email the report
10. ✅ Save to Files app
11. ✅ Open in Numbers/Excel
12. ✅ Verify data accuracy against original sessions

---

## ✅ Complete Test Summary

### Critical Tests (Must Pass):
- [ ] Single session export works
- [ ] Share sheet appears and functions
- [ ] Files save to Files app
- [ ] CSV format is correct
- [ ] Today's report combines pick-up/drop-off
- [ ] Date range selection works
- [ ] File naming is correct
- [ ] Special characters handled
- [ ] Email sharing works
- [ ] CSV opens in spreadsheet apps

### Nice-to-Have Tests:
- [ ] AirDrop works
- [ ] Large datasets handle well
- [ ] Error handling graceful
- [ ] Dark mode looks good
- [ ] Multiple exports don't conflict

---

## 🐛 Common Issues & Solutions

### Issue: Share sheet doesn't appear
**Solution**: Check that file URL is not nil, verify temporary directory is writable

### Issue: CSV shows weird characters
**Solution**: Ensure UTF-8 encoding is used, verify text editor supports UTF-8

### Issue: Names with commas break columns
**Solution**: Verify names are enclosed in double quotes in CSV

### Issue: Can't save to Files app
**Solution**: Check iOS permissions, ensure Files app is accessible

### Issue: Email doesn't attach file
**Solution**: Verify file exists in temporary directory, check file size

### Issue: File naming has weird characters
**Solution**: Check sanitizeFilename() function is being used

---

## 📊 Sample Test Data

### Recommended Test Attendees:
```
1. John Doe
2. Smith, Jane (with comma)
3. O'Brien, Patrick (with apostrophe)
4. José García (with accents)
5. Alice Williams
6. Bob Johnson
```

### Recommended Test Sessions:
- **Pick-Up Session 1**: All present (6/6)
- **Drop-Off Session 1**: 1 absent (5/6)
- **Pick-Up Session 2** (next day): 2 absent (4/6)
- **Drop-Off Session 2**: All present (6/6)

This gives you variety to test all scenarios.

---

**If all tests pass, Phase 4 is production-ready! 🎉**
