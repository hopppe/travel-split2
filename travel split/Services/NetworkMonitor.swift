//
//  NetworkMonitor.swift
//  EquiSplit
//
//  Created for offline functionality
//

import Foundation
import Combine

// MARK: - Network Monitoring Protocol

public protocol NetworkMonitoring: ObservableObject {
    var isConnected: Bool { get }
    var connectivityChangedPublisher: PassthroughSubject<Bool, Never> { get }
    
    func checkConnectivity()
}

// MARK: - Default Network Monitor Implementation

public class NetworkMonitor: NetworkMonitoring, ObservableObject {
    public static let shared = NetworkMonitor()
    
    // Published property that indicates network status
    @Published public var isConnected = true
    
    // For publishing connectivity change notifications
    public let connectivityChangedPublisher = PassthroughSubject<Bool, Never>()
    
    private init() {
        setupMonitor()
    }
    
    private func setupMonitor() {
        // Platform-specific implementation will be provided
        #if canImport(Network)
        setupIOSMonitor()
        #else
        // Fallback - assume connected
        isConnected = true
        #endif
    }
    
    // Method to manually check connectivity status
    public func checkConnectivity() {
        #if canImport(Network)
        checkIOSConnectivity()
        #else
        // Fallback - assume connected
        updateConnectionStatus(true)
        #endif
    }
    
    // Helper method to update connection status
    private func updateConnectionStatus(_ connected: Bool) {
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
}

// MARK: - iOS-Specific Implementation
#if canImport(Network)
import Network

extension NetworkMonitor {
    private func setupIOSMonitor() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // Determine if we're connected based on path status
            let connected = path.status == .satisfied
            self.updateConnectionStatus(connected)
        }
        
        // Start monitoring
        monitor.start(queue: queue)
    }
    
    private func checkIOSConnectivity() {
        let monitor = NWPathMonitor()
        let connected = monitor.currentPath.status == .satisfied
        updateConnectionStatus(connected)
    }
}
#endif 