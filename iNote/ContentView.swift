//
//  ContentView.swift
//  iNote
//
//  Created by 刘瑞 on 2025/11/18.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.cardBackground)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AppColors.secondaryText)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.secondaryText)]
        itemAppearance.selected.iconColor = UIColor(AppColors.accent)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.accent)]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        NavigationStack {
            EntryView()
        }
        .accentColor(AppColors.accent)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
