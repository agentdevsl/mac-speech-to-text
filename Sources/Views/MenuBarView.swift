// MenuBarView.swift
// macOS Local Speech-to-Text Application
//
// Ultra-minimal menu bar dropdown: Open app + Quit
// All settings moved to MainView

import SwiftUI

/// Ultra-minimal menu bar dropdown
struct MenuBarView: View {
    @State private var viewModel = MenuBarViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Open Speech to Text
            Button {
                viewModel.openMainView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.statusIcon)
                        .foregroundStyle(viewModel.iconColor)
                    Text("Open Speech to Text")
                    Spacer()
                    Text(",")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button {
                viewModel.quit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                    Text("Quit")
                    Spacer()
                    Text("Q")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 220)
    }
}

#Preview("Menu Bar View") {
    MenuBarView()
}
