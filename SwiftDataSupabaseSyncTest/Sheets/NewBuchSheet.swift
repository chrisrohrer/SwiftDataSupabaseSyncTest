//
//  NewProductSheet.swift
//  PraxisBestand
//
//  Created by Christoph Rohrer on 26.10.24.
//

import SwiftUI
import SwiftData


struct NewBuchSheet: View {
    
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Autor.name)
    private var autoren: [Autor]

    @State private var autor: Autor? = nil
    @State private var titel: String = ""
    @State private var seiten: Int = 0
    
    var body: some View {
        NewSheet(title: "Neues Buch") {
            Section("Buch") {
                TextField("Titel", text: $titel)
                    .font(.headline)
                TextField("Seiten", value: $seiten, format: .number)
                
                Picker("Autor", selection: $autor) {
                    Text("kein Autor").tag(nil as Autor?)
                    ForEach(autoren, id: \.self) { autor in
                        Text(autor.name).tag(autor as Autor?)
                    }
                }
            }
            
        } action: {
            withAnimation {
                let new = Buch(titel: titel, seiten: seiten, autor: autor!)
                modelContext.insert(new)
                try? modelContext.save()
            }
        } disabled: {
            autor == nil || titel.isEmpty
        }
    }
}

#Preview {
    NewBuchSheet()
        .modelContainer(MyPreviews.shared.container)
}
