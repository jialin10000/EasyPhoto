//
//  LightViewerApp.swift
//  LightViewer
//
//  Created by LIN JIA on 1/14/26.
//

import SwiftUI
import CoreData

@main
struct LightViewerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
