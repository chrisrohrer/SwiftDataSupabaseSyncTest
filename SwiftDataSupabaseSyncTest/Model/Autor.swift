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
    var updatedAt: Date = Date() // Letzter Sync-Zeitpunkt
    var isSynced: Bool = false // Kennzeichnet, ob die Änderung schon synchronisiert wurde
    var softDeleted: Bool = false // Soft delete flag

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
    
    func softDelete(modelContext: ModelContext) {
        self.softDeleted = true
        self.updatedAt = .now
        self.isSynced = false
        
        // für jede Relation!
        for buch in self.buecher ?? [] {
            buch.softDelete(modelContext: modelContext)
        }
        
        do {
            try modelContext.save()
        } catch {
            print(#function, error)
        }
    }

}




struct AutorRemote: Codable {
    var id: UUID
    var updatedAt: Date
    var softDeleted: Bool
    var name: String
    var geburtsjahr: Int
    
    
    static func createFrom(_ autor: Autor) -> Self {
        return .init(
            id: autor.id,
            updatedAt: autor.updatedAt,
            softDeleted: autor.softDeleted,
            name: autor.name,
            geburtsjahr: autor.geburtsjahr
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case updatedAt = "updated_at"
        case softDeleted = "is_deleted"
        case name
        case geburtsjahr
    }
}


extension AutorRemote {
    
    @MainActor
    func createOrUpdateAutor(modelContext: ModelContext) {
        
        let existingAutor = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == self.id })).first
        
        if let existingAutor {
            existingAutor.name = self.name
            existingAutor.geburtsjahr = self.geburtsjahr
            existingAutor.updatedAt = self.updatedAt
            existingAutor.isSynced = true
            existingAutor.softDeleted = self.softDeleted
        } else {
            let newAutor = Autor(name: self.name, geburtsjahr: self.geburtsjahr)
            newAutor.id = self.id
            newAutor.updatedAt = self.updatedAt
            newAutor.isSynced = true
            newAutor.softDeleted = self.softDeleted
            modelContext.insert(newAutor)
        }
    }
    
//    func deleteAutor(modelContext: ModelContext) {
//        if let autorToDelete = try? modelContext.fetch(FetchDescriptor<Autor>(predicate: #Predicate { $0.id == self.id })).first {
//            autorToDelete.softDeleted = true
//            autorToDelete.updatedAt = self.updatedAt
//            autorToDelete.isSynced = true
//        }
//    }
}







/*
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
*/
