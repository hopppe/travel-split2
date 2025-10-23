# Push Notification Implementation Plan & Progress

**Project:** EquiSplit - Expense Splitting App
**Feature:** Firebase Cloud Messaging Push Notifications
**Date Started:** 2025-10-23
**Status:** In Progress

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Notification Types](#notification-types)
- [Implementation Phases](#implementation-phases)
- [Progress Tracking](#progress-tracking)
- [Manual Setup Required](#manual-setup-required)
- [Testing Checklist](#testing-checklist)

---

## Overview

Implementing push notifications for EquiSplit using Firebase Cloud Messaging (FCM) to notify users about:
- Expense additions, updates, deletions
- Payments between users
- Balance settlements
- Participants joining/leaving/claiming accounts
- Being added to trips

### Key Decisions
- ✅ Using Firebase Cloud Messaging (wrapper around APNs)
- ✅ Simple on/off toggle (no per-notification-type preferences)
- ✅ No quiet hours
- ✅ Default system sounds and badges
- ✅ Notifications in user's language (English/Arabic)
- ❌ NO notification for debt created/changed (handled by expense notifications)
- ❌ NO notification for currency changes

---

## Architecture

```
Firestore Change (Trip Updated)
         ↓
Cloud Function (Detects what changed)
         ↓
FCM (Firebase Cloud Messaging)
         ↓
APNs (Apple Push Notification Service)
         ↓
User's iPhone
```

### Data Flow
1. User A adds expense → Firestore `/trips/{tripId}` updated
2. Cloud Function `onTripChanged` triggers
3. Function compares old vs new trip data
4. Function determines notification type and recipients
5. Function sends notification via FCM
6. FCM routes to APNs (iOS)
7. User B receives notification

---

## Notification Types

| Event | Trigger Location | Recipients | Example Message |
|-------|-----------------|------------|-----------------|
| **Expense Added** | `TripExpenseManager.swift:80` | All participants except payer | "John added Dinner - $45.00 in Trip to Paris" |
| **Expense Updated** | `TripExpenseManager.swift:147` | All participants | "John updated Dinner to $50.00 in Trip to Paris" |
| **Expense Deleted** | `TripExpenseManager.swift:160` | All participants except deleter | "John deleted Dinner in Trip to Paris" |
| **Payment Recorded** | `TripExpenseManager.swift:198` | Payer & recipient | "John paid you $20.00 in Trip to Paris" |
| **Balance Settled** | `TripBalanceCalculator.swift:76-80` | User whose balance settled | "Your balance is settled in Trip to Paris ✓" |
| **Participant Joined** | `TripParticipantManager.swift:33` | All existing participants | "Sarah joined Trip to Paris" |
| **Participant Left** | `TripViewModel.swift:455` | All remaining participants | "John left Trip to Paris" |
| **Participant Claimed** | `TripParticipantManager.swift:246` | Creator of unclaimed participant | "Sarah claimed their account in Trip to Paris" |
| **Added to Trip** | `TripParticipantManager.swift:96` | Newly added participant | "You were added to Trip to Paris by John" |

**Total Notification Types:** 9

---

## Implementation Phases

### Phase 1: iOS App Infrastructure ⏳

#### Files to Create
- [ ] `Services/NotificationService.swift` (~200 lines)
- [ ] `ViewModels/TripNotificationManager.swift` (~150 lines)
- [ ] `Views/Settings/NotificationPreferencesView.swift` (~100 lines)

#### Files to Modify
- [ ] `AppDelegate.swift` - Add FCM delegation
- [ ] `TripExpenseManager.swift` - Add notification triggers (3 locations)
- [ ] `TripParticipantManager.swift` - Add notification triggers (3 locations)
- [ ] `TripBalanceCalculator.swift` - Add notification trigger (1 location)
- [ ] `TripViewModel.swift` - Integrate notification manager
- [ ] `firestore.rules` - Add FCM token security rules
- [ ] `en.lproj/Localizable.strings` - Add notification strings
- [ ] `ar.lproj/Localizable.strings` - Add notification strings (RTL)

#### Package Dependencies
- [ ] Add `FirebaseMessaging` to Swift Package Manager

#### Xcode Project Settings
- [ ] Enable "Push Notifications" capability
- [ ] Enable "Background Modes" → "Remote notifications"

---

### Phase 2: Firebase Backend (Cloud Functions) ⏳

#### Files to Create
```
functions/
├── package.json
├── .gitignore
├── index.js (main entry point)
├── notifications/
│   ├── expenseNotifications.js
│   ├── participantNotifications.js
│   └── balanceNotifications.js
└── utils/
    ├── notificationHelpers.js
    └── localization.js
```

#### Cloud Functions to Deploy
- [ ] `onTripChanged` - Main trigger function
- [ ] Helper functions for each notification type
- [ ] Localization utilities (English/Arabic)

---

### Phase 3: Firebase & Apple Configuration ⏳

#### Apple Developer Account (Manual)
- [ ] Generate APNs Authentication Key (.p8 file)
- [ ] Note Key ID
- [ ] Note Team ID

#### Firebase Console (Manual)
- [ ] Open Firebase Console → Project Settings → Cloud Messaging
- [ ] Upload APNs .p8 key
- [ ] Enter Key ID and Team ID
- [ ] Enable Cloud Messaging API

#### Firestore Data Model Updates
```javascript
/users/{userId}
  - fcmToken: string (device token)
  - notificationsEnabled: boolean (default: true)
  - language: string ("en" or "ar")
```

---

### Phase 4: Integration & Testing ⏳

#### Integration Points
- [ ] Link NotificationService to TripViewModel
- [ ] Add notification triggers in expense manager
- [ ] Add notification triggers in participant manager
- [ ] Add notification triggers in balance calculator
- [ ] Update user profile to store FCM token

#### Testing Requirements
- [ ] Test on physical device (push notifications don't work on simulator)
- [ ] Test all 9 notification types
- [ ] Test notifications when app is:
  - [ ] In foreground
  - [ ] In background
  - [ ] Completely killed
- [ ] Test notification tap navigation to correct trip
- [ ] Test enable/disable notifications toggle
- [ ] Test English localization
- [ ] Test Arabic localization (RTL)
- [ ] Test badge count updates
- [ ] Test notification sounds

---

## Progress Tracking

### ✅ Completed (Phase 1 - iOS Infrastructure)
- [x] Requirements gathering
- [x] Architecture design
- [x] Notification type identification
- [x] Implementation plan creation
- [x] Created `Services/NotificationService.swift`
- [x] Updated `AppDelegate.swift` with FCM delegates
- [x] Updated `Services/FirebaseService.swift` with FCM token methods
- [x] Updated `travel_splitApp.swift` to request notification permissions
- [x] Added notification localization strings (English & Arabic)
- [x] Updated `firestore.rules` for FCM token security
- [x] Created complete Cloud Functions code in `CLOUD_FUNCTIONS_SETUP.md`
- [x] Created `NEXT_STEPS.md` with deployment instructions

### ⏳ In Progress (Phase 2 - Backend & Configuration)
- [ ] Add FirebaseMessaging SDK to Xcode project
- [ ] Enable Push Notifications capability in Xcode
- [ ] Generate APNs key from Apple Developer account
- [ ] Upload APNs key to Firebase Console
- [ ] Deploy Firestore security rules to Firebase
- [ ] Deploy Cloud Functions to Firebase

### ⏸️ Pending (Phase 3 - Testing)
- [ ] Test notifications on physical device
- [ ] Verify all 9 notification types
- [ ] Test in all app states (foreground/background/killed)
- [ ] Test localization (English & Arabic)
- [ ] TestFlight beta testing

---

## Manual Setup Required

### Step 1: Apple Developer Account - APNs Key
1. Go to https://developer.apple.com/account/resources/authkeys/list
2. Click "+" to create a new key
3. Name it "EquiSplit Push Notifications"
4. Check "Apple Push Notifications service (APNs)"
5. Click "Continue" → "Register" → "Download"
6. Save the `.p8` file securely
7. **Note the Key ID** (e.g., `AB12CD34EF`)
8. **Note your Team ID** (top right corner, e.g., `XYZ1234567`)

### Step 2: Firebase Console - Upload APNs Key
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your EquiSplit project
3. Click gear icon → "Project Settings"
4. Navigate to "Cloud Messaging" tab
5. Scroll to "Apple app configuration"
6. Click "Upload" under "APNs Authentication Key"
7. Upload the `.p8` file from Step 1
8. Enter Key ID from Step 1
9. Enter Team ID from Step 1
10. Click "Upload"

### Step 3: Xcode Project Capabilities
1. Open `EquiSplit.xcodeproj` in Xcode
2. Select project in navigator → Select target "travel split"
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Push Notifications"
6. Click "+ Capability" again
7. Add "Background Modes"
8. Check "Remote notifications" under Background Modes

### Step 4: Firebase Cloud Functions Setup
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize Functions: `firebase init functions`
4. Choose existing Firebase project (EquiSplit)
5. Choose JavaScript
6. Copy Cloud Functions code from `CLOUD_FUNCTIONS_SETUP.md`
7. Deploy: `firebase deploy --only functions`

### Step 5: Firestore Security Rules
Update `firestore.rules` to allow FCM token writes:
```javascript
// Add this rule under /users/{userId}
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth.uid == userId;

  // Allow users to update their own FCM token
  allow update: if request.auth.uid == userId
    && request.resource.data.keys().hasOnly(['fcmToken', 'notificationsEnabled', 'language']);
}
```

Deploy: `firebase deploy --only firestore:rules`

---

## Testing Checklist

### Pre-Testing Setup
- [ ] Build app on physical iOS device (push doesn't work on simulator)
- [ ] Grant notification permissions when prompted
- [ ] Verify FCM token saved to Firestore `/users/{userId}/fcmToken`
- [ ] Verify Cloud Functions deployed successfully

### Notification Type Tests

#### Expense Notifications
- [ ] Add expense → All participants receive notification
- [ ] Update expense → All participants receive notification
- [ ] Delete expense → All participants receive notification
- [ ] Verify notification title/body correct
- [ ] Verify tapping notification opens correct trip

#### Payment Notifications
- [ ] Record payment → Both payer and recipient receive notification
- [ ] Verify amounts are correct
- [ ] Verify currency symbols correct

#### Balance Notifications
- [ ] Settle balance → User receives "balance settled" notification
- [ ] Verify only sent when balance reaches zero

#### Participant Notifications
- [ ] Join trip → All existing participants receive notification
- [ ] Leave trip → All remaining participants receive notification
- [ ] Claim participant → Creator receives notification
- [ ] Add participant → New participant receives notification

### App State Tests
- [ ] Foreground: Notification appears as banner
- [ ] Background: Notification appears in notification center
- [ ] Killed: Notification appears, tapping opens app

### Localization Tests
- [ ] Set app to English → Notifications in English
- [ ] Set app to Arabic → Notifications in Arabic (RTL)
- [ ] Verify currency formatting correct for both languages

### Settings Tests
- [ ] Toggle notifications OFF → No notifications received
- [ ] Toggle notifications ON → Notifications resume
- [ ] Verify setting persists across app restarts

### Badge & Sound Tests
- [ ] Verify badge count increments with new notifications
- [ ] Verify badge count clears when opening app
- [ ] Verify notification sound plays (default system sound)

---

## Known Limitations

1. **Push notifications don't work on iOS Simulator** - Must test on physical device
2. **APNs requires production certificate for App Store** - Development certificates work for TestFlight/debugging
3. **Notification delivery not guaranteed** - APNs may delay/drop notifications under certain conditions
4. **Badge count requires manual management** - Must track and update in app
5. **Firebase free tier limits** - 10K Cloud Function invocations/day (sufficient for beta)

---

## Troubleshooting

### Issue: Not receiving notifications
- Check notification permissions: Settings → EquiSplit → Notifications
- Verify FCM token exists in Firestore `/users/{userId}/fcmToken`
- Check Cloud Function logs: Firebase Console → Functions → Logs
- Verify APNs key uploaded correctly in Firebase Console
- Ensure device has internet connection

### Issue: Notifications in wrong language
- Check user's language preference in Firestore `/users/{userId}/language`
- Verify localization strings exist in both `en.lproj` and `ar.lproj`

### Issue: Tapping notification doesn't open trip
- Verify notification payload includes `tripId`
- Check deep link handling in `AppDelegate.swift`

### Issue: Badge count not updating
- Verify badge increment logic in `NotificationService.swift`
- Check badge clear logic in `travel_splitApp.swift` `onAppear`

---

## Firebase Cloud Functions Structure

```javascript
// functions/index.js
exports.onTripChanged = functions.firestore
  .document('trips/{tripId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Detect changes
    const expensesAdded = detectExpensesAdded(before, after);
    const expensesUpdated = detectExpensesUpdated(before, after);
    const expensesDeleted = detectExpensesDeleted(before, after);
    const participantsAdded = detectParticipantsAdded(before, after);
    const participantsLeft = detectParticipantsLeft(before, after);
    const participantsClaimed = detectParticipantsClaimed(before, after);
    const balancesSettled = detectBalancesSettled(before, after);

    // Send notifications based on changes
    if (expensesAdded) await sendExpenseAddedNotifications(...);
    if (expensesUpdated) await sendExpenseUpdatedNotifications(...);
    // ... etc
  });
```

---

## Next Steps

1. **Implement iOS notification infrastructure** (Phase 1)
2. **Create Cloud Functions** (Phase 2)
3. **Configure APNs in Firebase Console** (Phase 3 - Manual)
4. **Test on physical device** (Phase 4)
5. **Deploy to TestFlight** for beta testing
6. **Production release**

---

## Resources

- [Firebase Cloud Messaging iOS Setup](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Apple Push Notification Service](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [Firestore Triggers](https://firebase.google.com/docs/functions/firestore-events)

---

## Contact

For questions or issues during implementation, refer to:
- Firebase documentation: https://firebase.google.com/docs
- Apple developer forums: https://developer.apple.com/forums
- This implementation plan

---

**Last Updated:** 2025-10-23
**Implemented By:** Claude Code
**Status:** Phase 1 In Progress
