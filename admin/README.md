# BusMate — WAC (Web Admin Console)

**Project name:** WAC
**Purpose:** Web portal for school administrators. Manage drivers, students, and schedules. View logs and activity.
**Deployed on:** Vercel — https://busmate-admin.vercel.app
**Language:** TypeScript, React 19
**Framework:** Next.js 15 (App Router)

---

## 1. Directory Structure

```
admin/
├── app/                        Next.js App Router pages and API routes
│   ├── api/                    Server-side API endpoints
│   │   ├── admin-otp/
│   │   │   ├── send/           POST — send OTP email to admin
│   │   │   └── verify/         POST — verify OTP, return Firebase custom token
│   │   └── notify-login/       POST — send login alert email to admin
│   ├── page.tsx                Dashboard — Gantt chart of daily trips
│   ├── login/                  Admin login page (email + OTP)
│   ├── auth-callback/          Firebase auth redirect handler
│   ├── signup/                 New admin registration
│   ├── check-email/            Email verification prompt
│   ├── drivers/                Driver management pages
│   │   ├── page.tsx            List all drivers
│   │   ├── add/                Add a new driver
│   │   ├── modify/             Edit a driver
│   │   └── remove/             Remove a driver
│   ├── students/               Student management pages
│   │   ├── page.tsx            List all students
│   │   ├── add/                Add a new student
│   │   ├── modify/             Edit a student
│   │   └── remove/             Remove a student
│   ├── schedule/               Route and schedule management
│   │   ├── page.tsx            View all routes and trips
│   │   ├── add/                Create a new route (with .xlsx upload)
│   │   ├── modify/             Edit a route
│   │   └── remove/             Remove a route
│   ├── logs/                   Activity log viewers
│   │   ├── admin/              Logs for admin actions
│   │   ├── driver/             Logs for driver actions
│   │   ├── student/            Logs for student actions
│   │   └── route/              Logs for route changes
│   ├── activity/               Activity dashboard
│   └── layout.tsx              Root layout with navigation
├── components/                 Reusable React components
├── lib/
│   ├── firebase.ts             Firebase client config (Firestore + Auth)
│   ├── auth-context.tsx        Auth state provider (React context)
│   ├── types.ts                TypeScript interfaces for all data models
│   └── utils.ts                Helper functions
├── hooks/                      Custom React hooks
├── public/                     Static assets
├── .env.local                  Environment variables (do not commit)
├── next.config.js              Next.js configuration
├── tailwind.config.ts          Tailwind CSS configuration
└── tsconfig.json               TypeScript configuration
```

---

## 2. Languages Used

| Language   | Purpose                             |
|------------|-------------------------------------|
| TypeScript | All application and API route code  |
| React 19   | UI rendering                        |
| CSS        | Styling via Tailwind CSS            |

---

## 3. Libraries Used

| Library          | Version | Purpose                                              |
|------------------|---------|------------------------------------------------------|
| Next.js          | 15      | Full-stack React framework with App Router           |
| Tailwind CSS     | 3.4     | Utility-first CSS styling                            |
| Firebase JS SDK  | 11      | Firestore database and Auth (client-side)            |
| firebase-admin   | 12      | Firebase Admin SDK. Creates custom tokens (server).  |
| Resend           | latest  | Sends OTP and login notification emails              |
| XLSX             | 0.18.5  | Parses uploaded .xlsx files. Generates .xlsx exports.|
| TypeScript       | 5       | Static typing                                        |

---

## 4. Pages

| Route              | File                        | Purpose                                             |
|--------------------|-----------------------------|-----------------------------------------------------|
| `/`                | `app/page.tsx`              | Dashboard. Shows Gantt chart of all scheduled trips.|
| `/login`           | `app/login/page.tsx`        | Admin login. Enter email, then enter OTP.           |
| `/signup`          | `app/signup/page.tsx`       | Register a new school admin account.                |
| `/check-email`     | `app/check-email/page.tsx`  | Tell user to check their email for OTP.             |
| `/auth-callback`   | `app/auth-callback/page.tsx`| Handle Firebase auth redirect after login.          |
| `/drivers`         | `app/drivers/page.tsx`      | List all drivers for this school.                   |
| `/drivers/add`     | `app/drivers/add/page.tsx`  | Form to add a new driver.                           |
| `/drivers/modify`  | `app/drivers/modify/page.tsx` | Form to edit a driver's details.                  |
| `/drivers/remove`  | `app/drivers/remove/page.tsx` | Confirm and remove a driver.                      |
| `/students`        | `app/students/page.tsx`     | List all students.                                  |
| `/students/add`    | `app/students/add/page.tsx` | Form to add a new student.                          |
| `/students/modify` | `app/students/modify/page.tsx` | Form to edit a student's details.                |
| `/students/remove` | `app/students/remove/page.tsx` | Confirm and remove a student.                    |
| `/schedule`        | `app/schedule/page.tsx`     | View and create routes. Upload student .xlsx. Substitute drivers for a date range. |
| `/schedule/add`    | `app/schedule/add/page.tsx` | Dedicated full-page route creation form.            |
| `/schedule/modify` | `app/schedule/modify/page.tsx` | Edit a route.                                    |
| `/schedule/remove` | `app/schedule/remove/page.tsx` | Remove a route and its trips.                    |
| `/logs/admin`      | `app/logs/admin/page.tsx`   | View admin activity log.                            |
| `/logs/driver`     | `app/logs/driver/page.tsx`  | View driver activity log.                           |
| `/logs/student`    | `app/logs/student/page.tsx` | View student activity log.                          |
| `/logs/route`      | `app/logs/route/page.tsx`   | View route-level activity log.                      |
| `/activity`        | `app/activity/page.tsx`     | Combined activity dashboard.                        |

