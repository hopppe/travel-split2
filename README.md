# Free Split

A mobile app that helps friends and travel groups split expenses easily while traveling together.

## Features

- Create trips and add participants
- Add expenses with custom splitting options
- Track who owes what to whom
- Add placeholder participants that others can claim
- Share trips with friends using invite codes
- User authentication with email and password
- Offline functionality - continue using the app without internet
- Currency conversion - record expenses in different currencies
- Real-time balance calculations and updates

## Technical Details

- Built with SwiftUI
- Uses Firebase for backend storage and authentication
- Implements real-time updates for expenses and balances
- Supports offline mode using local caching
- Network connectivity monitoring
- Modern MVVM architecture

## How to Use

### Getting Started

1. Create an account or sign in with existing credentials
2. Once logged in, you'll see your trips dashboard

### Creating a Trip

1. Open the app and tap the "+" button in the top right
2. Choose "Create New Trip"
3. Enter a name and description for your trip
4. Tap "Create"

### Adding Friends to a Trip

1. Open a trip
2. Tap the menu button (three dots) in the top right
3. Select "Add Participant" to manually add a friend
4. Or select "Share Trip" to generate a shareable link

### Recording Expenses

1. Open a trip
2. Tap the "+" button in the expenses tab
3. Enter expense details (title, amount, category)
4. Select who paid for the expense
5. Choose split type (equal or custom)
6. Select the currency if different from default
7. Tap "Save"

### Viewing Balances

1. Open a trip
2. Tap the "Balances" tab
3. See a summary of who owes what to whom
4. View total trip cost and average per person

### Working Offline

- The app automatically synchronizes when internet connection is restored
- You can continue adding expenses and viewing balances while offline
- New data will be uploaded when you're back online

## Development

### Requirements

- Xcode 14.0+
- iOS 16.0+
- Swift 5.7+
- Firebase account and configuration

### Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Set up Firebase configuration
4. Build and run on a simulator or device

## Future Enhancements

- Receipt scanning and automatic expense detection
- Transaction history with filtering options
- Direct payment integration with popular services
- Advanced currency management with real-time rates
- Expense categories analytics and reporting 