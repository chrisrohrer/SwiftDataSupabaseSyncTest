//
//  ViewModel.swift
//  SupaFeatures
//
//  Created by Mikaela Caron on 7/23/23.
//

import Foundation
import Supabase
import Realtime
import SwiftUI
import SwiftData


//@MainActor
final class AuthVM: ObservableObject {
    
    static let shared = AuthVM()
    
    @Published var userId: UUID? = nil
    @Published var user: String? = nil
    
    @Published var loggedInFullName: String? = nil
    
    @Published var isLoading: Bool = true
    
    var isAuthenticated: Bool {
        userId != nil
    }
    
    private var didInitializeSync = false
    
    init() {
        subscribeToAuthChanges()
    }
    
    @MainActor
    func setContext(_ context: ModelContext) {
        // ✅ Start sync after login
        if self.isAuthenticated {
            self.setupSync()
        }
    }
    
    
    // MARK: - Authentication
    
    func subscribeToAuthChanges() {
        Task { @MainActor in
            for await state in supabase.auth.authStateChanges {
                if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                    Task { @MainActor in
                        
                        let user = state.session?.user.email
                        self.userId = state.session?.user.id
                        self.user = state.session?.user.email
                        
                        print("🔒 AuthVM: Auth changed:", state.event, "user:", user as Any, "authenticated:", isAuthenticated)
//                        print("🔒AuthVM: **** Role:", role as Any, "user:", user as Any, "userId:", self.userId as Any)
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        Task {
            do {
                _ = try await supabase.auth.signIn(email: email, password: password)
                self.isLoading = false
            } catch {
                print(#function, error.localizedDescription)
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                self.userId = nil
                self.user = nil
                self.isLoading = false
                
            } catch {
                print(#function, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Sync Initialization
    
    @MainActor
    private func setupSync() {
        guard didInitializeSync == false else { return } // ✅ Prevent multiple initializations
        didInitializeSync = true
        
        Task { @MainActor in
            do {
                print("🔄 Initializing all Syncs...")
                try await SupabaseSyncManager.shared.fetchRemoteChanges()
                try await SupabaseSyncManager.shared.uploadLocalChanges()
                SupabaseSyncManager.shared.startRealtimeSync()
                SwiftDataSyncManager.shared.startObservingContext()
                
            } catch {
                print("🔄 Error initializing sync: \(error)")
            }
        }
    }
}


