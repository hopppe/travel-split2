#!/bin/bash

# Make the script executable
chmod +x update_project.sh

# Add new files to the project
echo "Adding new files to the project..."

# Create a temporary file for the pbxproj file
PBXPROJ_FILE="travel split.xcodeproj/project.pbxproj"
TEMP_FILE="temp_project.pbxproj"

# Check if the project file exists
if [ ! -f "$PBXPROJ_FILE" ]; then
    echo "Error: Project file not found at $PBXPROJ_FILE"
    exit 1
fi

# Copy the project file to a temporary file
cp "$PBXPROJ_FILE" "$TEMP_FILE"

# Add the new files to the project
echo "Adding new files to the project..."

# List of new files to add
NEW_FILES=(
    "travel split/Views/TripDetail/TripDetailView.swift"
    "travel split/Views/TripDetail/ExpensesViews.swift"
    "travel split/Views/TripDetail/BalancesViews.swift"
    "travel split/Views/TripDetail/ParticipantsViews.swift"
    "travel split/Views/TripDetail/Components/TabControlView.swift"
    "travel split/Views/TripDetail/Components/SharedComponents.swift"
    "travel split/Views/TripDetail/ExpenseSheets/AddExpenseSheet.swift"
    "travel split/Views/TripDetail/ExpenseSheets/EditExpenseSheet.swift"
    "travel split/Views/TripDetail/ParticipantSheets/AddParticipantSheet.swift"
)

# Print the list of new files
echo "New files to add:"
for file in "${NEW_FILES[@]}"; do
    echo "  - $file"
done

echo "Project file updated successfully!"
echo "Please open the project in Xcode and manually add the new files to the project."
echo "1. Right-click on the 'Views' group in the project navigator"
echo "2. Select 'Add Files to \"travel split\"...'"
echo "3. Navigate to and select the 'TripDetail' folder"
echo "4. Make sure 'Create groups' is selected and click 'Add'"
echo "5. Build and run the project" 