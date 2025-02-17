//
//  AutorenView.swift
//  SwiftDataSupabaseSyncTest
//
//  Created by Christoph Rohrer on 26.01.25.
//

import SwiftUI
import SwiftData

struct BuecherView: View {
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authVM: AuthVM

    @Query(filter: #Predicate<Buch> { $0.softDeleted == false },
           sort: \Buch.titel)
    private var buecher: [Buch]

    @State private var showNewSheet = false
    @State private var selectedBuch: Buch?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedBuch) {
                ForEach(buecher) { buch in
                    buchListCell(buch)
                        .id(buch)
                }
                .onDelete(perform: deleteItems)
            }

            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button("Logout") { authVM.signOut() }
                    
                    Button("Sync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                        Task {
                            try? await SupabaseSyncManager.shared.fetchRemoteChanges()
                            try? await SupabaseSyncManager.shared.uploadLocalChanges()
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
            .navigationTitle("Bücher")
            
        } detail: {
            if let selectedBuch {
                BuchDetails(buch: selectedBuch)
            } else {
                Text("Buch auswählen")
            }
        }
        .sheet(isPresented: $showNewSheet) {
            NewBuchSheet()
        }
    }
    
    
    private func buchListCell(_ buch: Buch) -> some View {
            VStack(alignment: .leading) {
                Text(buch.titel)
                    .font(.headline)
                Text(buch.autor?.name ?? "unbekannt")
                Group {
                    Text(buch.seiten.formatted())
                    Text(buch.updatedAt.formatted())
                    Text(buch.isSynced.description)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                .contextMenu {
                    Button("Löschen") {
                        buch.softDelete(modelContext: modelContext)
                    }
                }

            }
    }

    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(buecher[index])
            }
        }
    }

}

#Preview {
    BuecherView()
        .modelContainer(MyPreviews.shared.container)
}
