# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EquiSplit** is an iOS expense splitting app built with SwiftUI and Firebase. It helps groups track and split expenses while traveling together, with features like offline support, multi-currency conversion, real-time synchronization, and participant claiming.

**Tech Stack:**
- SwiftUI (iOS 16.0+)
- Firebase (Firestore, Authentication)
- Swift Package Manager for dependencies
- MVVM architecture with specialized component managers

## Build Commands

**Open project:**
```bash
open "EquiSplit.xcodeproj"
```

**Build and run:**
- Open in Xcode 14.0+ and use the standard build/run commands (Cmd+B to build, Cmd+R to run)
- Target iOS 16.0+ simulator or device

**Run tests:**
- Unit tests: `travel splitTests/`
- UI tests: `travel splitUITests/`
- Use Xcode's test navigator (Cmd+6) or Cmd+U to run all tests

**Firebase setup required:**
- Project requires `GoogleService-Info.plist` (not in repo for security)
- See `firebase-setup.md` for Firebase configuration
- Security rules in `firestore.rules`

## Architecture

### MVVM with Specialized Managers

The app uses a **coordinator-style MVVM pattern** where `TripViewModel` acts as the main coordinator and delegates to specialized managers:

**Core Coordinator:**
- `TripViewModel` - Main coordinator that orchestrates all trip operations and manages state

**Specialized Managers (Properties of TripViewModel):**
- `TripExpenseManager` - Expense CRUD operations and payment recording
- `TripParticipantManager` - Participant management and claiming
- `TripBalanceCalculator` - Balance calculations and currency conversions
- `TripUserManager` - User authentication and profile management
- `TripJoinService` - Trip joining, sharing, and deep linking

**Services Layer:**
- `FirebaseService` - Firestore operations, real-time listeners, deep linking
- `AuthenticationService` - Firebase Authentication wrapper
- `CurrencyConverterService` - Currency conversion with offline caching
- `NetworkMonitor` - Network connectivity monitoring
- `LanguageManager` - Localization and RTL support (English/Arabic)

**Key Architectural Patterns:**

1. **Delegation to Managers**: TripViewModel exposes public methods that delegate to specialized managers:
   ```swift
   func addExpenseToCurrentTrip(...) {
       expenseManager.addExpense(...)
   }
   ```

2. **Real-time Synchronization**: Firebase listeners update local state automatically. Each trip has a dedicated listener set up in `setupTripListener(for:)`.

3. **Offline-First**: Operations update local state immediately, then sync to Firebase. Failed syncs are queued in `pendingSync` dictionary and retried when online.

4. **Participant Claiming**: Unclaimed participants can be claimed via deep links. Unclaimed participant IDs follow pattern: `unclaimed_{auth_user_id}_{random}_{name}`.

### Data Models

**Core Models** (`Models/Models.swift`):
- `User` - User profiles with `isClaimed` flag for placeholder participants
- `Trip` - Trip with participants, expenses, inviteCode, and baseCurrencyCode
- `Expense` - Expense with flexible splitting and multi-currency support
- `ExpenseShare` - Individual participant shares in expenses
- `Debt` - Calculated debts between participants (computed, not stored)

**Important:** Users can be either:
- Claimed users (real app users with Firebase authentication)
- Unclaimed users (placeholders that can be claimed later via invite links)

### File Organization

```
travel split/
├── Models/                     # Data models
├── Services/                   # Backend and utility services
├── ViewModels/                 # MVVM business logic (TripViewModel + managers)
├── Views/
│   ├── TripDetail/            # Modular trip detail components
│   │   ├── Components/        # Reusable UI components
│   │   ├── ExpenseSheets/     # Expense management sheets
│   │   └── ParticipantSheets/ # Participant management sheets
│   └── [Other views]          # Authentication, trips list, profile
├── Extensions/                # Swift extensions (String+Localization)
├── en.lproj/                  # English localization
├── ar.lproj/                  # Arabic localization (with RTL support)
└── Assets.xcassets/           # App assets and icons
```

## Key Implementation Details

### Firebase Integration

**Authentication:**
- Anonymous auth enabled by default for quick onboarding
- Email/password authentication for persistent accounts
- User ID consistency managed by `TripUserManager.ensureUserIdConsistency()`

**Firestore Structure:**
```
/trips/{tripId}
  - name, description, participants[], expenses[], inviteCode, baseCurrencyCode

/users/{userId}
  - name, email, profileImage
```

**Security Rules** (`firestore.rules`):
- Authenticated users can read/write their own trips
- Trips with ≤1 participant can be deleted
- See file for full rules

### Offline Support & Sync

**Pattern:**
1. Update local state immediately
2. Add to `pendingSync` dictionary
3. Attempt Firebase sync via `syncTripToFirebase()`
4. On success: remove from `pendingSync`, set up listener
5. On failure: keep in `pendingSync` for later retry
6. `NetworkMonitor` triggers `syncPendingTrips()` when connection restored

