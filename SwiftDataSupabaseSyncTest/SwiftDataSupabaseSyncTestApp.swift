//
//  SwiftDataSupabaseSyncTestApp.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData

@main
struct SwiftDataSupabaseSyncTestApp: App {
    
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
