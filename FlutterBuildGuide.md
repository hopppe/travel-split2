# Free Split - Flutter Build Guide

This guide provides comprehensive information for rebuilding the Free Split app in Flutter. The original app was built in SwiftUI, and this document serves as a blueprint for recreating the same functionality in Flutter.

## App Overview

Free Split is a mobile app that helps friends and travel groups split expenses easily while traveling together. It allows users to create trips, add participants, record expenses with custom splitting options, and track who owes what to whom, all with a clean, intuitive interface.

## Core Features

- User authentication (email/password and anonymous)
- Trip creation and management
- Expense tracking with flexible splitting options
- Real-time balance calculations
- Participant management (including "unclaimed" placeholder participants)
- Trip sharing via invite codes
- Offline functionality
- Multiple currency support

## Technical Requirements

- Flutter SDK (latest stable version)
- Firebase for backend:
  - Firestore Database
  - Firebase Authentication
  - Cloud Functions (optional, for advanced features)
- State management: Provider or Riverpod
- Local storage: Hive or shared_preferences for offline capability

## Architecture

Implement a clean MVVM (Model-View-ViewModel) architecture:

1. **Models**: Data classes representing core entities
2. **Views**: Flutter widgets for the UI
3. **ViewModels**: Business logic and state management
4. **Services**: Firebase integration, authentication, etc.

## Data Models

### User Model
```dart
class User {
  final String id;
  String name;
  String email;
  String? profileImage;
  bool isClaimed;
  String? claimedByUserId;
  
  // Factory methods for creating users
  factory User.create(String name, String email) {
    // Implementation for creating claimed user with Firebase ID
  }
  
  factory User.createUnclaimed(String name, {String email = ""}) {
    // Implementation for creating unclaimed participant
  }
}
```

### Trip Model
```dart
class Trip {
  final String id;
  String name;
  String description;
  DateTime? startDate;
  DateTime? endDate;
  List<User> participants;
  List<Expense> expenses;
  String inviteCode;
  String baseCurrencyCode;
  
  // Factory method for creating new trip
  factory Trip.create(String name, String description, User creator) {
    // Implementation
  }
  
  // Get currency symbol from code
  String get baseCurrencySymbol {
    // Implementation to return currency symbol
  }
  
  // Calculate debts between participants
  List<Debt> calculateDebts() {
    // Implementation of debt calculation algorithm
  }
}
```

### Expense Model
```dart
class Expense {
  final String id;
  String title;
  String description;
  double amount;
  DateTime date;
  ExpenseCategory category;
  User paidBy;
  List<ExpenseShare> shares;
  String? currencyCode;
  
  // Get currency symbol
  String get currencySymbol {
    // Implementation
  }
  
  // Factory method for equal split expenses
  factory Expense.createEqual(
    String title, 
    double amount, 
    User paidBy, 
    List<User> participants, 
    {DateTime? date, 
    ExpenseCategory category = ExpenseCategory.other, 
    String currencyCode = "USD"}
  ) {
    // Implementation
  }
  
  // Factory method for custom split expenses
  factory Expense.createCustom(
    String title, 
    double amount, 
    User paidBy, 
    List<ExpenseShare> shares, 
    {DateTime? date, 
    ExpenseCategory category = ExpenseCategory.other, 
    String currencyCode = "USD"}
  ) {
    // Implementation
  }
}
```

### Supporting Models
```dart
class ExpenseShare {
  User user;
  double amount;
  double percentage;
}

class Debt {
  String id;
  User from;
  User to;
  double amount;
}

enum ExpenseCategory {
  food, accommodation, transportation, activities, shopping, other
}
```

## Firebase Structure

### Firestore Collections
- **users**: User information
  - Fields: id, name, email, profileImage, isClaimed, claimedByUserId
- **trips**: Trip information
  - Fields: id, name, description, startDate, endDate, inviteCode, baseCurrencyCode
- **participants**: Trip participants (subcollection of trips)
  - Fields: userId, tripId, reference to users collection
- **expenses**: Expenses for trips (subcollection of trips)
  - Fields: id, tripId, title, description, amount, date, category, paidBy, currencyCode