---

## 5. API Routes

### `POST /api/admin-otp/send`
**File:** `app/api/admin-otp/send/route.ts`

This route sends a 6-digit OTP to an admin's email address.

**Steps:**
1. Receive `{ email }` from the request body.
2. Look up the email in the Firestore `schools` collection.
3. If found, generate a cryptographically secure 6-digit OTP using `crypto.randomInt`.
4. Store the OTP in Firestore `adminOtps/{email}` with a 10-minute expiry timestamp.
5. Send the OTP to the admin's email via Resend.
6. Return `{ sent: true, schoolName }`.

**Used by:** The iOS app `AdminLoginView.swift` only.

---

### `POST /api/admin-otp/verify`
**File:** `app/api/admin-otp/verify/route.ts`

This route verifies a submitted OTP and returns a Firebase custom token.

**Steps:**
1. Receive `{ email, otp }` from the request body.
2. Fetch the stored OTP document from Firestore `adminOtps/{email}`.
3. Check that the OTP has not expired.
4. Check that the OTP matches.
5. Delete the OTP document from Firestore.
6. Look up the admin's UID in the `schools` collection.
7. Create a Firebase custom token using `firebase-admin`.
8. Return `{ customToken, schoolName, adminName, adminUid }`.

**Used by:** The iOS app `AdminLoginView.swift` only.

---

### `POST /api/admin-signin-link/send`
**File:** `app/api/admin-signin-link/send/route.ts`

This route sends a magic sign-in link to an admin's email address via Resend.

**Steps:**
1. Receive `{ email, origin, pendingSignup? }` from the request body.
2. For login: verify the email exists in the `schools` collection.
3. Generate a cryptographically secure 64-character hex token using `crypto.randomBytes`.
4. Store the token in Firestore `adminSigninTokens/{token}` with a 15-minute expiry. Include `pendingSignup` data if this is a new signup.
5. Send a styled HTML email via Resend with a button linking to `{origin}/auth-callback?token=...&email=...`.
6. Return `{ sent: true }`.

**Used by:** `app/login/page.tsx`, `app/signup/page.tsx`, and `app/check-email/page.tsx`.

---

### `POST /api/admin-signin-link/verify`
**File:** `app/api/admin-signin-link/verify/route.ts`

This route validates a magic link token and returns a Firebase custom token.

**Steps:**
1. Receive `{ token, email }` from the request body.
2. Fetch the token document from Firestore `adminSigninTokens/{token}`.
3. Check that the token has not expired.
4. Check that the email matches the token.
5. Delete the token document (single-use).
6. For signup: create the Firebase Auth user and write the school document to Firestore.
7. For login: look up the admin's UID in the `schools` collection.
8. Create a Firebase custom token using `firebase-admin`.
9. Return `{ customToken, schoolName, adminName, adminUid, isSignup }`.

**Used by:** `app/auth-callback/page.tsx`.

---

### `POST /api/notify-login`
**File:** `app/api/notify-login/route.ts`

This route sends a login alert email to the admin.

**Steps:**
1. Receive `{ email, displayName, schoolName, timestamp }`.
2. Send a styled HTML email via Resend.
3. Return `{ sent: true }`.

**Used by:** The WAC after successful login.

---

## 6. Key Files and Functions

### `lib/firebase.ts`
Initialises the Firebase client SDK.
Exports `db` (Firestore instance) and `auth` (Firebase Auth instance).
All Firestore reads and writes use these exports.

### `lib/auth-context.tsx`
React context provider for authentication state.
Wraps the app and makes the current admin user available to all pages.
Listens to Firebase Auth state changes.
Redirects unauthenticated users to `/login`.

