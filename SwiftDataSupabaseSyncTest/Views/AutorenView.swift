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

    @Query(filter: #Predicate<Autor> { $0.softDeleted == false },
           sort: \Autor.name)
    private var autoren: [Autor]

    @State private var showNewSheet = false
    @State private var selectedAuthor: Autor.ID?
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedAuthor) {
                ForEach(autoren) { autor in
                    autorListCell(autor)
//                        .id(autor)
                }
                .onDelete(perform: deleteItems)
            }

            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Logout") { authVM.signOut() }
                    
                    Button("Full refresh", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                        UserDefaults.standard.set(Date.now.addingTimeInterval(-60*60*24*45), forKey: "lastSyncDate")

                        Task {
                            await SupabaseSyncManager.shared.performFullRefresh()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                }
                ToolbarItem {
                    Button("Add Item", systemImage: "plus") { showNewSheet = true }
                }
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
            }
            .navigationTitle("Autoren")
            
        } detail: {
            if let selectedAuthor, let autor = autoren[selectedAuthor] {
                AutorDetails(autor: autor)
            } else {
                Text("Autor auswählen")
            }
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
                    HStack {
                        Text(autor.updatedAt.formatted())
                        Text(autor.isSynced ? "synced" : "UNSYNCED")
                        Text(autor.softDeleted ? "deleted" : "alive").foregroundStyle(autor.softDeleted ? .red : .primary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .badge(autor.buecher?.count ?? 0)
        
            .contextMenu {
                Button("Löschen") {
                    autor.softDelete(modelContext: modelContext)
                    print("In Delete", autor.softDeleted)
                }
            }
    }

    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                autoren[index].softDelete(modelContext: modelContext)
            }
        }
    }

}


#Preview {
    AutorenView()
        .modelContainer(MyPreviews.shared.container)
}
