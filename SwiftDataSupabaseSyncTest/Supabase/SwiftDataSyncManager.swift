//
//  SwiftDataSyncManager.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 04.02.25.
//

import Foundation
import SwiftData
import Combine
import Supabase

@MainActor
final class SwiftDataSyncManager {
    static let shared = SwiftDataSyncManager()
    
    private var modelContext: ModelContext?
    private var cancellables: Set<AnyCancellable> = []
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        observeModelChanges()
    }
    
    private func observeModelChanges() {
        print(">>> SwiftDataSyncManager: Starting observing ...")
        NotificationCenter.default.publisher(for: ModelContext.willSave)
            .sink { [weak self] notification in
                
                if SupabaseSyncManager.shared.isSyncing {
                    print(">>> SwiftDataSyncManager: Supabase is syncing ... Not reacting to changes")
                    return
                }
                self?.handleModelChangesWillSave()
            }
            .store(in: &cancellables)
    }
    
    private func handleModelChangesWillSave() {
        print(">>> SwiftDataSyncManager ... handling change")
        
        guard let modelContext else {
            print("Error: no ModelContext")
            return
        }
        
        let inserted = modelContext.insertedModelsArray
        let updated = modelContext.changedModelsArray
        let deleted = modelContext.deletedModelsArray
        
        if inserted.isEmpty == false {
            print("--- inserted: ")
            for item in inserted {
                let model = modelContext.model(for: item.persistentModelID)

                if let book = model as? Buch {
                    print(book.id, book.titel)
                    book.updatedAt = .now
                    book.isSynced = false
                }

                if let author = model as? Autor {
                    print(author.id, author.name)
                    author.updatedAt = .now
                    author.isSynced = false
                }
            }
        }
        
        if updated.isEmpty == false {
            print("--- updated: ")
            for item in updated {

                let model = modelContext.model(for: item.persistentModelID)
                if let book = model as? Buch {
                    print(book.id, book.titel)
                    book.updatedAt = .now
                    book.isSynced = false
                }

                if let author = model as? Autor {
                    print(author.id, author.name)
                    author.updatedAt = .now
                    author.isSynced = false
                }
            }
        }
        
        if deleted.isEmpty == false {
            print("--- deleted: ")
            for item in deleted {
                let model = modelContext.model(for: item.persistentModelID)
                if let book = model as? Buch {
                    print(book.id, book.titel)
                }
                if let author = model as? Autor {
                    print(author.id, author.name)
                }
            }
        }
    }
    
    
    
    /*
     
     private func handleModelChangesDidSave(notification: Notification) {
         print("SwiftDataSyncManager ... change")
         
         guard let modelContext else {
             print("Error: no ModelContext")
             return
         }
         
         if let userInfo = notification.userInfo {
             let inserted = (userInfo["inserted"] as? [PersistentIdentifier]) ?? []
             let updated = (userInfo["updated"] as? [PersistentIdentifier]) ?? []
             let deleted = (userInfo["deleted"] as? [PersistentIdentifier]) ?? []
             
             //            let modelContext = try! ModelContainer(for: Buch.self, Autor.self).mainContext
             
             print("inserted: ")
             for item in inserted {
                 let model = modelContext.model(for: item)
                 if let book = model as? Buch {
                     print(book.id, book.titel)
                 }
                 if let author = model as? Autor {
                     print(author.id, author.name)
                 }
             }
             print("updated: ")
             for item in updated {
                 let model = modelContext.model(for: item)
                 if let book = model as? Buch {
                     print(book.id, book.titel)
                 }
                 if let author = model as? Autor {
                     print(author.id, author.name)
                     author.isSynced = false
                 }
             }
             print("deleted: ")
             for item in deleted {
                 let model = modelContext.model(for: item)
                 if let book = model as? Buch {
                     print(book.id, book.titel)
                 }
                 if let author = model as? Autor {
                     print(author.id, author.name)
                 }
             }
         }
         
     }
     
     

     
     */
}