### `lib/types.ts`
TypeScript interfaces for all data models:
`Driver`, `Student`, `Parent`, `Route`, `Trip`, `StudentTripRecord`, `ActivityLog`, `PassengerNote`.
These match the Firestore document structure exactly.

Key fields on `Student`: `stopAddressAM`, `stopAddressPM` (separate morning and afternoon stops), `orderAM`, `orderPM` (stop sequence numbers for the driver app).
`StudentTripRecord` (embedded in each `Trip.studentRecords` array) mirrors `stopAddressAM`, `stopAddressPM`, `orderAM`, and `orderPM` as a snapshot at trip creation time.

### `app/schedule/page.tsx`
The main schedule management page.
Lists all existing routes.
Handles creation of a new route via a slide-out form.

**Key functions in this file:**

`handleFile(e)` — Parses an uploaded .xlsx file.
Reads 12 columns: Student Name, Grade, Order AM, Scheduled AM, Order PM, Scheduled PM, STOP Location AM, STOP Location PM, Parent 1 Phone, Parent 1 Name, Student Phone, Relationship.
Stores the parsed rows in the `preview` state.

`handleSubmit(e)` — Saves a new route to Firestore.
Creates one student document per row in the preview.
Creates one route document with all student IDs.
Creates two trip documents per scheduled day (one pickup, one dropoff).
All writes use a Firestore batch for atomicity.

`downloadTemplate()` — Generates and downloads a blank .xlsx template file.
Uses SheetJS to build the file in the browser.
The template contains the correct 12 column headers.

### `app/layout.tsx`
Root layout for all pages.
Wraps all content with the `AuthContext` provider.
Renders the navigation sidebar.

---

## 7. .xlsx Upload Format

The schedule creation form accepts a `.xlsx` file with exactly these columns in this order:

| Column | Header            | Field in Firestore                   |
|--------|-------------------|--------------------------------------|
| A (0)  | Student Name      | `student.name`                       |
| B (1)  | Grade             | `student.grade`                      |
| C (2)  | Order AM          | `student.orderAM`                    |
| D (3)  | Scheduled AM      | `student.scheduledPickupTime`        |
| E (4)  | Order PM          | `student.orderPM`                    |
| F (5)  | Scheduled PM      | `student.scheduledDropoffTime`       |
| G (6)  | STOP Location AM  | `student.stopAddressAM`              |
| H (7)  | STOP Location PM  | `student.stopAddressPM`              |
| I (8)  | Parent 1 Phone    | `student.parents[0].phone`           |
| J (9)  | Parent 1 Name     | `student.parents[0].name`            |
| K (10) | Student Phone     | `student.phone`                      |
| L (11) | Relationship      | `student.parents[0].relationship`    |

Row 1 must be the header row. Data starts from row 2.
Use the "Download Template" button in the schedule form to get a pre-formatted file.

---

## 8. Firestore Collections

| Collection          | Purpose                                                          |
|---------------------|------------------------------------------------------------------|
| `schools`           | One document per school. Contains admin email and UID.           |
| `adminOtps`         | Temporary OTP storage. Documents expire after 10 minutes. iOS only. |
| `adminSigninTokens` | Temporary magic link token storage. Documents expire after 15 minutes. WAC only. |
| `drivers`           | One document per driver. Contains profile and FCM token.         |
| `students`          | One document per student. Contains route and stop info.          |
| `parents`           | One document per parent. Contains children IDs and FCM token.    |
| `routes`            | One document per bus route. Contains driver and student IDs.     |
| `trips`             | One document per trip (pickup or dropoff) per day.               |
| `passengerNotes`    | Notes created by parents for drivers.                            |
| `activityLog`       | Audit trail of all user actions.                                 |

---

## 9. Data Flow

### Admin Login Flow (WAC web)
```
Admin enters email on /login
       │
       ▼
POST /api/admin-signin-link/send
   Checks schools collection
   Generates 64-char hex token (crypto.randomBytes)
   Stores token in adminSigninTokens with 15-min expiry
   Sends magic link email via Resend
       │
       ▼
Admin clicks link → /auth-callback?token=...&email=...
       │
       ▼
POST /api/admin-signin-link/verify
   Checks token expiry and email match
   Deletes token from Firestore (single-use)
   Creates Firebase custom token
       │
       ▼
WAC signs in with custom token
Firebase resolves user → schools collection
Admin sees dashboard
```

### Admin Signup Flow (WAC web)
```
Admin fills school name, full name, email on /signup
       │
       ▼
Duplicate checks on schools collection
       │
       ▼
POST /api/admin-signin-link/send  (with pendingSignup payload)
   Stores token + pendingSignup data in adminSigninTokens
   Sends magic link email via Resend
       │
       ▼
Admin clicks link → /auth-callback?token=...&email=...
       │
       ▼
POST /api/admin-signin-link/verify
   Validates token
   Creates Firebase Auth user
   Writes school document to Firestore
   Creates Firebase custom token
       │
       ▼
WAC signs in with custom token → Admin sees dashboard
```

