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
    
    var isSyncing = false
    var isUploading = false // 🚀 NEW FLAG

    // darf nur einer sein für alle Changes!
    private var subscriptionChannel: RealtimeChannelV2?
    
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
        
        let remoteAutoren: [AutorRemote] = unsyncedAutoren.map { AutorRemote.createFrom($0) }
        let remoteBuecher: [BuchRemote] = unsyncedBuecher.map { BuchRemote.createFrom($0) }
        
        print("⤴️ SupabaseSyncManager: uploadLocalChanges")
        
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
                
        for autor in unsyncedAutoren { autor.isSynced = true }
        for buch in unsyncedBuecher { buch.isSynced = true }
        
        try modelContext.save()
        
        isSyncing = false
        isUploading = false // Reset the flag
    }
    
    
    
    // MARK: - Fetch Remote Changes
    
    /// one time fetch of all  changes in supabase to swiftdata, called manually
    @MainActor
    func fetchRemoteChanges(modelContext: ModelContext) async throws {
        
        print("⤵️ SupabaseSyncManager: fetchRemoteChanges")
        
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
        
        // Fetch Autoren
        let autorResponse: [AutorRemote] = try await supabase
            .from("Autor")
            .select()
            .gte("updatedat", value: lastSyncDate)
            .execute()
            .value
        
        // Fetch Bücher
        let buchResponse: [BuchRemote] = try await supabase
            .from("Buch")
            .select()
            .gte("updatedat", value: lastSyncDate)
            .execute()
            .value
        
        isSyncing = true
        
        // Store Autoren
        for remoteAutor in autorResponse {
            print("--- download Autor", remoteAutor.name)
            remoteAutor.createOrUpdateAutor(modelContext: modelContext)
        }
        
        // Store Bücher
        for remoteBuch in buchResponse {
            print("--- download Buch", remoteBuch.titel)
            remoteBuch.createOrUpdateBuch(modelContext: modelContext)
        }
        
        try modelContext.save()
        UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
        
        isSyncing = false
    }
    
    
    // MARK: - Start Listening for Realtime Updates
    
    /// start listening to realtime changes in supabase
    /// can only be one channel!
    func startRealtimeSync(modelContext: ModelContext) {
        print("🔄 SupabaseSyncManager: Starting sync ...")
        Task {
            await subscribeToChanges(modelContext: modelContext)
        }
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
                    updatedAutor.createOrUpdateAutor(modelContext: modelContext)
                    print("--- update Autor", updatedAutor.name)

                case "Buch":
                    let updatedBuch = try jsonObject.decode(as: BuchRemote.self)
                    updatedBuch.createOrUpdateBuch(modelContext: modelContext)
                    print("--- update Buch", updatedBuch.titel)

                default:
                    print("⚠️ Unknown table: \(table)")
                }
                
                try modelContext.save()
                
                
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

