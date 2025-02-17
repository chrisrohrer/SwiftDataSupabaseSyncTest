//
//  SyncManager.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 01.02.25.
//

import Foundation
import Supabase
import SwiftData

//@MainActor
final class SupabaseSyncManager {
    
    static let shared = SupabaseSyncManager()
    
    private var modelContext: ModelContext? // ✅ Store ModelContext safely

    var isUploading = false
    var isDownloading = false

    // darf nur einer sein für alle Changes!
    private var subscriptionChannel: RealtimeChannelV2?
    
    // Sync alle 5 min
    private var syncTimer: Timer?
    private let syncTimeInterval = 60.0 // Sekunden

    private init() {}
    
    
    struct UpdatedAtRecord: Decodable {
        let updated_at: Date
    }

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    
    
    // MARK: - Upload Local Changes
    
    /// upload of all local changes to supabase, as defined by `model.isSynced == false`
    @MainActor
    func uploadLocalChanges() async throws {
        
        defer {
            isUploading = false // Reset the flag
        }
                
        guard let modelContext else {
            print("⚠️ SupabaseSyncManager: uploadLocalChanges: no ModelContext set!")
            return
        }
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
        
        if !unsyncedAutoren.isEmpty {
            
            print("--- upload Autoren")
            
            for autor in unsyncedAutoren {
                print("🚨 Uploading Autor:", autor.name, "isDeleted:", autor.softDeleted)

                // 🔍 Fetch the latest `updated_at` from Supabase before upserting
                let latestServerRecord: [UpdatedAtRecord] = try await supabase
                    .from("Autor")
                    .select("updated_at")
                    .eq("id", value: autor.id.uuidString)
                    .execute()
                    .value
                
                if let serverAutor = latestServerRecord.first,
                   serverAutor.updated_at > autor.updatedAt {
                    
                    print("⚠️ Conflict detected for \(autor.name), skipping upload")
                    continue //  Don't upload if the server version is newer
                }

                let autorRemote = AutorRemote.createFrom(autor)
                print("Autor", autor.softDeleted)
                print("AutorRemote", autorRemote.softDeleted)
                let response = try await supabase
                    .from("Autor")
                    .upsert(autorRemote)
                    .execute()

                if response.status == 201 || response.status == 200 || response.status == 204 {
                    autor.isSynced = true
                } else {
                    print("Failed to upload Autor: \(response)")
                }
            }
        }
        
        
        if !unsyncedBuecher.isEmpty {
            
            print("--- upload Bücher")
            
            for buch in unsyncedBuecher {
                // 🔍 Fetch the latest `updated_at` from Supabase before upserting
                let latestServerRecord: [UpdatedAtRecord] = try await supabase
                    .from("Buch")
                    .select("updated_at")
                    .eq("id", value: buch.id.uuidString)
                    .execute()
                    .value

                if let serverBuch = latestServerRecord.first,
                    serverBuch.updated_at > buch.updatedAt {
                    print("⚠️ Conflict detected for \(buch.titel), skipping upload")
                    continue //  Don't upload if the server version is newer
                }

                let buchRemote = BuchRemote.createFrom(buch)
                let response = try await supabase
                    .from("Buch")
                    .upsert(buchRemote)
                    .execute()

                // wenn ok, dann isSynced setzen
                if response.status == 201 || response.status == 200 || response.status == 204 {
                    buch.isSynced = true
                } else {
                    print("Failed to upload Buch: \(response)")
                }
            }
            
            
        }
                        
        try modelContext.save()

        isUploading = false // Reset the flag
    }
    
    
    
    // MARK: - Fetch Remote Changes
    
    /// one time fetch of all  changes in supabase to swiftdata, called manually
    @MainActor
    func fetchRemoteChanges() async throws {
        
        if isDownloading { return }

        defer {
            isDownloading = false
        }

        isDownloading = true
        
        print("⤵️ SupabaseSyncManager: fetchRemoteChanges")
        
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date ?? Date.distantPast
//        print("****", lastSyncDate)
        let daysSinceLastSync = Calendar.current.dateComponents([.day], from: lastSyncDate, to: Date()).day ?? 100
//        print("****", daysSinceLastSync)
        if daysSinceLastSync > 30 {
            print("🔄 User inactive for \(daysSinceLastSync) days. Performing full refresh...")
            await performFullRefresh()
        } else {
            await performIncrementalSync(lastSyncDate: lastSyncDate)
        }
        
        isDownloading = false

    }
    