### Admin Login Flow (iOS app)
```
Admin enters email in AdminLoginView.swift
       │
       ▼
POST /api/admin-otp/send
   Checks schools collection
   Generates 6-digit OTP (crypto.randomInt)
   Stores OTP in adminOtps with 10-min expiry
   Sends OTP email via Resend
       │
       ▼
Admin enters OTP in AdminLoginView.swift
       │
       ▼
POST /api/admin-otp/verify
   Checks OTP expiry and match
   Deletes OTP from Firestore
   Creates Firebase custom token
       │
       ▼
authManager.signInWithCustomToken() signs in on the device
```

### Schedule Creation Flow
```
Admin fills route form (name, driver, term, dates, days)
Admin uploads .xlsx file or manually adds students
Admin clicks Save
       │
       ▼
handleSubmit() runs a Firestore batch write:
   ├── Creates one student document per .xlsx row
   ├── Creates one route document with all student IDs
   └── Creates 2 trips (pickup + dropoff) per scheduled day
```

---

## 10. External Services and APIs

### Firebase (Firestore + Auth)
- **Purpose:** Primary database and authentication.
- **Client SDK:** `firebase` v11 — used in all pages for Firestore reads and writes.
- **Admin SDK:** `firebase-admin` v12 — used only in API routes to create custom tokens.
- **Project ID:** `busmate-de66c`

### Resend
- **Purpose:** Sends OTP codes, magic sign-in links, and login alert emails.
- **API Key variable:** `RESEND_API_KEY`
- **Used in:** `/api/admin-otp/send`, `/api/admin-signin-link/send`, and `/api/notify-login`

### SheetJS (XLSX)
- **Purpose:** Parse uploaded .xlsx files. Generate downloadable .xlsx templates.
- **Used in:** `app/schedule/page.tsx`

---

## 11. Environment Variables

Store these in `.env.local` locally.
Set them in the Vercel dashboard for production.
Do not commit `.env.local` to git.

| Variable                          | Purpose                                              |
|-----------------------------------|------------------------------------------------------|
| `NEXT_PUBLIC_FIREBASE_API_KEY`    | Firebase client API key                              |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`| Firebase Auth domain                                 |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID` | Firebase project ID                                  |
| `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET` | Firebase Storage bucket                          |
| `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID` | Firebase Cloud Messaging sender ID          |
| `NEXT_PUBLIC_FIREBASE_APP_ID`     | Firebase app ID                                      |
| `RESEND_API_KEY`                  | Resend API key for sending emails                    |
| `FIREBASE_ADMIN_SERVICE_ACCOUNT`  | Stringified Firebase service account JSON. Required for `/api/admin-otp/verify`. Download from Firebase Console → Project Settings → Service Accounts → Generate new private key. |

---

## 12. How to Run Locally

```bash
cd admin
npm install
npm run dev
```

The portal runs at `http://localhost:3000` by default.

**Note:** You must fill in `FIREBASE_ADMIN_SERVICE_ACCOUNT` in `.env.local` before the OTP verify endpoint works.
Download the service account JSON from Firebase Console → Project Settings → Service Accounts.
Stringify it and paste it as the value: `FIREBASE_ADMIN_SERVICE_ACCOUNT='{"type":"service_account",...}'`

---

## 13. How to Deploy to Vercel

Next.js 15 has a known issue on Vercel's build servers where it tries to exec a child Node.js process
using `process.execPath`, which resolves to a path that doesn't exist on Vercel (`/vercel/path0/node`).
The workaround is to build locally and upload the pre-built output.

### First-time setup

```bash
# Install Vercel CLI globally
sudo npm i -g vercel

# Link the project (run once)
cd admin
vercel

# Add all environment variables to production
vercel env add FIREBASE_ADMIN_SERVICE_ACCOUNT production   # paste the service account JSON
vercel env add RESEND_API_KEY production
vercel env add NEXT_PUBLIC_FIREBASE_API_KEY production --type config --value "..."
vercel env add NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN production --type config --value "..."
vercel env add NEXT_PUBLIC_FIREBASE_PROJECT_ID production --type config --value "..."
vercel env add NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET production --type config --value "..."
vercel env add NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID production --type config --value "..."
vercel env add NEXT_PUBLIC_FIREBASE_APP_ID production --type config --value "..."
```

### Deploy

```bash
# Pull production settings locally
vercel pull --yes --environment production

# Build locally (produces .vercel/output)
vercel build --yes --target production

# Upload the pre-built output — bypasses the remote build
vercel deploy --prebuilt --prod
```

The production URL is **https://busmate-admin.vercel.app**.
