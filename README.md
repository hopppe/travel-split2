# Travel Split

Travel Split is an iOS app designed to simplify expense sharing between friends during trips. Similar to Splitwise, it allows users to track expenses, split costs equally or customly, and see who owes what to whom.

## Features

- **Create Trips**: Create trip groups to track expenses together
- **Invite Friends**: Share invite links to add friends to your trips
- **Add Expenses**: Quickly add expenses with descriptions and amounts
- **Flexible Splitting**: Split expenses equally by default, or customize splits as needed
- **Balance Calculation**: Automatically calculate who owes what to whom
- **Expense Categories**: Categorize expenses for better organization
- **Simple Interface**: Clean, intuitive UI following Apple's design guidelines

## How to Use

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
6. Tap "Save"

### Viewing Balances

1. Open a trip
2. Tap the "Balances" tab
3. See a summary of who owes what to whom
4. View total trip cost and average per person

## Technical Details

The app follows a clean architecture pattern:

- **Models**: Core data structures (User, Trip, Expense)
- **ViewModels**: Business logic and state management
- **Views**: UI components and user interaction

## Development

### Requirements

- Xcode 14.0+
- iOS 16.0+
- Swift 5.7+

### Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Build and run on a simulator or device

## Future Enhancements

- User authentication
- Cloud storage and synchronization
- Receipt scanning
- Transaction history
- Direct payment integration 