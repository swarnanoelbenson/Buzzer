# WAC Test Cases

Web Admin Console — manual test cases for QA.
Each test lists what to do, what should happen, and a note if the feature is not yet implemented.

---

## 1. Schedule

### 1.1 Create schedule with a past start date
**Steps:** Open Add Schedule. Set Start Date to any date in the past (e.g. yesterday). Set End Date to next week. Fill rest and submit.
**Expected:** Should be rejected with an error — "Start date cannot be in the past."
**Current behaviour:** Allowed. No validation exists yet.
**Fix options:**
- A) Add a client-side check: `if (startDate < today) show error`
- B) Disable past dates on the date picker (`min={today}`)

---

### 1.2 Create schedule where end date is before start date
**Steps:** Set Start Date to next Monday. Set End Date to the previous Friday. Submit.
**Expected:** Should be rejected — "End date must be after start date."
**Current behaviour:** Allowed. Trips are generated but the date loop produces zero dates silently.
**Fix options:**
- A) Client-side check: `if (endDate < startDate) show error`
- B) Disable end dates before start date on the date picker

---

### 1.3 Create schedule with no days selected
**Steps:** Open Add Schedule. Deselect all days (click Mon–Fri to turn them off). Fill all other fields and upload a valid student file. Submit.
**Expected:** Should be rejected — "Select at least one scheduled day."
**Current behaviour:** Allowed. Zero trips are created.
**Fix options:**
- A) Disable submit button if `selectedDays.length === 0`
- B) Show inline error before submit

---

### 1.4 Create schedule with no students uploaded
**Steps:** Fill in all route details. Do not upload an Excel file. Click submit.
**Expected:** Submit button should be disabled until a file with at least one student is uploaded.
**Current behaviour:** Button is already disabled if `preview.length === 0`. Works correctly.

---

### 1.5 Upload a non-xlsx file
**Steps:** In the student upload zone, upload a `.csv` or `.png` file.
**Expected:** Error — "Could not parse file. Make sure it is a valid .xlsx file."
**Current behaviour:** Error message appears. Works correctly.

---

### 1.6 Upload an xlsx where columns are in the wrong order
**Steps:** Create an Excel file with columns swapped (e.g. Grade in column A, Name in column B). Upload it.
**Expected:** Data is imported incorrectly (name reads as grade, etc.) — ideally should show a warning.
**Current behaviour:** Silently misreads data. No header validation.
**Fix options:**
- A) Read column headers in row 1 and match by name instead of position
- B) Show header names in the preview table so the admin can spot the mismatch

---

### 1.7 Substitute driver for one week
**Scenario:** Driver A is on leave for Week 3. Driver B should cover their route for that week only.
**Expected:** An easy way to reassign a route to a temporary driver and revert after.
**Current behaviour:** Edit Schedule lets you change the driver for the whole route permanently. You can do it manually — change to Driver B before Week 3, then change back after — but there is no "temporary override" concept and no audit of who drove which specific trips.
**Fix options:**
- A) (Simple) Allow editing the driver on individual trips (trip-level driver field). Admin changes trip by trip or selects a date range.
- B) (Better) Add a "Driver Override" field on the route — set a substitute driver with a from/to date range. The app uses this driver for that window, then reverts automatically.

---

### 1.8 Edit a schedule that already has completed trips
**Steps:** Find a route with completed trips. Open Edit. Change the driver. Save.
**Expected:** Only future trips should be updated. Completed trip records should keep the original driver ID for audit purposes.
**Current behaviour:** Route's `driverId` is updated globally. Past trip records are not changed (trips store their own driverId), so historical trips are safe — but this is not obvious to the admin.
**Fix options:**
- A) Add a note in the Edit modal: "Changes apply to future trips only."

---

### 1.9 Remove a schedule that has upcoming trips
**Steps:** Remove an active route that has future trips scheduled.
**Expected:** Should warn the admin that X upcoming trips exist and will be affected (or cancelled).
**Current behaviour:** Route is soft-deactivated. Trips are not cancelled or updated.
**Fix options:**
- A) Show a count of upcoming trips in the Remove confirmation modal
- B) Automatically set upcoming trips to status: "cancelled" when a route is removed

