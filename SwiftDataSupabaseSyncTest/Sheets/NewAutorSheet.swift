//
//  NewProductSheet.swift
//  PraxisBestand
//
//  Created by Christoph Rohrer on 26.10.24.
//

import SwiftUI
import SwiftData


struct NewAutorSheet: View {
    
    @Environment(\.modelContext) private var modelContext

    @State private var autor = Autor()
    
    var body: some View {
        NewSheet(title: "Neuer Autor") {
            Section("Autor") {
                TextField("Name", text: $autor.name)
                    .font(.headline)
                TextField("Geburtsjahr", value: $autor.geburtsjahr, format: .number.grouping(.never))
            }
            
        } action: {
            withAnimation {
                modelContext.insert(autor)
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    NewAutorSheet()
        .modelContainer(MyPreviews.shared.container)
}
