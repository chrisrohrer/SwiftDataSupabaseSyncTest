//
//  Kunde.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import Foundation
import SwiftData
import Supabase
import Realtime


@Model
final class Buch {
    
    // Standards

    static let tableName: String = "Buch"
    @Attribute(.unique) var id: UUID = UUID()
    var updatedAt: Date = Date() // Letzter Sync-Zeitpunkt
    var isSynced: Bool = false // Kennzeichnet, ob die Änderung schon synchronisiert wurde

    // Attributes

    var titel: String = ""
    var seiten: Int = 0
    
    // Relations

    var autor: Autor?
    
    // Init

    internal init(titel: String = "", seiten: Int = 0, autor: Autor?) {
        self.titel = titel
        self.seiten = seiten
        self.autor = autor
    }

}

struct BuchRemote: Codable {
    var id: UUID
    var updatedAt: Date
    var isDeleted: Bool
    var titel: String
    var seiten: Int
    
    // foreign key reference from Supabase
    var autorID: UUID?
    
    static func createFrom(_ buch: Buch) -> Self {
        return .init(
            id: buch.id,
            updatedAt: buch.updatedAt,
            isDeleted: false,
            titel: buch.titel,
            seiten: buch.seiten,
            autorID: buch.autor?.id
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
        case titel
        case seiten
        case autorID = "autor_id"
    }
}


extension BuchRemote {
    
    func createOrUpdateBuch(modelContext: ModelContext) {
        
        let existingBuch = try? modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.id == self.id })).first
        
        let falseID = UUID()
        let autor = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == self.autorID ?? falseID })).first

        if let existingBuch {
            existingBuch.titel = self.titel
            existingBuch.seiten = self.seiten
            existingBuch.updatedAt = self.updatedAt
            existingBuch.autor = autor
            existingBuch.isSynced = true
            
        } else {
            if let autor {
                let newBuch = Buch(titel: self.titel, seiten: self.seiten, autor: autor)
                newBuch.id = self.id
                newBuch.updatedAt = self.updatedAt
                newBuch.isSynced = true
                modelContext.insert(newBuch)
            }
        }
    }

    func deleteBuch(modelContext: ModelContext) {
        if let buchToDelete = try? modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.id == self.id })).first {
            modelContext.delete(buchToDelete)
        }
    }

}




/*
extension Buch {
    
    // subscribe to Supabase Realtime Updates
    static func subscribe() {
        print("subscribed to", Self.tableName)
        Task {
            let myChannel = supabase.channel("realtime changes")
            let changes = myChannel.postgresChange(AnyAction.self, schema: "public", table: Self.tableName)
            await myChannel.subscribe()
            
            for await change in changes {
                print("change detected", Self.tableName)
                processChange(change)
            }
        }
    }
    
    static func processChange(_ change: AnyAction) {
        
        switch change {
        case .insert(let action):
            guard let table = action.rawMessage.payload["data"]?.objectValue?["table"]?.stringValue else { return }
//            if table != Self.tableName { return }
            let record = action.record
            print("insert", table, record)

        case .update(let action):
            guard let table = action.rawMessage.payload["data"]?.objectValue?["table"]?.stringValue else { return }
//            if table != Self.tableName { return }
            let record = action.record
            print("update", table, record)

        case .delete(let action):
            guard let table = action.rawMessage.payload["data"]?.objectValue?["table"]?.stringValue else { return }
//            if table != Self.tableName { return }
            let oldRecord = action.oldRecord
            print("delete", table, oldRecord)
        }
    }
}
*/
