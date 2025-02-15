//
//  AutorenView.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData

struct AutorenView: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthVM

    @Query(sort: \Autor.name)
    private var autoren: [Autor]

    @State private var showNewSheet = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(autoren) { autor in
                    NavigationLink {
                        AutorDetails(autor: autor)
                        
                    } label: {
                        autorListCell(autor)
                    }
                }
                .onDelete(perform: deleteItems)
            }

            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Logout") { authVM.signOut() }
                    
                    Button("Sync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                        Task {
                            try? await SupabaseSyncManager.shared.fetchRemoteChanges(modelContext: modelContext)
                            try? await SupabaseSyncManager.shared.uploadLocalChanges(modelContext: modelContext)
                        }
                    }
                }
                
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button("Add Item", systemImage: "plus") { showNewSheet = true }
                }
            }
            .navigationTitle("Autoren")
        } detail: {
            Text("Autor auswählen")
        }
        .sheet(isPresented: $showNewSheet) {
            NewAutorSheet()
        }
    }
    
    
    private func autorListCell(_ autor: Autor) -> some View {
            VStack(alignment: .leading) {
                Text(autor.name)
                    .font(.headline)
                Group {
                    Text(autor.geburtsjahr.formatted(.number.grouping(.never)))
                    Text(autor.updatedAt.formatted())
                    Text(autor.isSynced.description)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .badge(autor.buecher?.count ?? 0)
    }

    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(autoren[index])
            }
        }
    }

}


#Preview {
    AutorenView()
        .modelContainer(MyPreviews.shared.container)
}
