//
//  NeueGruppeSheet.
//  PooolRealm
//
//  Created by Christoph Rohrer on 04.04.24.
//

import SwiftUI

/// Sheet Basic für neue Elemente
struct NewSheet<V: View>: View {
    
    internal init(title: String, @ViewBuilder content: @escaping () -> V, action: @escaping () -> Void, disabled: @escaping () -> Bool = { false }) {
        self.title = title
        self.content = content
        self.action = action
        self.disabled = disabled
    }
    
    let title: String
    let content: () -> V
    let action: () -> Void
    var disabled: () -> Bool = { false }
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
//                Text(title)
//                    .font(.headline)
//                    .padding([.horizontal, .top])
//                
                Form {
                    content()
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                
            }
            .frame(minWidth: 400, minHeight: 300)
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction ) {
                    Button("Abbrechen", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction ) {
                    Button("OK") {
                        action()
                        dismiss()
                    }
                    .disabled(disabled())
                }
            }
            .navigationTitle(title)
        }
    }
}