---

### 1.10 Download the student template and upload it back
**Steps:** Enter "5" in the student count field. Click Download. Open the file. Fill in all 5 students. Upload the file.
**Expected:** Preview table shows all 5 students with correct columns.
**Current behaviour:** Works correctly if columns are in the right order.

---

### 1.11 Duplicate route name
**Steps:** Create a route called "Route A". Then try to create another route also called "Route A".
**Expected:** Should warn — "A route with this name already exists."
**Current behaviour:** Allowed. Both routes are created.
**Fix options:**
- A) Query Firestore for matching route names before saving
- B) Show a soft warning (not a hard block) — "Another route has this name. Are you sure?"

---

## 2. Drivers

### 2.1 Add a driver under minimum age
**Steps:** Add a driver and set Age to 17.
**Expected:** Should be rejected — "Driver must be at least 21 years old." (or whatever the legal minimum is)
**Current behaviour:** Allowed. Any number is saved.
**Fix options:**
- A) Add client-side check: `if (age < 21) show error`

---

### 2.2 Add a driver with an expired licence
**Steps:** Set Licence Expiry to a date in the past.
**Expected:** Should warn — "Licence expiry date is in the past."
**Current behaviour:** Allowed with no warning.
**Fix options:**
- A) Show a yellow warning but still allow saving (driver may be in the process of renewing)
- B) Hard block with an error

---

### 2.3 Add a driver with a licence expiring soon
**Steps:** Set Licence Expiry to a date within the next 30 days.
**Expected:** Show a warning — "Licence expires in X days. Consider following up."
**Current behaviour:** No warning shown.
**Fix options:**
- A) Add an orange badge on the driver row in the table if expiry < 30 days away
- B) Show a warning in the form on save

---

### 2.4 Add a driver with an invalid phone number
**Steps:** Enter "abc123" in the phone field. Save.
**Expected:** Should be rejected — "Enter a valid Australian mobile number."
**Current behaviour:** Allowed. "abc123" is saved with +61 prefix prepended.
**Fix options:**
- A) Add regex check: `/^\d{9}$/` (9 digits after stripping leading 0)
- B) The PhoneInput component should handle this

---

### 2.5 Add duplicate driver (same phone number)
**Steps:** Add a driver with phone 0430040000. Then add another driver with the same number.
**Expected:** Should warn — "A driver with this phone number already exists."
**Current behaviour:** Allowed. Both are created.
**Fix options:**
- A) Query Firestore for matching phone before saving

---

### 2.6 Remove a driver assigned to active routes
**Steps:** Try to remove a driver who is currently assigned to one or more active routes.
**Expected:** Should warn — "This driver is assigned to X active routes. Reassign them first."
**Current behaviour:** Driver is deactivated. Routes still reference the old driver ID.
**Fix options:**
- A) Show affected routes in the Remove modal with a prompt to reassign
- B) Hard block removal until routes are reassigned

---

### 2.7 Remove a driver and verify audit log
**Steps:** Remove a driver. Enter a reason. Confirm.
**Expected:** An entry appears in Admin Log with the driver's name, the admin who did it, and the reason.
**Current behaviour:** Works correctly.

---

### 2.8 Reactivate a driver and update their details
**Steps:** Remove a driver. Find them in the inactive list. Click Reactivate. Change their phone number. Save.
**Expected:** Driver is active again with updated details.
**Current behaviour:** Works correctly.

---

### 2.9 Reveal sensitive fields and verify auto-hide
**Steps:** Click on a driver row to reveal phone and address. Wait 5 minutes.
**Expected:** Fields redact automatically after 5 minutes.
**Current behaviour:** Works correctly.

---

### 2.10 Edit driver — leave required field blank
**Steps:** Open Edit for an existing driver. Clear the Full Name field. Try to save.
**Expected:** Form prevents save — "Full Name is required."
**Current behaviour:** HTML5 required attribute blocks submission. Works.

---

## 3. Students

### 3.1 Add a student with no parent
**Steps:** Add a student. In the parent section, clear all parent name fields. Submit.
**Expected:** Student is saved with no parent records. A warning could appear: "No parent linked — this student will have no guardian with app access."
**Current behaviour:** Student is saved with an empty parents array. No warning shown.

