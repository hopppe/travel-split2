# ViewModels Organization

This directory contains the ViewModels for the Split Pro app, split into smaller, more focused files for better maintainability.

## Core Files

- **TripViewModel.swift**: The main coordinator ViewModel that delegates specific functionality to specialized components. It maintains the published state and provides a unified interface to the UI layer.

## Specialized Components

- **TripExpenseManager.swift**: Handles all expense-related operations (adding, updating, deleting expenses and payments).
- **TripParticipantManager.swift**: Manages participant-related operations (adding, claiming participants).
- **TripBalanceCalculator.swift**: Manages balance calculations, debts, and currency operations.
- **TripUserManager.swift**: Handles user authentication, creation, and updates.
- **TripJoinService.swift**: Manages trip joining and sharing operations.

## Design Pattern

The code uses a composition pattern where the main TripViewModel owns specialized manager objects, delegating specific functionality to them. This approach helps keep files smaller (under 200 lines) and more focused, making the code easier to maintain and extend.

## Benefits

1. **Separation of concerns**: Each file focuses on one aspect of the app's functionality
2. **Improved maintainability**: Smaller, focused files are easier to understand and modify
3. **Better testability**: Specialized components can be tested in isolation
4. **Code organization**: Logic is organized by function rather than being in one large file

## Usage

The UI layer should continue to use the TripViewModel as before. All public methods from the original implementation are preserved, but they now delegate to the appropriate specialized component internally. 