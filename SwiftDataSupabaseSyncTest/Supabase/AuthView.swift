//
//  AuthView.swift
//  SupabasePoool
//
//  Created by Christoph Rohrer on 01.10.24.
//

import SwiftUI
import Supabase

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
//    @State private var result: Result<Void, Error>?

    @EnvironmentObject var authVM: AuthVM
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        
        Group {
            if authVM.isAuthenticated  {
                ContentView()
            } else if authVM.isLoading {
                ProgressView()
            } else {
                Form {
                    Section {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                    }
                    
                    Section {
                        Button("Sign in") {
                            isLoading = true
                            defer { isLoading = false }
                            authVM.signIn(email: email, password: password)
                        }
                        if isLoading {
                            ProgressView()
                        }
                    }
                }
                .frame(width: 400)
                
                .onOpenURL(perform: { url in
                    print("onOpenURL", url)
                    supabase.auth.handle(url)
                })
                
            }
        }
        .onAppear {
            authVM.setContext(modelContext)
        }

    }
}
