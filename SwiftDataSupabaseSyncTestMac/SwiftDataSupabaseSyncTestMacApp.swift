//
//  SwiftDataSupabaseSyncTestMacApp.swift
//  SwiftDataSupabaseSyncTestMac
//
//  Created by Christoph Rohrer on 04.02.25.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataSupabaseSyncTestMacApp: App {
    
    @StateObject var authVM = AuthVM()

    @State private var modelContainer = try! ModelContainer(for: Autor.self, Buch.self)

    var body: some Scene {
        WindowGroup {
            AuthView()
        }
        .modelContainer(modelContainer)
        .environmentObject(authVM)

    }
}
