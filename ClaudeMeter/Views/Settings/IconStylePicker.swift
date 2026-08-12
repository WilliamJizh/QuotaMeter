//
//  IconStylePicker.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-12-28.
//

import SwiftUI

/// Visual grid picker for selecting menu bar icon style
struct IconStylePicker: View {
    @Binding var selection: IconStyle
    let isColored: Bool
    var onSelectionChanged: ((IconStyle) -> Void)? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(IconStyle.allCases) { style in
                IconStyleCard(
                    style: style,
                    isSelected: selection == style,
                    isColored: isColored
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = style
                    onSelectionChanged?(style)
                }
            }
        }
    }
}

/// Individual card showing icon style preview
struct IconStyleCard: View {
    let style: IconStyle
    let isSelected: Bool
    let isColored: Bool

    /// Preview values, expressed as quota remaining to match the live icon.
    private let previewRemaining: Double = 35
    private let previewSecondaryRemaining: Double = 55
    private let previewStatus: UsageStatus = .warning

    var body: some View {
        VStack(spacing: 8) {
            // Live preview container
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .frame(height: 32)

                // Render the actual icon at a slightly larger scale for visibility
                iconPreview
                    .scaleEffect(1.2)
            }

            HStack(spacing: 4) {
                Text(style.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .primary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(style.displayName) icon style")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(style.accessibilityDescription)
    }

    private var iconPreview: some View {
        Image(nsImage: MenuBarIconRenderer().render(
            remaining: previewRemaining,
            status: previewStatus,
            isLoading: false,
            isStale: false,
            iconStyle: style,
            secondaryRemaining: previewSecondaryRemaining,
            isColored: isColored
        ))
            .renderingMode(isColored ? .original : .template)
            .foregroundStyle(.primary)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selection: IconStyle = .battery
        @State private var isColored: Bool = true

        var body: some View {
            VStack {
                Text("Selected: \(selection.displayName)")
                    .padding()

                Picker("Icon color", selection: $isColored) {
                    Text("Mono").tag(false)
                    Text("Color").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                IconStylePicker(selection: $selection, isColored: isColored)
                    .padding()
            }
            .frame(width: 400)
        }
    }

    return PreviewWrapper()
}
