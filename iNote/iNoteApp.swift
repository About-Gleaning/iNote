//
//  iNoteApp.swift
//  iNote
//
//  Created by 刘瑞 on 2025/11/18.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct iNoteApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            MediaAsset.self,
            Tag.self
        ])

        let cloudConfig = ModelConfiguration(
            "cloud",
            schema: schema,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
