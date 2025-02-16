//
//  SyncManager.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 01.02.25.
//

import Foundation
import Supabase
import SwiftData


final class SupabaseSyncManager {
    
    static let shared = SupabaseSyncManager()
    
    private var modelContext: ModelContext? // ✅ Store ModelContext safely

    var isSyncing = false
    var isUploading = false // 🚀 NEW FLAG
    var isDownloading = false // 🚀 NEW FLAG

    // darf nur einer sein für alle Changes!
    private var subscriptionChannel: RealtimeChannelV2?
    
    // Sync alle 5 min
    private var syncTimer: Timer?
    private let syncTimeInterval = 60.0 // Sekunden

    private init() {}
    
    
    // MARK: - Upload Local Changes
    
    /// one time upload of all local changes to supabase, called manually
    @MainActor
    func uploadLocalChanges(modelContext: ModelContext) async throws {
        
        if isUploading { return }
        isUploading = true

        try modelContext.save()
        
        let unsyncedAutoren = try modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.isSynced == false }))
        let unsyncedBuecher = try modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.isSynced == false }))
        
        if unsyncedAutoren.isEmpty && unsyncedBuecher.isEmpty {
            isUploading = false
            return
        }

        print("⤴️ SupabaseSyncManager: uploadLocalChanges")

        let remoteAutoren: [AutorRemote] = unsyncedAutoren.map { AutorRemote.createFrom($0) }
        let remoteBuecher: [BuchRemote] = unsyncedBuecher.map { BuchRemote.createFrom($0) }
        
        isSyncing = true

        if !remoteAutoren.isEmpty {
            
            print("--- upload Autoren")
            
            let response = try await supabase
                .from("Autor")
                .upsert(remoteAutoren)
                .execute()
            
            if response.status == 201 || response.status == 200 { // Only mark as synced if successful
                for autor in unsyncedAutoren { autor.isSynced = true }
            } else {
                print("Failed to upload Autoren: \(response)")
            }
        }
        
        if !remoteBuecher.isEmpty {
            
            print("--- upload Bücher")
            
            let response = try await supabase
                .from("Buch")
                .upsert(remoteBuecher)
                .execute()
            
            if response.status == 201 || response.status == 200 {
                for buch in unsyncedBuecher { buch.isSynced = true }
            } else {
                print("Failed to upload Bücher: \(response)")
            }
        }
                        
        try modelContext.save()
        
        isSyncing = false
        isUploading = false // Reset the flag
    }
    
    
    
    // MARK: - Fetch Remote Changes
    
    /// one time fetch of all  changes in supabase to swiftdata, called manually
    @MainActor
    func fetchRemoteChanges(modelContext: ModelContext) async throws {
        
        if isSyncing || isDownloading { return }
        isSyncing = true
        isDownloading = true
        
        print("⤵️ SupabaseSyncManager: fetchRemoteChanges")
        
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
        let daysSinceLastSync = Calendar.current.dateComponents([.day], from: lastSyncDate, to: Date()).day ?? 0
        
        if daysSinceLastSync > 30 {
            print("🔄 User inactive for \(daysSinceLastSync) days. Performing full refresh...")
            await performFullRefresh(modelContext: modelContext)
        } else {
            print("⤵️ Performing incremental sync...")
            await performIncrementalSync(modelContext: modelContext, lastSyncDate: lastSyncDate)
        }
        
        UserDefaults.standard.set(Date(), forKey: "last_sync_date")

        isSyncing = false
        isSyncing = false
        isDownloading = false

    }
    
    @MainActor
    private func performFullRefresh(modelContext: ModelContext) async {
        do {
            print("🗑️ Deleting all local data...")
            
            try modelContext.delete(model: Autor.self)
            try modelContext.delete(model: Buch.self)

            try modelContext.save()

            print("🔄 Fetching fresh data from Supabase...")
            await performIncrementalSync(modelContext: modelContext, lastSyncDate: nil)

            print("✅ Full refresh complete!")
        } catch {
            print("❌ Error during full refresh: \(error)")
        }
    }

        
    @MainActor
    private func performIncrementalSync(modelContext: ModelContext, lastSyncDate: Date?) async {
        do {
            // Fetch Autoren
            let autorResponse: [AutorRemote] = try await supabase
                .from("Autor")
                .select()
                .gte("updated_at", value: lastSyncDate)
                .execute()
                .value
            
            // Fetch Bücher
            let buchResponse: [BuchRemote] = try await supabase
                .from("Buch")
                .select()
                .gte("updated_at", value: lastSyncDate)
                .execute()
                .value
            
            // Store Autoren
            for remoteAutor in autorResponse {
                print("--- download Autor", remoteAutor.name)
                if remoteAutor.isDeleted {
                    remoteAutor.deleteAutor(modelContext: modelContext)
                } else {
                    remoteAutor.createOrUpdateAutor(modelContext: modelContext)
                }
            }
            
            // Store Bücher
            for remoteBuch in buchResponse {
                print("--- download Buch", remoteBuch.titel)
                if remoteBuch.isDeleted {
                    remoteBuch.deleteBuch(modelContext: modelContext)
                } else {
                    remoteBuch.createOrUpdateBuch(modelContext: modelContext)
                }
            }
            
            try modelContext.save()
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
            
        } catch {
            print("❌ Error during incremental sync: \(error)")
        }

    }
    
    
    
    
    
    
    
    // MARK: - Start Listening for Realtime Updates
    
    /// start listening to realtime changes in supabase
    /// can only be one channel!
    func startRealtimeSync(modelContext: ModelContext) {
        print("🔄 SupabaseSyncManager: Starting sync ...")
        self.modelContext = modelContext

        Task {
            await subscribeToChanges(modelContext: modelContext)
        }
        
        // Initialize the periodic sync timer
        DispatchQueue.main.async { [weak self] in
            self?.syncTimer = Timer.scheduledTimer(withTimeInterval: self?.syncTimeInterval ?? 300, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return } // ✅ Ensure `self` is available
                    if self.isUploading || self.isDownloading { return }
                    await self.performBackgroundSync()
                }
            }
        }
    }
    
    @MainActor
    private func performBackgroundSync() async {
        guard let modelContext = modelContext else {
            print("❌ Error: ModelContext is not set")
            return
        }
        do {
            print("⏳ Performing periodic sync...")
            try await fetchRemoteChanges(modelContext: modelContext)
            try await uploadLocalChanges(modelContext: modelContext)
        } catch {
            print("❌ Error during periodic sync: \(error)")
        }
    }

    
    
    
    func stopRealtimeSync() {
        subscriptionChannel = nil

        // Invalidate the periodic sync timer
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Subscribe to Changes from Supabase via Listener
    
    /// start listening to realtime changes in supabase
    /// can only be one channel!
    /// delivers changes to "handleChange"
    private func subscribeToChanges(modelContext: ModelContext) async {
        subscriptionChannel = supabase.channel("realtime")
        let changeStream = subscriptionChannel!.postgresChange(AnyAction.self, schema: "public")
        await subscriptionChannel!.subscribe()
        
        for await change in changeStream {
            
            if self.isSyncing {
//                print("<<< SupabaseSyncManager: is syncing ...")
            } else {
                
                print("⤵️ SupabaseSyncManager: Change detected", change.rawMessage.payload)
                self.isSyncing = true
                Task { @MainActor in
                    self.handleChange(change: change, modelContext: modelContext)
                    self.isSyncing = false
                }
            }
        }
    }
    
    
    // MARK: - Handle Changes (Insert, Update, Delete)
    
    /// handles all changes: insert, update, delete from Supabase subscription
    /// for all tables
    @MainActor
    private func handleChange(change: AnyAction, modelContext: ModelContext) {
        
        guard let table = change.rawMessage.payload["data"]?.objectValue?["table"]?.stringValue else {
            print("⚠️ Table name missing in change event:", change.rawMessage.payload)
            return
        }
        
        do {
            switch change {
            case .insert(let action):
                let jsonObject = action.record
                switch table {
                case "Autor":
                    let newAutor = try jsonObject.decode(as: AutorRemote.self)
                    newAutor.createOrUpdateAutor(modelContext: modelContext)
                    print("--- insert Autor", newAutor.name)

                case "Buch":
                    let newBuch = try jsonObject.decode(as: BuchRemote.self)
                    newBuch.createOrUpdateBuch(modelContext: modelContext)
                    print("--- insert Buch", newBuch.titel)

                default:
                    print("⚠️ Unknown table: \(table)")
                }
                
                try modelContext.save()
                
                
            case .update(let action):
                let jsonObject = action.record
                switch table {
                case "Autor":
                    let updatedAutor = try jsonObject.decode(as: AutorRemote.self)
                    // Soft Delete
                    if updatedAutor.isDeleted {
                        if let autorToDelete = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == updatedAutor.id })).first {
                            print("--- delete Autor", autorToDelete.name)
                            modelContext.delete(autorToDelete)
                        }
                    } else {
                        updatedAutor.createOrUpdateAutor(modelContext: modelContext)
                        print("--- update Autor", updatedAutor.name)
                    }
                    
                case "Buch":
                    let updatedBuch = try jsonObject.decode(as: BuchRemote.self)
                    // Soft Delete
                    if updatedBuch.isDeleted {
                        if let buchToDelete = try? modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.id == updatedBuch.id })).first {
                            print("--- delete Buch", buchToDelete.titel)
                            modelContext.delete(buchToDelete)
                        }
                    } else {
                        updatedBuch.createOrUpdateBuch(modelContext: modelContext)
                        print("--- update Buch", updatedBuch.titel)
                    }
                default:
                    print("⚠️ Unknown table: \(table)")
                }
                
                try modelContext.save()
                
                
            // actually not used, because we use Soft Delete
            case .delete(let action):
                guard let idString = action.oldRecord["id"]?.stringValue, let id = UUID(uuidString: idString) else {
                    print("⚠️ Error: Failed to extract UUID from delete action: \(action.oldRecord)")
                    return
                }
                
                switch table {
                case "Autor":
                    if let autorToDelete = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == id })).first {
                        print("--- delete Autor", autorToDelete.name)
                        modelContext.delete(autorToDelete)
                    }
                    
                case "Buch":
                    if let buchToDelete = try? modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.id == id })).first {
                        print("--- delete Buch", buchToDelete.titel)
                        modelContext.delete(buchToDelete)
                    }
                default:
                    print("⚠️ Unknown table for delete: \(table)")
                }
                
                try? modelContext.save()
            }
        } catch {
            print("⚠️ Error: \(error)")
        }
        
    }
    
    
    
}

