import SwiftUI

@main
struct TravelSplitApp: App {
    // Create a sample user - in a real app this would come from authentication
    @StateObject private var tripViewModel = TripViewModel(
        currentUser: User.create(name: "You", email: "you@example.com")
    )
    
    var body: some Scene {
        WindowGroup {
            TripsListView(viewModel: tripViewModel)
                .tint(.indigo) // Set app accent color
                .onAppear {
                    // Set up appearance
                    configureAppearance()
                }
        }
    }
    
    // Configure global appearance settings
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Apply appearance to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
} 