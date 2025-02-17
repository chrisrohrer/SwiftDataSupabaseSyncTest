//
//  AutorDetails.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData

struct BuchDetails: View {
    
    @Bindable var buch: Buch
    
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Autor> { $0.softDeleted == false },
           sort: \Autor.name)
    private var autoren: [Autor]

    var body: some View {
        
        Form {
            
            TextField("Titel", text: $buch.titel)
            TextField("Seiten", value: $buch.seiten, format: .number.grouping(.never))

            Picker("Autor", selection: $buch.autor) {
                Text("kein Autor").tag(nil as Autor?)
                ForEach(autoren, id: \.self) { autor in
                    Text(autor.name).tag(autor as Autor?)
                }
            }
            Spacer()
            
            Button("Save") { try? modelContext.save() }

        }
        .navigationTitle(buch.titel)
        .padding()
    }
}



#Preview {
    AutorDetails(autor: MyPreviews.shared.autor)
}
