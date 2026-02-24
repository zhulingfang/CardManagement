//
//  CardManagementApp.swift
//  CardManagement
//
//  Created by Lingfang Zhu on 7/28/25.
//

import SwiftUI

@available(iOS 16.0, *)
@main
struct CardManagementApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