---

### 3.2 Add a student with two parents, one with app access off
**Steps:** Add a student. Parent 1: Emma Chen, access ON. Parent 2: James Chen, access OFF. Save.
**Expected:** A parent document is created for Emma only. James is stored in the student's `parents` array but has no login access.
**Current behaviour:** Works correctly.

---

### 3.3 Edit a student and toggle parent app access from off to on
**Steps:** Add a student with Parent 2 access OFF. Then edit the student and turn Parent 2's access ON. Save.
**Expected:** A new parent document should be created for Parent 2 so they can log in.
**Current behaviour:** Not implemented. The parent doc is not created. Parent 2 has `canAccess: true` in the student record but no `/parents` doc.
**Fix options:**
- A) In the edit save handler, check if any parent has `canAccess: true` but no corresponding parent doc. Create it.
- B) Show a note in the UI: "Toggling app access after initial save requires reactivating the student."

---

### 3.4 Add a student with an invalid pickup/dropoff time
**Steps:** Set Scheduled Pick-up Time to "morning". Set Drop-off Time to "afternoon". Save.
**Expected:** Should be rejected — "Use HH:MM AM/PM format."
**Current behaviour:** Saved as-is. Time strings appear in the app and driver view as "morning".
**Fix options:**
- A) Use a time picker input (`type="time"`) instead of free text
- B) Validate with regex on save

---

### 3.5 Assign a student to an inactive route
**Steps:** In the route dropdown, check if inactive routes appear. If they do, assign a student to one.
**Expected:** Only active routes should appear in the dropdown.
**Current behaviour:** All routes are fetched. Inactive routes may appear depending on the fetch filter.

---

### 3.6 Remove a student and verify admin log
**Steps:** Remove a student with a reason. Check Admin Log.
**Expected:** Entry appears with student name, admin name, and reason.
**Current behaviour:** Works correctly.

---

### 3.7 Reactivate a student
**Steps:** Remove a student. Find them in the inactive list. Click Reactivate.
**Expected:** Student appears active again.
**Current behaviour:** Works correctly.

---

### 3.8 Add a student with duplicate name
**Steps:** Add a student named "Liam Chen". Add another student also named "Liam Chen" with a different stop.
**Expected:** Should warn — "A student with this name already exists."
**Current behaviour:** Allowed. Both students are created.
**Fix options:**
- A) Query Firestore for matching name before saving
- B) Show a soft warning only

---

### 3.9 Add a student with no route assigned
**Steps:** Leave the Assigned Route dropdown blank. Fill all other fields. Save.
**Expected:** Student is saved with no route (`routeId: ""`). They will not appear in any trip's student list.
**Current behaviour:** Allowed. No warning is shown.
**Fix options:**
- A) Warn: "This student has no route. They won't be included in any trips."

---

### 3.10 Parent phone — invalid format
**Steps:** In the parent phone field, type "not-a-phone". Save.
**Expected:** Should be rejected — "Enter a valid Australian mobile number."
**Current behaviour:** Saved as "+61not-a-phone".
**Fix options:**
- A) PhoneInput component should validate digit-only input

---

## 4. Dashboard

### 4.1 View today with no trips
**Steps:** Navigate to a date where no routes are scheduled.
**Expected:** Gantt chart shows empty state — "No trips scheduled for this day."
**Current behaviour:** Works correctly (empty state displayed).

---

### 4.2 Navigate to a past date
**Steps:** Use the back arrow on the dashboard date picker to go to yesterday or last week.
**Expected:** Historical trip data loads and is shown read-only.
**Current behaviour:** Works correctly.

---

### 4.3 Navigate to a future date
**Steps:** Go forward to a date next week.
**Expected:** Scheduled (not yet started) trips appear. Completion percentages are 0%.
**Current behaviour:** Works correctly.

---

### 4.4 Check pickup vs. dropoff percentage cards
**Steps:** On a day where 5 out of 10 pickup trips are completed, check the Pickup card.
**Expected:** Shows 50%.
**Current behaviour:** Calculation is based on trip status. Verify against live data.

---

