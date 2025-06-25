# EquiSplit

A SwiftUI mobile app that helps friends and travel groups split expenses easily while traveling together. Built with Firebase backend for real-time synchronization and offline support.

## Current Status

**Development Phase**: Active Development  
**Platform**: iOS (SwiftUI)  
**Backend**: Firebase (Firestore, Authentication)  
**Architecture**: MVVM with specialized component managers  

### Recent Updates
- ✅ **Major Refactoring Complete**: Broke down large files into focused, maintainable components
- ✅ **Modular Architecture**: Implemented specialized ViewModels for different functionality areas
- ✅ **Enhanced Code Organization**: Files now under 200 lines following best practices
- ✅ **Bug Fixes**: Resolved custom split amounts and visual feedback issues

## Features

### Core Functionality
- ✅ **User Authentication**: Email/password and anonymous authentication
- ✅ **Trip Management**: Create, join, and manage expense groups
- ✅ **Expense Tracking**: Add expenses with flexible splitting options (equal or custom)
- ✅ **Smart Balance Calculations**: Real-time debt calculations between participants
- ✅ **Participant Management**: Add friends or placeholder participants that can be claimed later
- ✅ **Trip Sharing**: Share trips via invite codes and deep links
- ✅ **Multi-Currency Support**: Record expenses in different currencies with automatic conversion
- ✅ **Offline Functionality**: Continue using the app without internet, sync when reconnected
- ✅ **Real-time Updates**: Live synchronization of expenses and balances across devices

### Advanced Features
- ✅ **Unclaimed Participants**: Add placeholder participants that others can claim via invite links
- ✅ **Deep Linking**: Join trips and claim participants via shareable URLs
- ✅ **Network Monitoring**: Visual indicators for offline/online status
- ✅ **Currency Conversion**: Built-in currency converter with cached rates
- ✅ **Balance Breakdown**: Detailed view of who owes what and why
- ✅ **Payment Recording**: Track when debts are settled between participants

## Technical Architecture

### Core Technologies
- **Frontend**: SwiftUI (iOS 16.0+)
- **Backend**: Firebase (Firestore Database, Authentication)
- **Architecture**: MVVM with specialized component managers
- **Language**: Swift 5.7+
- **Development Environment**: Xcode 14.0+

### Architecture Components

#### Specialized ViewModels
- **TripViewModel**: Main coordinator that delegates to specialized managers
- **TripExpenseManager**: Handles expense operations (add, edit, delete, payments)
- **TripParticipantManager**: Manages participant operations and claiming
- **TripBalanceCalculator**: Handles balance calculations and currency operations
- **TripUserManager**: Manages user authentication and profile updates
- **TripJoinService**: Handles trip joining and sharing functionality

#### Services Layer
- **FirebaseService**: Firestore operations and real-time synchronization
- **AuthenticationService**: User authentication and session management
- **CurrencyConverterService**: Currency conversion with offline caching
- **NetworkMonitor**: Network connectivity monitoring

#### Data Models
- **User**: User profiles with claiming functionality for placeholder participants
- **Trip**: Trip information with invite codes and currency settings
- **Expense**: Expense records with flexible splitting and multi-currency support
- **ExpenseShare**: Individual participant shares in expenses
- **Debt**: Calculated debts between participants

### File Organization
```
travel split/
├── Models/                     # Data models
├── Services/                   # Backend and utility services
├── ViewModels/                 # MVVM business logic layer
├── Views/
│   ├── TripDetail/            # Modular trip detail components
│   │   ├── Components/        # Reusable UI components
│   │   ├── ExpenseSheets/     # Expense management sheets
│   │   └── ParticipantSheets/ # Participant management sheets
│   └── Common/                # Shared UI components
└── Assets.xcassets/           # App assets and icons
```

## How to Use

### Getting Started
1. **Sign Up/Sign In**: Create an account or sign in with existing credentials
2. **Anonymous Option**: Start immediately with anonymous authentication
3. **Profile Setup**: Set your name and preferences

### Trip Management
1. **Create a Trip**: Tap "+" → "Create New Trip" → Enter details
2. **Join a Trip**: Use invite code or tap shared link
3. **Add Participants**: Manually add friends or create placeholder participants

### Expense Tracking
1. **Add Expense**: Tap "+" in expenses tab → Enter details
2. **Choose Split Type**: Equal split or custom amounts per person
3. **Multi-Currency**: Select different currency if needed
4. **Track Payments**: Record when debts are settled

### Balance Management
1. **View Balances**: See who owes what in the Balances tab
2. **Detailed Breakdown**: Tap any balance for expense-by-expense details
3. **Settle Debts**: Record payments to update balances

### Sharing and Collaboration
1. **Share Trip**: Generate invite link to share with friends
2. **Claim Participants**: Others can claim placeholder participants via shared links
3. **Real-time Sync**: Changes appear instantly across all devices

## Development

### Requirements
- Xcode 14.0+
- iOS 16.0+ deployment target
- Swift 5.7+
- Firebase project with Firestore and Authentication enabled

### Setup Instructions
1. **Clone Repository**: `git clone [repository-url]`
2. **Firebase Configuration**: 
   - Add your `GoogleService-Info.plist` to the project
   - Configure Firestore security rules (see `firestore.rules`)
3. **Dependencies**: All dependencies managed through Swift Package Manager
4. **Build and Run**: Open in Xcode and build for simulator or device

### Firebase Configuration
- **Authentication**: Email/password and anonymous auth enabled
- **Firestore**: Offline persistence enabled with 100MB cache
- **Security Rules**: Configured for user-specific data access (see `firestore.rules`)

### Testing
- Unit tests: `travel splitTests/`
- UI tests: `travel splitUITests/`
- Firestore rules testing: See `firestore-rules-testing.md`

## Current Development Focus

### Completed ✅
- Core expense splitting functionality
- Real-time Firebase synchronization
- Offline support with automatic sync
- Multi-currency support
- Deep linking for trip invitations
- Modular architecture refactoring
- Participant claiming system

### In Progress 🚧
- Enhanced UI polish and animations
- Improved accessibility features
- Performance optimizations
- Additional currency support

### Planned 📋
- Receipt scanning with automatic expense detection
- Advanced expense categorization and analytics
- Direct payment integration (Apple Pay, etc.)
- Export functionality for trip summaries
- Group messaging within trips

## Contributing

The codebase follows these principles:
- **Clean, readable code** with clear naming conventions
- **Files under 200 lines** for better maintainability
- **Modular architecture** with separation of concerns
- **Comprehensive commenting** for complex business logic
- **Minimal, focused changes** when fixing issues

## Support

For feedback or support:
- **Email**: ethan@ingenuitylabs.net
- **Issues**: Use GitHub issues for bug reports and feature requests

## License

This project is currently in active development. License information will be added upon initial release.

---

**Note**: This app is currently iOS-only. A Flutter version guide is available in `FlutterBuildGuide.md` for cross-platform development planning. 