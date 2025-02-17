//
//  AutorDetails.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData

struct AutorDetails: View {
    
    @Bindable var autor: Autor
    
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        
        Form {
            
            TextField("Name", text: $autor.name)
            TextField("Geburtsjahr", value: $autor.geburtsjahr, format: .number.grouping(.never))

            Section("Bücher") {
                List(autor.buecher ?? []) { buch in
                    VStack(alignment: .leading) {
                        Text(buch.titel)
                            .font(.headline)
                        Text(buch.autor?.name ?? "unbekannt")
                        Text(buch.seiten.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Button("Save") { try? modelContext.save() }
        }
        .navigationTitle(autor.name)
        .padding()
    }
}



#Preview {
    AutorDetails(autor: MyPreviews.shared.autor)
}
