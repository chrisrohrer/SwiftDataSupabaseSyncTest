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

    @Query(sort: \Buch.titel)
    private var buecher: [Buch]

    @State private var showNewSheet = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(buecher) { buch in
                    NavigationLink {
                        BuchDetails(buch: buch)
                        
                    } label: {
                        buchListCell(buch)
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
            .navigationTitle("Bücher")
        } detail: {
            Text("Autor auswählen")
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
