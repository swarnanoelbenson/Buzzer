# Bus Manifest Export Implementation

## Overview
This document describes the implementation of the weekly bus manifest export feature in Excel/CSV format.

## Changes Made

### 1. ProfileView.swift - Fixed Compilation Errors
**Problem**: The User model's `phone` and `busRegistration` properties were being accessed incorrectly.

**Solution**: Updated the code to safely unwrap optional properties:
```swift
// Before (caused errors)
value: authManager.currentUser?.phone.isEmpty == false ? ...

// After (fixed)
value: {
    if let phone = authManager.currentUser?.phone, !phone.isEmpty {
        return phone
    }
    return "Not provided"
}()
```

### 2. Models.swift - Enhanced Data Model

#### Attendee Model
Added new fields to support manifest requirements:
- `grade: String` - Student's grade level
- `scheduledAM: Bool` - Whether student is scheduled for morning pickup
- `scheduledPM: Bool` - Whether student is scheduled for afternoon dropoff
- `notes: String` - Travel notes for the student

#### AttendanceSession Model
Added field to track final safety check:
- `finalCheckTimestamp: Date?` - Time when "No Child Left On Bus" check was performed

### 3. CSVGenerator.swift - New Manifest Export Function

#### New Function: `generateWeeklyManifest()`
Generates a bus manifest in Excel-friendly CSV format with:

**Header Section:**
- Bus manifest title with week date
- Route name (from list name)
- Bus registration (from user signup)
- Driver name (from logged-in user)
- Phone (from user signup)
- Email (from logged-in user)

**Attendance Table:**
- Columns: Name, Grade, Scheduled AM, Scheduled PM, Monday-Friday
- Pickup section: Students in list order (top to bottom)
- Dropoff section: Students in reverse order (bottom to top)
- Time format: '7:05am' (12-hour, lowercase, no spaces)
- Absent students: Shows 'Absent' instead of blank

**Final Check Row:**
- "No Child Left On Bus" with final check timestamp
- Format: '3:35 PM' (12-hour with space and uppercase)

**Travel Notes Section:**
- Student name | Notes
- Only includes students with notes

#### Helper Functions Added:
- `getPickupTimestamp()` - Gets pickup time for specific student on specific date
- `getDropoffTimestamp()` - Gets dropoff time for specific student on specific date
- `escapeCSV()` - Properly escapes CSV values with commas/quotes
- `generateManifestFilename()` - Creates filename: `Bus_Manifest_[ListName]_[DateRange].csv`

#### Time Formatting Extensions:
- `formatTimeShort12Hour()` - Formats as "7:05am" (lowercase, no space)
- `formatTime12Hour()` - Formats as "3:35 PM" (uppercase with space)

### 4. ReportGenerationView.swift - Added Manifest Report Type

#### Changes:
1. Added `@EnvironmentObject var authManager: FirebaseAuthManager` to access user data
2. Added new report type: `weeklyManifest`
3. Updated date selection UI for weekly manifest (single date picker for week start)
4. Updated report generation logic to call new manifest function
5. Updated filename generation to support manifest format
6. Updated session filtering for weekly date range

#### Report Type: Weekly Manifest
- Description: "Export bus manifest with daily attendance for Monday-Friday."
- Date picker: Select Monday as week start date
- Passes current user information to CSV generator
- Generates proper filename format

### 5. DataManager.swift - Updated Session Conversion

Updated `convertToAttendanceSession()` to include the `finalCheckTimestamp` field when converting from Core Data entities.

## File Format Example

```csv
BUS MANIFEST - Week of 2026-03-02

ROUTE,Morning Route
REGISTRATION,ABC-123
DRIVER,john.doe
PHONE,555-0123
EMAIL,john.doe@example.com

Name,Grade,Scheduled AM,Scheduled PM,Monday,Tuesday,Wednesday,Thursday,Friday
PICKUP
John Smith,5,Yes,Yes,7:15am,7:16am,Absent,7:14am,7:15am
Jane Doe,6,Yes,Yes,7:20am,7:21am,7:19am,7:20am,7:22am

DROPOFF
Jane Doe,6,Yes,Yes,3:30pm,3:32pm,3:29pm,3:31pm,3:33pm
John Smith,5,Yes,Yes,3:25pm,3:27pm,Absent,3:26pm,3:28pm

No Child Left On Bus,3:35 PM

TRAVEL NOTES
Student Name,Notes
John Smith,Needs to sit in front due to motion sickness
```

## Filename Format

The manifest is saved with the following naming convention:
```
Bus_Manifest_[ListName]_[StartDate]_to_[EndDate].csv
```

Example:
```
Bus_Manifest_Morning_Route_2026-03-02_to_2026-03-08.csv
```

## Data Sources

1. **User Information**: From `FirebaseAuthManager.currentUser`
   - Bus registration (from signup)
   - Driver name (from email/displayName)
   - Phone (from signup)
   - Email (from account)

2. **Attendance Data**: From Core Data via `DataManager`
   - Pickup/dropoff timestamps
   - Student presence/absence
   - Final check timestamp

3. **Student Information**: From `AttendeeList.attendees`
   - Name
   - Grade
   - Scheduled AM/PM
   - Travel notes
   - List order

## Key Features

1. ✅ Correct pickup/dropoff ordering (forward vs reverse)
2. ✅ Proper time formatting (7:05am vs 3:35 PM)
3. ✅ "Absent" shown for missing students
4. ✅ Final check timestamp included
5. ✅ Travel notes section
6. ✅ User/driver information from signup
7. ✅ Excel-compatible CSV format
8. ✅ Monday-Friday daily columns
9. ✅ Week date range in filename

## Testing Recommendations

1. Test with empty attendance (all students absent)
2. Test with partial attendance (some students absent each day)
3. Test with full attendance (all students present)
4. Test with students who have notes vs no notes
5. Test with different list names (special characters)
6. Test with missing final check timestamp
7. Test CSV import in Excel/Google Sheets
8. Test with different grade levels
9. Test with scheduled AM/PM variations

## Future Enhancements

Consider adding:
- Custom date ranges (not just Monday-Friday)
- Multiple week export
- PDF export option
- Email delivery of manifest
- Print-friendly formatting
- Signature line for driver
- Weather/incident notes section