    /// only called manually from Button – or when lastSync is more than 30 days away in `fetchRemoteChanges`
    ///
    func performFullRefresh() async {
        guard let modelContext else {
            print("⚠️ SupabaseSyncManager: uploadLocalChanges: no ModelContext set!")
            return
        }

        do {
            isDownloading = true
            
            print("🗑️ Deleting all local data...")
            
            try modelContext.delete(model: Autor.self)
            try modelContext.delete(model: Buch.self)
            try modelContext.save()

            print("🔄 Resetting sync date before fetching fresh data...")
            UserDefaults.standard.set(Date.distantPast, forKey: "lastSyncDate") // ✅ Reset sync date

            print("🔄 Fetching fresh data from Supabase...")
            await performIncrementalSync(lastSyncDate: .distantPast)

            print("✅ Full refresh complete!")
            isDownloading = false
        } catch {
            print("❌ Error during full refresh: \(error)")
            isDownloading = false
        }
    }

    @MainActor
    private func performIncrementalSync(lastSyncDate: Date) async {
        guard let modelContext else {
            print("⚠️ SupabaseSyncManager: uploadLocalChanges: no ModelContext set!")
            return
        }

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
                remoteAutor.createOrUpdateAutor(modelContext: modelContext)
            }
            
            // Store Bücher
            for remoteBuch in buchResponse {
                print("--- download Buch", remoteBuch.titel)
                remoteBuch.createOrUpdateBuch(modelContext: modelContext)
            }
            
            try modelContext.save()
            
            // only set lastsyncdate when successful
            UserDefaults.standard.set(Date(), forKey: "lastSyncDate")
            
        } catch {
            print("❌ Error during incremental sync: \(error)")
        }

    }
    
    
    
    
    
    
    
    // MARK: - Start Listening for Realtime Updates
    
    /// start listening to realtime changes in supabase
    /// can only be one channel!
    func startRealtimeSync() {
        
        print("🔄 SupabaseSyncManager: Starting sync ...")

        Task {
            await subscribeToChanges()
        }
        
        // Initialize the periodic sync timer
        DispatchQueue.main.async { [weak self] in
            self?.syncTimer = Timer.scheduledTimer(withTimeInterval: self?.syncTimeInterval ?? 10, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return } // ✅ Ensure `self` is available
                    if self.isUploading || self.isDownloading { return }
                    await self.performBackgroundSync()
                }
            }
        }
    }
    
    private func performBackgroundSync() async {
        do {
            print("⏳ Performing periodic sync...")
            try await fetchRemoteChanges()
            try await uploadLocalChanges()
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
    private func subscribeToChanges() async {
        subscriptionChannel = supabase.channel("realtime")
        let changeStream = subscriptionChannel!.postgresChange(AnyAction.self, schema: "public")
        await subscriptionChannel!.subscribe()
        
        for await change in changeStream {
            
            if self.isDownloading {
//                print("<<< SupabaseSyncManager: is syncing ...")
            } else {
                
                print("⤵️ SupabaseSyncManager: Change detected", change.rawMessage.payload)
                self.isDownloading = true
                Task { @MainActor in
                    defer { self.isDownloading = false } // Ensure reset even if error occurs
                    self.handleChange(change: change)
                }
            }
        }
    }
    
    
    // MARK: - Handle Changes (Insert, Update, Delete)
    
    /// handles all changes: insert, update, delete from Supabase subscription
    /// for all tables
    @MainActor
    private func handleChange(change: AnyAction) {
        
        guard let modelContext else {
            print("⚠️ SupabaseSyncManager: uploadLocalChanges: no ModelContext set!")
            return
        }

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
                
                
            // actually not used, because we use Soft Delete
            case .delete(let action):
                print("⚠️ Delete Should never be called")
                /*
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
                 */
            }
        } catch {
            print("⚠️ Error: \(error)")
        }
        
    }
    
    
    
}

