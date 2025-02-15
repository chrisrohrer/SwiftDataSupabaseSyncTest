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
    
    internal init(titel: String = "", seiten: Int = 0, autor: Autor?) {
        self.titel = titel
        self.seiten = seiten
        self.autor = autor
    }
    
    static let tableName: String = "Buch"

    @Attribute(.unique) var id: UUID = UUID()
    var updatedAt: Date = Date()
    var isSynced: Bool = false // Kennzeichnet, ob die Änderung schon synchronisiert wurde

    var titel: String = ""
    var seiten: Int = 0
    
    var autor: Autor?
    
}

struct BuchRemote: Codable {
    var id: UUID
    var updatedat: Date
    var issynced: Bool
    
    var titel: String
    var seiten: Int
    
    // foreign key reference from Supabase
    var autorid: UUID?
    
    static func createFrom(_ buch: Buch) -> Self {
        return .init(
            id: buch.id,
            updatedat: buch.updatedAt,
            issynced: buch.isSynced,
            titel: buch.titel,
            seiten: buch.seiten,
            autorid: buch.autor?.id
        )
    }
    
    func createOrUpdateBuch(modelContext: ModelContext) {
        
        let existingBuch = try? modelContext.fetch(FetchDescriptor<Buch>(predicate: #Predicate { $0.id == self.id })).first
        
        let falseID = UUID()
        let autor = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == self.autorid ?? falseID })).first

        if let existingBuch {
            existingBuch.titel = self.titel
            existingBuch.seiten = self.seiten
            existingBuch.updatedAt = self.updatedat
            existingBuch.autor = autor
            existingBuch.isSynced = true
            
        } else {
            if let autor {
                let newBuch = Buch(titel: self.titel, seiten: self.seiten, autor: autor)
                newBuch.id = self.id
                newBuch.updatedAt = self.updatedat
                newBuch.isSynced = true
                modelContext.insert(newBuch)
            }
        }
    }

}





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
