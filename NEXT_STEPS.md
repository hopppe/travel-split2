# Next Steps for Push Notification Implementation

**Status:** iOS infrastructure complete ✅ | Backend & Configuration pending ⏳

---

## What Has Been Completed ✅

### iOS App Infrastructure
- ✅ **NotificationService.swift** created with full FCM integration
- ✅ **AppDelegate.swift** updated with FCM delegates and APNs registration
- ✅ **FirebaseService.swift** updated with FCM token management methods
- ✅ **travel_splitApp.swift** updated to request notification permissions on launch
- ✅ **Localization strings** added for all notification types (English & Arabic)
- ✅ **Firestore security rules** updated to allow FCM token writes

### Documentation
- ✅ **NOTIFICATION_IMPLEMENTATION.md** - Complete implementation plan and progress tracker
- ✅ **CLOUD_FUNCTIONS_SETUP.md** - Full Cloud Functions code and deployment guide

---

## What Still Needs to Be Done ⏳

### 1. Add Firebase Messaging SDK ⚠️ **CRITICAL - DO THIS FIRST**

The app currently references `FirebaseMessaging` but the SDK isn't installed yet.

**Option A: Using Xcode (Recommended)**
1. Open `EquiSplit.xcodeproj` in Xcode
2. Click on the project in the navigator
3. Select the "travel split" target
4. Go to "General" tab → "Frameworks, Libraries, and Embedded Content"
5. Click the "+" button
6. Select "Add Package Dependency"
7. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
8. Version: Select "10.0.0" or higher
9. Click "Add Package"
10. Select these products:
    - **FirebaseMessaging** ✅
    - FirebaseCore (already added)
    - FirebaseFirestore (already added)
    - FirebaseAuth (already added)
11. Click "Add Package"

**Option B: Manual Package.swift (if using SPM directly)**
Add to your `Package.swift` dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
],
targets: [
    .target(
        name: "travel split",
        dependencies: [
            .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
            .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")  // ADD THIS
        ]
    )
]
```

---

### 2. Enable Push Notifications in Xcode ⚠️ **CRITICAL**

1. Open `EquiSplit.xcodeproj` in Xcode
2. Select the project in navigator → Select "travel split" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add **"Push Notifications"**
6. Click "+ Capability" again
7. Add **"Background Modes"**
8. Under Background Modes, check:
   - ✅ **Remote notifications**

---

### 3. Apple Developer Account - Create APNs Key 🍎 **MANUAL REQUIRED**

You need to generate an APNs authentication key from your Apple Developer account.

**Steps:**
1. Go to: https://developer.apple.com/account/resources/authkeys/list
2. Click the "+" button to create a new key
3. Name it: `EquiSplit Push Notifications`
4. Check: ✅ **Apple Push Notifications service (APNs)**
5. Click "Continue"
6. Click "Register"
7. Click "Download" - You'll get a `.p8` file
8. **IMPORTANT:** Save this file securely - you can only download it once!
9. **Note the Key ID** (e.g., `AB12CD34EF`) - you'll need this
10. **Note your Team ID** (shown in top right, e.g., `XYZ1234567`) - you'll need this

---

### 4. Firebase Console - Upload APNs Key 🔥 **MANUAL REQUIRED**

1. Go to: https://console.firebase.google.com
2. Select your EquiSplit project
3. Click the gear icon (⚙️) → "Project Settings"
4. Click on the "Cloud Messaging" tab
5. Scroll down to "Apple app configuration"
6. Under "APNs Authentication Key", click "Upload"
7. Upload the `.p8` file from step 3
8. Enter the **Key ID** from step 3
9. Enter your **Team ID** from step 3
10. Click "Upload"

✅ Done! Firebase can now send push notifications to your iOS app.

---

### 5. Deploy Firestore Security Rules 🔐

The rules have been updated in `firestore.rules` but need to be deployed.

**Option A: Using Firebase CLI**
```bash
cd "/Users/ethanhoppe/Desktop/travel split"
firebase deploy --only firestore:rules
```

**Option B: Using Firebase Console**
1. Go to: https://console.firebase.google.com
2. Select your project
3. Go to "Firestore Database" → "Rules" tab
4. Copy the contents of `firestore.rules` file
5. Paste into the console
6. Click "Publish"

---

### 6. Deploy Cloud Functions 🚀 **READY TO DEPLOY**

✅ **All Cloud Functions code has been created in the `functions/` directory!**
✅ **Dependencies installed successfully!**

The Cloud Functions are ready to deploy. You just need to install Firebase CLI and deploy.

**Prerequisites:**
```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Login to Firebase (if not already logged in)
firebase login
```

**Deploy Cloud Functions:**
```bash
# Navigate to project directory
cd "/Users/ethanhoppe/Desktop/travel split"

