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
#if os(macOS)
import AppKit
#endif

/// A singleton class responsible for syncing local SwiftData changes with Supabase.
/// - It observes changes in the `ModelContext` and uploads unsynced data to Supabase.
/// - Uses `Combine` to listen for `willSave` notifications and trigger data sync.
/// - It listens for app termination on macOS to ensure data is uploaded before quitting.
//@MainActor
final class SwiftDataSyncManager {
    static let shared = SwiftDataSyncManager()
    
    private var modelContext: ModelContext? // ✅ Store ModelContext safely
    private var cancellables: Set<AnyCancellable> = []
    
#if os(macOS)
    init() {
        // Try save on app quit
//        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
    }
#endif
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    
    /// Starts observing changes in the given `ModelContext`.
    /// - Parameter context: The `ModelContext` to observe (must come from a View)
    func startObservingContext() {
        print("🔄 SwiftDataSyncManager: Starting observing ...")
//        self.modelContext = context
        observeModelChanges()
    }
    
    
    // MARK: - private funcs
    
    /// Observes `willSave` notifications from the `ModelContext`.
    /// This ensures that changes in SwiftData are detected and marked for synchronization.
    private func observeModelChanges() {

        NotificationCenter.default.publisher(for: ModelContext.willSave)
            .sink { [weak self] notification in
                
                if SupabaseSyncManager.shared.isUploading || SupabaseSyncManager.shared.isDownloading {
//                    print("🔀 SwiftDataSyncManager: Supabase is syncing ... Not reacting to changes")
                    return
                }
                
                // handle the change and mark respective records as unsynced
                self?.handleModelChangesWillSave()
                
                // Call upload after marking as unsynced
                Task {
                    do {
                        if !SupabaseSyncManager.shared.isUploading {
                            print("🔀 SwiftDataSyncManager: uploading to Supabase")
                            try await SupabaseSyncManager.shared.uploadLocalChanges()
                        }
                    } catch {
                        print("❌ Error uploading local changes: \(error)")
                    }
                }

            }
            .store(in: &cancellables)
    }
    
    
    private func handleModelChangesWillSave() {
        if SupabaseSyncManager.shared.isUploading || SupabaseSyncManager.shared.isDownloading {
            return
        }
        
        guard let modelContext else {
            print("Error: no ModelContext")
            return
        }
        
        let inserted = modelContext.insertedModelsArray
        let updated = modelContext.changedModelsArray
        let deleted = modelContext.deletedModelsArray

        if (inserted + updated + deleted).isEmpty {
            return
        }
        
        print("🔁 SwiftDataSyncManager ... handling change")
        
        if inserted.isEmpty == false {
            print("--- inserted: ")
            for item in inserted {
                let model = modelContext.model(for: item.persistentModelID)

                if let book = model as? Buch {
//                    if book.isSynced {
                        print(book.id, book.titel)
                        book.updatedAt = .now
                        book.isSynced = false
//                    }
                }
                
                if let author = model as? Autor {
//                    if author.isSynced {
                    print(author.id, author.name, author.softDeleted)
                        author.updatedAt = .now
                        author.isSynced = false
//                    }
                }
            }
        }
        
        if updated.isEmpty == false {
            print("--- updated: ")
            for item in updated {

                let model = modelContext.model(for: item.persistentModelID)
                if let book = model as? Buch {
//                    if book.isSynced {
                        print(book.id, book.titel)
                        book.updatedAt = .now
                        book.isSynced = false
//                    }
                }
                
                if let author = model as? Autor {
//                    if author.isSynced {
                    print(author.id, author.name, author.softDeleted)
                        author.updatedAt = .now
                        author.isSynced = false
//                    }
                }
            }
        }
        
        // Should never be called, because of SoftDelete
        if deleted.isEmpty == false {
            print("--- deleted: ")
            for item in deleted {
                let model = modelContext.model(for: item.persistentModelID)
                if let book = model as? Buch {
                    if book.isSynced {
                        print(book.id, book.titel)
                        book.softDeleted = true
                        book.updatedAt = .now
                        book.isSynced = false
                    }
                }
                if let author = model as? Autor {
                    print(author.id, author.name)
                }
            }
        }
    }
    
    
    @objc private func appWillTerminate() {
        guard let modelContext = self.modelContext else { return }

        print("🔄 App is quitting: Attempting to upload unsynced changes...")

        let taskID = ProcessInfo.processInfo.beginActivity(options: .background, reason: "Uploading pending changes before quitting")

        Task { @MainActor in
            do {
                try modelContext.save() // ✅ Ensure local save
                try await SupabaseSyncManager.shared.uploadLocalChanges()
                print("✅ All changes uploaded before quitting")
            } catch {
                print("❌ Error uploading data before quitting: \(error)")
            }

            ProcessInfo.processInfo.endActivity(taskID) // ✅ Allow quitting after best-effort upload
        }

        print("🛑 App is quitting now. Best-effort sync completed. Any remaining uploads will continue on next launch.")
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
