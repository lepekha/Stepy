//
//  ContentView.swift
//  Steps
//
//  Created by Ruslan Lepekha on 05.06.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        HomeScreen(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
