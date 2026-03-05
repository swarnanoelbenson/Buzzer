# 🧪 Phase 5 Testing Guide

**Testing authentication, splash screen, logo, and accessibility features**

---

## Test 1: Splash Screen ✅

### Steps:
1. **Close app completely** (swipe up in app switcher)
2. **Launch app** from home screen

### Expected:
- ✅ Splash screen appears immediately
- ✅ Buzzer logo (letter "B") visible
- ✅ Logo animates (scales up, fades in)
- ✅ "Buzzer" text appears after logo
- ✅ "Bus Attendance Tracking" subtitle appears
- ✅ Blue gradient background
- ✅ Duration is 2-3 seconds
- ✅ Smoothly transitions to sign in screen

### With VoiceOver:
1. Enable VoiceOver (Settings > Accessibility > VoiceOver)
2. Launch app

### Expected:
- ✅ VoiceOver announces "Buzzer app is loading"

---

## Test 2: Logo Appearance ✅

### Light Mode:
1. Ensure device is in light mode
2. View splash screen and sign in screen

### Expected:
- ✅ Logo has vibrant blue gradient
- ✅ Letter "B" is white
- ✅ Gradient is bright and clear
- ✅ Shadow visible under logo

### Dark Mode:
1. Switch to dark mode (Settings > Display & Brightness)
2. Force quit and relaunch app

### Expected:
- ✅ Logo has softer, muted blue gradient
- ✅ Letter "B" is still white
- ✅ Gradient is darker, easier on eyes
- ✅ Looks good on dark background

---

## Test 3: Sign Up (New User) ✅

### Steps:
1. On sign in screen, tap **"Sign Up"** link

### Expected:
- ✅ Title changes to "Welcome to Buzzer"
- ✅ Button changes to "Sign Up"
- ✅ "Forgot Password?" link disappears
- ✅ Bottom link changes to "Already have an account? Sign In"

2. **Email field**:
   - Tap email field
   - Enter invalid email: "notanemail"
   - Tap "Sign Up"

### Expected:
- ✅ Error alert: "Please enter a valid email address"

3. Try again with valid email: "driver@bus.com"
4. **Password field**:
   - Tap password field
   - Enter short password: "123"
   - Tap "Sign Up"

### Expected:
- ✅ Error alert: "Password must be at least 4 characters"

5. Try again with valid password: "0000"
6. Tap **"Sign Up"** button (70pt height)

### Expected:
- ✅ Loading indicator appears briefly
- ✅ Account created successfully
- ✅ Navigates to main app (Lists View)
- ✅ User is signed in

---

## Test 4: Sign Out ✅

### Steps:
1. In Lists View, look for sign out icon (top-left)
2. Tap **sign out icon** (arrow with door)

### Expected:
- ✅ Alert appears: "Sign Out"
- ✅ Message: "Are you sure you want to sign out?"
- ✅ Two buttons: "Cancel" and "Sign Out"

3. Tap "Sign Out"

### Expected:
- ✅ Returns to sign in screen
- ✅ Email and password fields are cleared
- ✅ Can't navigate back to app

---

## Test 5: Sign In (Existing User) ✅

### Steps:
1. On sign in screen (should be showing "Sign In" button)
2. Enter email: "driver@bus.com"
3. Enter password: "0000"
4. Tap **"Sign In"** button

### Expected:
- ✅ Loading indicator appears
- ✅ Successfully signs in
- ✅ Navigates to Lists View
- ✅ User is authenticated

---

## Test 6: Forgot Password ✅

### Steps:
1. Sign out if signed in
2. On sign in screen, tap **"Forgot Password?"**

### Expected:
- ✅ Sheet appears with title "Reset Password"
- ✅ Lock rotation icon visible
- ✅ Email field present
- ✅ "Send Reset Instructions" button (70pt height)
- ✅ "Cancel" button in navigation bar

3. Enter email: "driver@bus.com"
4. Tap **"Send Reset Instructions"**

