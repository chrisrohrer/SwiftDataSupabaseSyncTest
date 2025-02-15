//
//  ContentView.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData
import Realtime


struct ContentView: View {
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            AutorenView()
                .tabItem { Label("Autoren", systemImage: "person") }

            BuecherView()
                .tabItem { Label("Bücher", systemImage: "book") }
        }

        .task {
            do {
                try await SupabaseSyncManager.shared.fetchRemoteChanges(modelContext: modelContext)
                try await SupabaseSyncManager.shared.uploadLocalChanges(modelContext: modelContext)
                SupabaseSyncManager.shared.startRealtimeSync(modelContext: modelContext)
                SwiftDataSyncManager.shared.setModelContext(modelContext)

            } catch {
                print("Error syncing on app launch: \(error)")
            }
        }
        
//        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
//            if let userInfo = notification.userInfo {
//                let inserted = (userInfo["inserted"] as? [PersistentIdentifier]) ?? []
//                let updated = (userInfo["updated"] as? [PersistentIdentifier]) ?? []
//                let deleted = (userInfo["deleted"] as? [PersistentIdentifier]) ?? []
//                
//                print("------ didSave")
//                print("inserted: ")
//                for item in inserted {
//                    let model = modelContext.model(for: item)
//                    if let book = model as? Buch {
//                        print(book.id, book.titel)
//                    }
//                    if let author = model as? Autor {
//                        print(author.id, author.name)
//                    }
//                }
//                print("updated: ")
//                for item in updated {
//                    let model = modelContext.model(for: item)
//                    if let book = model as? Buch {
//                        print(book.id, book.titel)
//                    }
//                    if let author = model as? Autor {
//                        print(author.id, author.name)
//                        author.isSynced = false
//                    }
//                }
//                print("deleted: ")
//                for item in deleted {
//                    let model = modelContext.model(for: item)
//                    if let book = model as? Buch {
//                        print(book.id, book.titel)
//                    }
//                    if let author = model as? Autor {
//                        print(author.id, author.name)
//                    }
//                }
//            }
//        }
    }
    

}


func fetchRecordByID<T: PersistentModel>(id: PersistentIdentifier, context: ModelContext) -> T? {
    return context.model(for: id) as? T
}



#Preview {
    ContentView()
        .modelContainer(MyPreviews.shared.container)
}
