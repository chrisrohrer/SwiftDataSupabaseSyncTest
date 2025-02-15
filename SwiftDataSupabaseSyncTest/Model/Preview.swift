//
//  Preview.swift
//  PraxisBestand
//
//  Created by Christoph Rohrer on 26.10.24.
//

import Foundation
import SwiftData


@MainActor
class MyPreviews {
    
    static let shared = MyPreviews()
    
    let container: ModelContainer
    let autor: Autor
    let buch: Buch
    
    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(
                for: Autor.self,
                Buch.self,
                configurations: config)
            
            autor = Autor(name: "Herman Müller", geburtsjahr: 1964)
            container.mainContext.insert(autor)

            buch = Buch(titel: "Der schwarze Tod in Europa", seiten: 123, autor: autor)
            container.mainContext.insert(buch)

            let buch2 = Buch(titel: "Der weiße Hase", seiten: 456, autor: autor)
            container.mainContext.insert(buch2)


            let autor2 = Autor(name: "Leo Tolstoi", geburtsjahr: 1810)
            container.mainContext.insert(autor2)

            let buch3 = Buch(titel: "Anna Karenina", seiten: 1234, autor: autor2)
            container.mainContext.insert(buch3)

            let buch4 = Buch(titel: "Krieg und Frieden", seiten: 2345, autor: autor2)
            container.mainContext.insert(buch4)

        } catch {
            fatalError("Failed to create Preivew model container")
        }
    }
    
}
