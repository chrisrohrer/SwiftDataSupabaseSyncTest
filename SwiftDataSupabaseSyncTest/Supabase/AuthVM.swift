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


//@MainActor
final class AuthVM: ObservableObject {
    
    static let shared = AuthVM()
    
    @Published var userId: UUID? = nil
    @Published var user: String? = nil

    @Published var loggedInFullName: String? = nil
    @Published var rechte: Rechte = .keine

    @Published var isLoading: Bool = true

    var isAuthenticated: Bool {
        userId != nil
    }
        
    init() {
        subscribeToAuthChanges()
    }
    
    
    // MARK: - Authentication
        
    func subscribeToAuthChanges() {
        Task { @MainActor in
            for await state in supabase.auth.authStateChanges {
                if [.initialSession, .signedIn, .signedOut].contains(state.event) {
                    Task { @MainActor in
                        
                        let role = state.session?.user.role
                        let user = state.session?.user.email
                        
                        if role == "supabase_admin" {
                            self.rechte = .admin
                        }
                        
                        self.userId = state.session?.user.id
                        self.user = state.session?.user.email
                        
                        print("Users Auth changed:", state.event, isAuthenticated)
                        print("AuthVM **** Role:", role as Any, "user:", user as Any, "userId:", self.userId as Any)
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
            } catch {
                print(#function, error.localizedDescription)
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
            } catch {
                print(#function, error.localizedDescription)
            }
        }
    }
}



extension AuthVM {
    
    enum Rechte: String, CaseIterable, Codable {
        case keine          = "Keine"

        // nur Stunden, Mitarbeiter, Teams
        case mitarbeiter    = "Mitarbeiter"
        case empfang        = "Empfang"         // zusätzlich Zugriff auf Kasse Empfang
        case it             = "IT"              // zusätzlich Zugriff auf Inventar
        case personal       = "Personal"        // Zugriff auf Adressdaten und Mitarbeiterdaten

        // eigene Kunden, Projektdaten, Cards, Adressen
        case projektmanager = "Projektmanager"
        case teamleiter     = "Teamleiter"      // Reporting eigene Teamauswertung
        
        // ALLE Kunden, Projektdaten
        case associate      = "Associate"       // Reporting eigene Teamauswertung
        
        // ALLES - Finanzen, Reporting, Inventar, Liquidität, Personal
        case finance        = "Finance"
        case admin          = "Admin"
    }

    
    var rechtePersonaldaten: Bool {
        [.admin, .finance, .personal].contains(rechte)
    }
    
    var rechteAlleKundenProjekte: Bool {
        [.admin, .finance, .associate].contains(rechte)
    }

    var rechteEigeneKundenProjekte: Bool {
        [.admin, .finance, .associate, .teamleiter, .projektmanager].contains(rechte)
    }

    var rechteAdressen: Bool {
        [.admin, .finance, .associate, .teamleiter, .projektmanager, .personal].contains(rechte)
    }

    var rechteFinance: Bool {
        [.admin, .finance].contains(rechte)
    }

}


extension View {
    /// zeigt View nur wenn ebtsprechende Rechte vorhanden sind
    func fürRechte(_ rechte: [AuthVM.Rechte]) -> some View {
        self
            .modifier(FürRechte(rechte: rechte))
    }
}

struct FürRechte: ViewModifier {
    
    let rechte: [AuthVM.Rechte]
    @EnvironmentObject var authVM: AuthVM
    
    func body(content: Content) -> some View {
        if rechte.contains(authVM.rechte) {
            content
        } else {
//            Image(systemName: "lock")
            EmptyView()
        }
    }
}