### 4.5 View parent notes on dashboard
**Steps:** Have a parent submit a note from the parent app. Check the dashboard.
**Expected:** Note appears in the Parent Notes section on the relevant date.
**Current behaviour:** Depends on note's `fromDate` and `toDate` matching the selected date.

---

## 5. Activity & Logs

### 5.1 Filter admin log by year and term
**Steps:** Go to Admin Log. Select a year and then a term.
**Expected:** Only entries from that year/term appear.
**Current behaviour:** Works correctly.

---

### 5.2 Expand an admin log entry
**Steps:** Click on a log entry.
**Expected:** Details expand showing actor, target, reason, and before/after fields.
**Current behaviour:** Works correctly.

---

### 5.3 View driver log with no entries
**Steps:** Go to Driver Log. Select a year with no driver activity.
**Expected:** Empty state — "No activity for this period."
**Current behaviour:** Works correctly (empty list shown).

---

### 5.4 Filter student log by student
**Steps:** Go to Student Log. Select a specific student from the dropdown.
**Expected:** Only log entries for that student appear.
**Current behaviour:** Works correctly.

---

### 5.5 Activity log — role filter
**Steps:** Go to Activity Log. Switch filter from "All" to "Driver".
**Expected:** Only driver-role entries are shown.
**Current behaviour:** Works correctly.

---

## 6. Login & Auth

### 6.1 Sign in with a valid school email
**Steps:** Enter the registered school email. Click Send Link.
**Expected:** Redirects to "Check your email" page. Email arrives with magic link.
**Current behaviour:** Works correctly.

---

### 6.2 Sign in with an unregistered email
**Steps:** Enter an email not in the `schools` collection.
**Expected:** Error — "No account found for this email address."
**Current behaviour:** Works correctly.

---

### 6.3 Sign in with an invalid email format
**Steps:** Type "notanemail" and submit.
**Expected:** Browser HTML5 validation blocks submission.
**Current behaviour:** Works correctly.

---

### 6.4 Use magic link after it expires (15 minutes)
**Steps:** Request a sign-in link. Wait 15+ minutes. Click the link.
**Expected:** Redirected to login with error — "This link has expired. Request a new one."
**Current behaviour:** Token expiry is stored in Firestore. Verify the auth callback checks and rejects expired tokens.

---

### 6.5 Request multiple sign-in links in a row
**Steps:** Submit the sign-in form 5 times in 1 minute with the same email.
**Expected:** Rate limiting kicks in after N attempts — "Too many requests. Please wait."
**Current behaviour:** No rate limiting. All requests succeed and multiple valid tokens are created.
**Fix options:**
- A) Add rate limiting on the `/api/admin-signin-link/send` route (e.g. max 3 per 10 minutes per email)

---

## 7. Cross-feature Edge Cases

### 7.1 Driver removed mid-term — what happens to their trips?
**Scenario:** Remove a driver halfway through a term. Their future trips still reference their driver ID.
**Expected:** Admin is warned. Future trips should be reassigned or cancelled.
**Current behaviour:** Not handled. Future trips remain with a deactivated driver ID.

### 7.2 Student removed — still appears in upcoming trips?
**Scenario:** Remove a student. Their studentRecord entries inside future trips still reference them.
**Expected:** Student records in future trips should be flagged or removed.
**Current behaviour:** Not handled. Student still appears in driver's trip list until trips are manually edited.

### 7.3 Admin log — reason left blank
**Steps:** Remove a driver. Leave the reason field blank. Confirm.
**Expected:** Saved as "No reason provided" in the log.
**Current behaviour:** Works correctly.

### 7.4 Large student Excel upload (50+ students)
**Steps:** Upload an Excel file with 50 students. Verify the preview and submit.
**Expected:** Preview shows first 5 with "...and 45 more". All 50 are created on submit.
**Current behaviour:** Preview truncation works. Verify all 50 students appear in Firestore after save.

### 7.5 Session timeout — form in progress
**Steps:** Open the Add Driver form. Leave it open for a long time. Try to save.
**Expected:** If the Firebase auth session has expired, save should fail with a clear error — not silently drop data.
**Current behaviour:** Firebase SDK handles token refresh automatically most of the time. Edge case if refresh fails.

---

*Last updated: October 2026*
