//
//  Travel_appApp.swift
//  Travel app
//
//  Created by Егор Галкин on 28.02.2026.
//

import SwiftUI

@main
struct Travel_appApp: App {
    @State private var store = TripStore()

    var body: some Scene {
        WindowGroup {
            MainTabView(store: store)
                .preferredColorScheme(.light)
        }
    }
}