**Real-time Listeners:**
- Each trip has a Firestore snapshot listener
- Updates propagate automatically to `trips` array and `currentTrip`
- Listeners cleaned up in `stopAllListeners()` or when user leaves trip

### Deep Linking & Sharing

**Universal Links:**
- Base URL: `https://equisplit.ingenuitylabs.net/join/{inviteCode}`
- Handled in `travel_splitApp.swift` via `.onOpenURL` modifier
- Web files in `web-files/` directory (deployed to Vercel)
- `apple-app-site-association` file configures Universal Links

**Flow:**
1. User shares trip → generates Universal Link with invite code
2. Recipient opens link → app handles via `autoJoinTrip(withInviteCode:)`
3. If unclaimed participants match user, show claim sheet
4. Otherwise, add user as new participant

### Localization (English & Arabic)

**Implementation:**
- `LanguageManager` singleton manages language switching
- 200+ localized strings in `en.lproj/` and `ar.lproj/`
- String extension: `"key".localized` for simple localization
- Full RTL (Right-to-Left) support for Arabic
- See `ARABIC_LOCALIZATION_PLAN.md` for details

**Usage:**
```swift
Text("welcome_title".localized)  // Simple
Text(String(format: "participants_count".localized, count))  // With params
```

### Balance Calculations & Currency

**Balance Calculation** (`TripBalanceCalculator`):
- All expenses converted to trip's `baseCurrencyCode` for balance calculation
- Uses `CurrencyConverterService.shared.convert(amount:from:to:)`
- Debt simplification algorithm in `Trip.calculateDebts()`

**Multi-Currency:**
- Each expense can have its own `currencyCode`
- Currency rates cached for offline use
- Symbols mapped in `Models.swift` (currencySymbol computed property)

### Participant Management

**Adding Participants:**
- Direct: `addParticipantToCurrentTrip(_:)` for existing users
- Unclaimed: `addUnclaimedParticipantToCurrentTrip(name:email:)` for placeholders

**Claiming Participants:**
- `TripJoinService.autoJoinTrip()` checks for claimable participants
- Shows `ParticipantClaimView` if matches found
- Claiming updates participant's `isClaimed` flag and `claimedByUserId`

**Removal:**
- Can only remove if participant balance is zero
- Check via `canRemoveParticipant(_:)` before attempting removal

## Development Guidelines

### Modular Architecture
- Keep files under 200 lines when possible
- Separation of concerns: ViewModels handle business logic, Views handle UI
- Delegate complex operations to specialized managers

### Firebase Operations
- Always check `NetworkMonitor.shared.isConnected` before assuming online
- Use `pendingSync` pattern for operations that need to be retried
- Clean up listeners in `deinit` or when user leaves context

### Testing Firestore Rules
- See `firestore-rules-testing.md` for testing security rules
- Rules must be tested before deployment

### User ID Consistency
- When working with user identity, call `userManager.ensureUserIdConsistency()` first
- Firebase user ID is source of truth (from `Auth.auth().currentUser?.uid`)
- UserDefaults stores user_id, user_name, user_email for offline access

### Deep Link Testing
- Universal Links only work on real devices (not simulators)
- Test both scenarios: app installed vs not installed
- Web deployment at `equisplit.ingenuitylabs.net`

### Localization
- All new user-facing strings must use localization keys
- Add to both `en.lproj/Localizable.strings` and `ar.lproj/Localizable.strings`
- Use semantic alignment (`.leading`/`.trailing`) for RTL compatibility

## Common Tasks

**Add a new expense:**
```swift
tripViewModel.addExpenseToCurrentTrip(
    title: "Dinner",
    amount: 50.0,
    paidBy: user,
    splitType: .equal,
    category: .food,
    currencyCode: "USD"
)
```

**Join a trip:**
```swift
tripViewModel.joinTrip(withInviteCode: code) { success in
    // Handle result
}
```

**Update trip currency:**
```swift
tripViewModel.updateBaseCurrency(to: "EUR")
```

**Leave a trip:**
```swift
tripViewModel.leaveTrip(trip: currentTrip)
// Note: Only works if user balance is zero
```

## Important Files

- `travel_splitApp.swift` - App entry point, deep link handling, auth state
- `TripViewModel.swift` - Main coordinator for all trip operations
- `FirebaseService.swift` - All Firestore operations and real-time listeners
- `Models.swift` - Core data models with business logic
- `firestore.rules` - Firestore security rules (deploy to Firebase)
- `GoogleService-Info.plist` - Firebase config (gitignored, must be added locally)

## Documentation Files

- `README.md` - Project overview and features
- `ARABIC_LOCALIZATION_PLAN.md` - Complete localization implementation guide
- `firebase-setup.md` - Firebase project setup instructions
- `firestore-rules-testing.md` - Security rules testing guide
- `FlutterBuildGuide.md` - Cross-platform considerations (future)
- `REFACTORING_README.md` - Architecture refactoring notes