### Expected:
- ✅ Loading indicator appears
- ✅ Success alert: "Password reset instructions have been sent to driver@bus.com"
- ✅ Tapping "OK" dismisses sheet

---

## Test 7: Authentication Persistence ✅

### Steps:
1. Sign in to the app
2. **Force quit** the app (swipe up in app switcher)
3. **Relaunch** the app

### Expected:
- ✅ Splash screen appears
- ✅ After splash, goes directly to Lists View (NOT sign in)
- ✅ User is still signed in
- ✅ Authentication state persisted

---

## Test 8: Accessibility - Touch Targets ✅

### Test with Thumb (One-Handed Use):

1. **Sign In button** (sign in screen):
   - Try to tap with thumb
   - ✅ Easy to hit (70pt height)
   - ✅ No accidental taps on nearby elements

2. **START button** (list detail view):
   - Navigate to a list with attendees
   - Try to tap "Start" button with thumb
   - ✅ Easy to hit (60x70pt minimum)
   - ✅ Icon and text both visible
   - ✅ Label says "Start"

3. **HISTORY button** (list detail view):
   - Try to tap "History" button with thumb
   - ✅ Easy to hit (70pt height)
   - ✅ Icon and text both visible
   - ✅ Label says "History"

4. **Session buttons** (session selection):
   - Tap "Start" to open session selection
   - Try "Start Pick-Up" button
   - Try "Start Drop-Off" button
   - ✅ Both are 70pt height minimum
   - ✅ Easy to tap
   - ✅ No accidental taps

---

## Test 9: Accessibility - Typography ✅

### Check Font Sizes:

Using a ruler or measurement tool:

1. **Sign in screen**:
   - ✅ "Welcome to Buzzer": ~28pt
   - ✅ "Email" label: ~18pt
   - ✅ "Sign In" button: ~22pt

2. **Session selection**:
   - ✅ List name: ~28pt
   - ✅ "15 attendees": ~18pt
   - ✅ "Start Pick-Up" button: ~24pt
   - ✅ "Last pick-up" text: ~16pt

3. **All text throughout app**:
   - ✅ No text smaller than 16pt
   - ✅ Body text is 18pt
   - ✅ Buttons are 20pt+

---

## Test 10: Accessibility - Contrast ✅

### Test Contrast Ratios:

1. **Green buttons** (Start Pick-Up):
   - Background: rgb(0, 153, 0)
   - Text: White
   - ✅ High contrast, easy to read
   - ✅ Visible in bright light
   - ✅ Works in dark mode

2. **Orange buttons** (Start Drop-Off):
   - Background: rgb(230, 128, 0)
   - Text: White
   - ✅ High contrast
   - ✅ Distinguishable from green

3. **Red buttons** (errors, delete):
   - Background: rgb(204, 0, 0)
   - Text: White
   - ✅ High contrast
   - ✅ Clearly indicates danger

4. **Borders**:
   - ✅ All cards have 2pt borders
   - ✅ Borders are visible
   - ✅ High contrast with background

---

## Test 11: Accessibility - Labels ✅

### Check Icon + Text Labels:

1. **List detail toolbar**:
   - ✅ "History" button has clock icon + "History" text
   - ✅ "Start" button has play icon + "Start" text

2. **Session selection**:
   - ✅ "Start Pick-Up" has arrow up icon + text
   - ✅ "Start Drop-Off" has arrow down icon + text

3. **All major actions**:
   - ✅ Icons accompanied by text
   - ✅ No icon-only buttons (except very minor actions)

---

## Test 12: VoiceOver - Complete Workflow ✅

### Enable VoiceOver:
Settings > Accessibility > VoiceOver > On

### Test Full Flow:

1. **Launch app**:
   - ✅ "Buzzer app is loading" announced

2. **Sign in screen**:
   - Swipe right to navigate
   - ✅ "Email address" field announced
   - ✅ Hint: "Enter your email address"
   - ✅ "Password" field announced
   - ✅ Hint: "Enter your password, minimum 4 characters"
   - ✅ "Sign in" button announced
   - ✅ Hint: "Sign in to your account"