# Deploy the functions
firebase deploy --only functions
```

That's it! The functions will be deployed to your Firebase project.

**Verify Deployment:**
```bash
# Check deployed functions
firebase functions:list

# View logs
firebase functions:log --only onTripChanged
```

**What was created:**
- ✅ `functions/index.js` - Main entry point with trip change detection
- ✅ `functions/notifications/expenseNotifications.js` - Expense notification handlers
- ✅ `functions/notifications/participantNotifications.js` - Participant notification handlers
- ✅ `functions/notifications/balanceNotifications.js` - Balance notification handlers
- ✅ `functions/utils/notificationHelpers.js` - FCM sending utilities
- ✅ `functions/utils/localization.js` - English/Arabic message templates
- ✅ `functions/package.json` - Dependencies configuration
- ✅ `functions/.gitignore` - Git ignore rules
- ✅ All npm dependencies installed (524 packages)

---

### 7. Test Notifications 🧪

Once everything is deployed, test on a **physical iOS device** (push notifications don't work on simulator).

**Testing Checklist:**

#### Initial Setup
- [ ] Build app on physical device
- [ ] Grant notification permission when prompted
- [ ] Check logs to see if FCM token is received
- [ ] Verify FCM token is saved in Firestore `/users/{userId}/fcmToken`

#### Test Cases
- [ ] **Expense Added:** Add expense → Other participants get notification
- [ ] **Expense Updated:** Update expense → All participants get notification
- [ ] **Expense Deleted:** Delete expense → All participants get notification
- [ ] **Payment:** Record payment → Both users get notification
- [ ] **Participant Joined:** User joins trip → Existing participants get notification
- [ ] **Participant Left:** User leaves trip → Remaining participants get notification
- [ ] **Balance Settled:** Make payment that zeroes balance → User gets notification
- [ ] **Participant Claimed:** Unclaimed participant claims account → Creator gets notification

#### App States
- [ ] **Foreground:** Notification appears as banner at top
- [ ] **Background:** Notification appears in notification center
- [ ] **Killed:** Notification appears, tapping opens app to trip

#### Localization
- [ ] Set app to English → Notifications in English
- [ ] Set app to Arabic → Notifications in Arabic (RTL)

#### Notification Tap
- [ ] Tap notification → App opens to correct trip

---

## Troubleshooting 🔧

### Issue: Notifications not received at all

**Check:**
1. Notification permission granted? (Settings → EquiSplit → Notifications)
2. FCM token exists in Firestore? Check `/users/{userId}/fcmToken`
3. APNs key uploaded to Firebase Console?
4. Cloud Functions deployed? Run: `firebase functions:list`
5. Check Cloud Function logs: `firebase functions:log`

**Solution:**
- If no FCM token: Check AppDelegate setup, restart app
- If no Cloud Functions: Deploy using step 6 above
- If APNs not configured: Complete step 4 above

---

### Issue: Build errors about FirebaseMessaging

**Error:**
```
Cannot find 'Messaging' in scope
```

**Solution:**
Complete step 1 - Add Firebase Messaging SDK to project

---

### Issue: Notifications received but in wrong language

**Check:**
1. User's language preference in Firestore `/users/{userId}/language`
2. Localization strings in `en.lproj/Localizable.strings` and `ar.lproj/Localizable.strings`

**Solution:**
- Verify Cloud Functions `utils/localization.js` has both languages
- Check user document has `language` field set correctly

---

### Issue: App crashes when notification received

**Check:**
- Console logs for error messages
- Verify NotificationService is properly registered in AppDelegate

**Solution:**
- Ensure all notification handlers are implemented in NotificationService
- Check that `userInfo` dictionary has expected keys

---

## Firebase Cloud Functions Code Summary

The Cloud Functions live in the `functions/` directory and work like this:

### Main Function
**`onTripChanged`** - Triggers when any trip document in Firestore is updated

### What it does:
1. Compares `before` and `after` trip data
2. Detects changes:
   - New expenses
   - Updated expenses
   - Deleted expenses
   - Participants joined
   - Participants left
   - Participants claimed
   - Balances settled
3. Calls appropriate notification handlers
4. Sends push notifications via FCM

### Notification Flow:
```
User adds expense → Firestore updated → Cloud Function triggered
→ Function detects expense added → Gets participant FCM tokens
→ Sends notification via FCM → APNs delivers to devices
```

---

## Current File Status

### ✅ Created/Modified Files (iOS)
- `Services/NotificationService.swift` - NEW
- `AppDelegate.swift` - MODIFIED (added FCM)
- `Services/FirebaseService.swift` - MODIFIED (added FCM token methods)
- `travel_splitApp.swift` - MODIFIED (added permission request)
- `en.lproj/Localizable.strings` - MODIFIED (added notification strings)
- `ar.lproj/Localizable.strings` - MODIFIED (added notification strings)
- `firestore.rules` - MODIFIED (added FCM token rules)

### ✅ Created Files (Backend - Ready to Deploy)
All Cloud Functions code has been created and is ready in the `functions/` directory:
- `functions/index.js` ✅
- `functions/notifications/expenseNotifications.js` ✅
- `functions/notifications/participantNotifications.js` ✅
- `functions/notifications/balanceNotifications.js` ✅
- `functions/utils/notificationHelpers.js` ✅
- `functions/utils/localization.js` ✅
- `functions/package.json` ✅
- `functions/.gitignore` ✅
- `functions/node_modules/` ✅ (524 packages installed)

---

## Quick Start Checklist

If you're resuming this project, do these in order:

1. [ ] Add FirebaseMessaging SDK to Xcode project (Step 1)
2. [ ] Enable Push Notifications capability in Xcode (Step 2)
3. [ ] Generate APNs key from Apple Developer account (Step 3)
4. [ ] Upload APNs key to Firebase Console (Step 4)
5. [ ] Deploy Firestore security rules (Step 5)
6. [ ] Set up and deploy Cloud Functions (Step 6)
7. [ ] Test on physical device (Step 7)

**Estimated Time:** 2-3 hours (including Firebase setup and testing)

---

## Resources

- **Firebase Console:** https://console.firebase.google.com
- **Apple Developer:** https://developer.apple.com/account
- **Firebase Cloud Messaging Docs:** https://firebase.google.com/docs/cloud-messaging/ios/client
- **Firebase Cloud Functions Docs:** https://firebase.google.com/docs/functions
- **Implementation Plan:** `NOTIFICATION_IMPLEMENTATION.md`
- **Cloud Functions Code:** `CLOUD_FUNCTIONS_SETUP.md`

---

## Notes for Future Development

### Adding New Notification Types
1. Add notification case to `NotificationService.swift`
2. Add localized strings to `en.lproj` and `ar.lproj`
3. Add handler function in appropriate Cloud Function file
4. Add detection logic in `index.js` `onTripChanged` function
5. Test end-to-end

### Notification Preferences (Future Enhancement)
Currently: Simple on/off toggle
Future: Could add per-notification-type preferences:
- Expense notifications
- Payment notifications
- Participant notifications
- Balance notifications

Would require:
- UI update in settings
- Firestore schema update
- Cloud Function logic update to check preferences

---

## Contact & Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Firebase Console logs
3. Check `firebase functions:log` for Cloud Function errors
4. Verify all steps completed in checklist

---

**Last Updated:** 2025-10-23
**Status:** iOS Complete | Backend Pending
**Next Action:** Add FirebaseMessaging SDK to Xcode
