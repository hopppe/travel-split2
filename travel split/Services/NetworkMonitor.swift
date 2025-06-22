//
//  NetworkMonitor.swift
//  free split
//
//  Created for offline functionality
//

import Foundation
import Network
import Combine

// MARK: - Network Monitor

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    // Published property that indicates network status
    @Published var isConnected = true
    
    // For publishing connectivity change notifications
    let connectivityChangedPublisher = PassthroughSubject<Bool, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        setupMonitor()
    }
    
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Determine if we're connected based on path status
            let connected = path.status == .satisfied
            
            // Update the published property on the main thread
            DispatchQueue.main.async {
                // Only notify if there's a change
                if self.isConnected != connected {
                    print("Network connectivity changed to: \(connected ? "online" : "offline")")
                    self.isConnected = connected
                    
                    // Notify subscribers of the change
                    self.connectivityChangedPublisher.send(connected)
                }
            }
        }
        
        // Start monitoring
        monitor.start(queue: queue)
    }
    
    // Method to manually check connectivity status
    func checkConnectivity() {
        let connection = monitor.currentPath.status == .satisfied
        
        // Update the published property on the main thread
        DispatchQueue.main.async {
            // Only notify if there's a change
            if self.isConnected != connection {
                print("Network connectivity changed to: \(connection ? "online" : "offline")")
                self.isConnected = connection
                
                // Notify subscribers of the change
                self.connectivityChangedPublisher.send(connection)
            }
        }
    }
    
    deinit {
        monitor.cancel()
    }
} 