3. **Lists view**:
   - ✅ "Buzzer" header announced with "heading" trait
   - ✅ Each list announced with name
   - ✅ Attendee count announced
   - ✅ "Sign out" button announced

4. **List detail**:
   - ✅ "History" button announced
   - ✅ Hint: "View past attendance sessions"
   - ✅ "Start session" button announced
   - ✅ Hint: "Start a new pick-up or drop-off session"
   - ✅ Each attendee name announced

5. **Session selection**:
   - ✅ List name announced as heading
   - ✅ "15 attendees in this list" announced
   - ✅ "Start pick-up session" button announced
   - ✅ Hint: "Begin recording pick-up attendance"
   - ✅ "Last pick-up session was 2 hours ago" announced
   - ✅ "Start drop-off session" button announced
   - ✅ Hint: "Begin recording drop-off attendance"

6. **Complete a full workflow**:
   - Create a list (VoiceOver navigable)
   - Add attendees (VoiceOver navigable)
   - Start session (VoiceOver navigable)
   - Record attendance (VoiceOver navigable)
   - ✅ All steps completable with VoiceOver only

---

## Test 13: Dark/Light Mode ✅

### Light Mode:
1. Set device to light mode
2. Navigate through all screens

### Expected:
- ✅ Logo is vibrant blue
- ✅ All text is readable
- ✅ Buttons have good contrast
- ✅ No white-on-white text
- ✅ Colors are bright and clear

### Dark Mode:
1. Set device to dark mode
2. Navigate through all screens

### Expected:
- ✅ Logo is muted blue (softer)
- ✅ All text is readable
- ✅ Buttons have good contrast
- ✅ No black-on-black text
- ✅ Colors are easier on eyes
- ✅ High contrast maintained

### Toggle Between Modes:
1. While app is open, toggle light/dark mode
2. Navigate through screens

### Expected:
- ✅ Smooth transitions
- ✅ All elements adapt correctly
- ✅ No layout issues
- ✅ Logo updates automatically

---

## Test 14: Error Handling ✅

### Test All Error Scenarios:

1. **Invalid email** (sign up/sign in):
   - Enter "notanemail"
   - ✅ Error: "Please enter a valid email address"

2. **Short password** (sign up):
   - Enter "123"
   - ✅ Error: "Password must be at least 4 characters"

3. **Empty fields** (sign in):
   - Leave email empty
   - ✅ "Sign In" button disabled
   - Fill email, leave password empty
   - ✅ "Sign In" button still disabled

4. **Wrong credentials** (sign in):
   - Enter email: "wrong@email.com"
   - Enter password: "wrongpassword"
   - ✅ Error: "Invalid email or password"

5. **Existing account** (sign up):
   - Try to sign up with existing email
   - ✅ Error: "An account with this email already exists"

---

## Test 15: Accessibility - Date Picker ✅

### Navigate to Date Picker:
1. Session History → Tap share icon → Select "Date Range" report
2. Date picker should appear

### Test Accessibility:
- ✅ Date picker is graphical style (large, easy to see)
- ✅ Label is 18pt+
- ✅ Easy to swipe through months
- ✅ Easy to tap on dates
- ✅ Current selection is clear
- ✅ Can't select future dates

### With VoiceOver:
- ✅ Date picker is announced
- ✅ Hint: "Swipe up or down to change the date"
- ✅ Can navigate dates with VoiceOver gestures

---

## Test 16: Accessibility - 60+ User Simulation ✅

### Simulate Age-Related Conditions:

#### Reduced Vision:
1. Hold phone at arm's length
2. Try to read all text

### Expected:
- ✅ All text readable at arm's length
- ✅ Button labels clear
- ✅ Icons distinguishable
- ✅ High contrast helps readability

#### Limited Dexterity:
1. Use thumb only (one-handed)
2. Try to tap all buttons quickly

### Expected:
- ✅ All buttons easy to hit
- ✅ No accidental taps
- ✅ Generous spacing between elements
- ✅ Large touch targets (70pt)