- **shares**: Expense shares (subcollection of expenses)
  - Fields: expenseId, userId, amount, percentage

### Security Rules
Implement Firebase security rules to ensure:
- Users can only access their own data
- Trip participants can only access trips they're part of
- Only authenticated users can create/edit trips

## UI Screens and Navigation

### Main App Flow
1. **Splash/Loading Screen**
2. **Authentication Flow**:
   - Welcome screen
   - Sign up screen
   - Sign in screen
3. **Main App Flow**:
   - Trips list screen
   - Trip detail screen with tabs
   - User profile screen

### Screen Details

#### Welcome Screen
- App introduction
- Sign in button
- Sign up button
- Anonymous sign in option

#### Sign Up/Sign In Screens
- Email and password fields
- Authentication buttons
- Error handling displays

#### Trips List Screen
- List of trips the user is part of
- FAB to create new trips
- Trip card showing name, dates, and participant count
- Settings access

#### Trip Detail Screen
- Trip information at the top
- Tab navigation:
  1. **Expenses Tab**: List of expenses with search and filter
  2. **Balances Tab**: Who owes what to whom
  3. **Participants Tab**: List of trip participants
- FAB to add new expenses

#### Add/Edit Expense Screen
- Form for expense details
- Payer selection
- Split type selection (equal/custom)
- Currency selection
- Category selection

#### User Profile Screen
- User information
- Profile image
- Update profile option
- Sign out button

## ViewModels

### AuthViewModel
- Handle authentication state
- Sign in/sign up with email
- Anonymous sign in
- Sign out

### TripViewModel
- List, create, update, delete trips
- Join trips with invite code
- Calculate balances
- Manage trip settings

### TripExpenseManager
- Add, edit, delete expenses
- Manage expense splits
- Currency conversion

### TripParticipantManager
- Add, remove participants
- Manage unclaimed participants
- Participant claiming process

## Services

### AuthenticationService
- Firebase Auth integration
- User state persistence
- User profile management

### FirebaseService
- Firestore CRUD operations
- Real-time data synchronization
- Offline persistence configuration

### CurrencyConverterService
- Currency conversion logic
- Cache exchange rates for offline use

### NetworkMonitor
- Track network connectivity
- Trigger sync when connection is restored

## Deep Linking

Implement Firebase Dynamic Links or custom URL scheme to handle:
- Trip invitations
- Participant claiming

## Offline Functionality

- Cache trips and expenses locally
- Queue changes when offline
- Sync when online
- Show offline status indicator

## Implementation Strategy

1. **Setup Project**:
   - Create Flutter project
   - Configure Firebase
   - Set up architecture

2. **Authentication**:
   - Implement sign up/sign in
   - User profile management

3. **Core Models**:
   - Create data models
   - Firebase service implementation

4. **Main Screens**:
   - Build UI components
   - Trips list and management

5. **Expense Management**:
   - Add/edit expenses
   - Splitting algorithm

6. **Balance Calculation**:
   - Implement debt calculation algorithm
   - Balance display

7. **Sharing Features**:
   - Invite system
   - Deep linking

8. **Offline Support**:
   - Local storage
   - Synchronization

9. **Polish and Testing**:
   - UI refinement
   - Comprehensive testing

## Packages to Consider

- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `provider` or `riverpod` for state management
- `hive` or `shared_preferences` for local storage
- `intl` for formatting dates and currencies
- `flutter_native_splash` for splash screen
- `connectivity_plus` for network monitoring
- `image_picker` for profile images
- `share_plus` for sharing invite links
- `flex_color_scheme` for consistent theming

## UI/UX Guidelines

- Use a modern, clean design with clear visual hierarchy
- Main color scheme: indigo as primary color
- Implement responsive design for various screen sizes
- Use skeleton loading indicators for better UX
- Intuitive navigation between screens
- Meaningful error messages and empty states
- Accessibility considerations for all UI elements

## Testing Strategy

- Unit tests for models and business logic
- Widget tests for UI components
- Integration tests for key user flows
- Firebase emulator testing

This guide provides a comprehensive starting point for rebuilding Free Split in Flutter while maintaining its core functionality and user experience. 