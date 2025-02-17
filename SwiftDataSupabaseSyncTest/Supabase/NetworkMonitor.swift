//
//  NetworkMonitor.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 17.02.25.
//

import Foundation
import Network
import SwiftData


@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isOnline: Bool = false
    
    init() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in
                self.isOnline = path.status == .satisfied
                print("🌍 Network status changed: \(self.isOnline ? "Online" : "Offline")")
                
                if self.isOnline || path.status == .satisfied {
                    Task {
//                        print("inside task")
                        do {
                            try await SupabaseSyncManager.shared.uploadLocalChanges()
                            try await SupabaseSyncManager.shared.fetchRemoteChanges()
                        } catch {
                            print("❌ Error syncing after network restore: \(error)")
                        }
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}
