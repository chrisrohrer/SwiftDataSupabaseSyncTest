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

// SwiftData Model
@Model
final class Autor {
    
    // Standards
    
    static let tableName: String = "Autor"
    
    @Attribute(.unique) var id: UUID = UUID()
    var updatedAt: Date = Date()
    var isSynced: Bool = false // Kennzeichnet, ob die Änderung schon synchronisiert wurde

    // Attributes
    
    var name: String = ""
    var geburtsjahr: Int = 1900
    
    // Relations

    @Relationship(deleteRule: .cascade, inverse: \Buch.autor)
    var buecher: [Buch]?
    
    // Init
    
    internal init(name: String = "", geburtsjahr: Int = 1900) {
        self.name = name
        self.geburtsjahr = geburtsjahr
    }
    

}




struct AutorRemote: Codable {
    var id: UUID
    var updatedat: Date
    var issynced: Bool

    var name: String
    var geburtsjahr: Int
    
    
    static func createFrom(_ autor: Autor) -> Self {
        return .init(
            id: autor.id,
            updatedat: autor.updatedAt,
            issynced: autor.isSynced,
            name: autor.name,
            geburtsjahr: autor.geburtsjahr
        )
    }
    
    func createOrUpdateAutor(modelContext: ModelContext) {
        
        let existingAutor = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == self.id })).first
        
        if let existingAutor {
            existingAutor.name = self.name
            existingAutor.geburtsjahr = self.geburtsjahr
            existingAutor.updatedAt = self.updatedat
            existingAutor.isSynced = true
        } else {
            let newAutor = Autor(name: self.name, geburtsjahr: self.geburtsjahr)
            newAutor.id = self.id
            newAutor.updatedAt = self.updatedat
            newAutor.isSynced = true
            modelContext.insert(newAutor)
        }
    }
}








extension Autor {
    
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
        
        print("processing change")
        
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