#### Presbyopia (Age-Related Farsightedness):
1. Remove reading glasses if you wear them
2. Try to read small text

### Expected:
- ✅ All text is 16pt+ minimum
- ✅ No squinting required
- ✅ Readable without glasses

---

## Test 17: Integration Test (Full Workflow) ✅

### Complete User Journey:

1. ✅ Launch app → See splash screen
2. ✅ Sign up with email "newdriver@bus.com", password "0000"
3. ✅ Create a list "Morning Route"
4. ✅ Add 5 attendees
5. ✅ Tap "Start" button (verify 60x70pt)
6. ✅ Tap "Start Pick-Up" (verify 70pt height, 24pt font)
7. ✅ Record attendance for all attendees
8. ✅ Complete session
9. ✅ Tap "History" button (verify 70pt height)
10. ✅ View session details
11. ✅ Export CSV
12. ✅ Return to lists
13. ✅ Sign out
14. ✅ Sign in again (persistence check)
15. ✅ All data still present

---

## Test 18: Performance ✅

### Test Responsiveness:

1. **Authentication**:
   - ✅ Sign in completes in 1-2 seconds
   - ✅ Loading indicators shown
   - ✅ No freezing

2. **Navigation**:
   - ✅ Screen transitions are smooth
   - ✅ No lag when tapping large buttons
   - ✅ Splash screen doesn't overstay

3. **With VoiceOver**:
   - ✅ VoiceOver doesn't slow down app
   - ✅ Gestures are responsive
   - ✅ Announcements are timely

---

## ✅ Complete Test Summary

### Critical Tests (Must Pass):
- [ ] Splash screen works (2-3 seconds)
- [ ] Logo adapts to light/dark mode
- [ ] Can sign up with email/password
- [ ] Can sign in with existing account
- [ ] Authentication persists after relaunch
- [ ] Can sign out
- [ ] START button is 60x70pt
- [ ] HISTORY button is 70pt height
- [ ] All text is 16pt+ minimum
- [ ] High contrast (4.5:1 ratio)
- [ ] Icon + text labels on buttons
- [ ] VoiceOver complete workflow works
- [ ] Dark mode looks good

### Nice-to-Have Tests:
- [ ] Forgot password works
- [ ] Error messages are helpful
- [ ] Animations are smooth
- [ ] Performance is good
- [ ] Date picker is accessible

---

## 🐛 Common Issues & Solutions

### Issue: Splash screen too short/long
**Solution**: Adjust duration in `SplashScreenView.swift` (line with `asyncAfter`)

### Issue: VoiceOver not announcing button
**Solution**: Check `.accessibilityLabel()` is set on button

### Issue: Button too small
**Solution**: Verify `.frame(height: 70)` is applied

### Issue: Text too small
**Solution**: Use `.font(.system(size: 18))` minimum

### Issue: Authentication not persisting
**Solution**: Check UserDefaults is saving correctly in `FirebaseAuthManager`

### Issue: Logo not changing in dark mode
**Solution**: Check `@Environment(\.colorScheme)` is used

---

## 📊 Accessibility Compliance Checklist

### WCAG 2.1 Level AA:
- [ ] Touch targets 44x44pt minimum (✅ 60-70pt)
- [ ] Text 16pt minimum (✅ 18pt+)
- [ ] Contrast 4.5:1 for normal text (✅)
- [ ] Contrast 3:1 for large text (✅)
- [ ] All interactive elements have labels (✅)
- [ ] Proper heading structure (✅)
- [ ] Color not sole indicator (✅ icons + text)

### Age 60+ Specific:
- [ ] 70pt button heights (✅)
- [ ] 20pt+ button text (✅ 22-24pt)
- [ ] Icon + text labels (✅)
- [ ] High contrast colors (✅)
- [ ] Large touch spacing (✅)

---

**If all tests pass, Phase 5 is ready for production use! 🎉**

Your app is now fully accessible and ready for drivers aged 60+!
