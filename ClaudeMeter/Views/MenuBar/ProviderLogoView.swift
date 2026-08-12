//
//  ProviderLogoView.swift
//  QuotaMeter
//

import SwiftUI

/// Renders a provider's actual logo at a fixed square size.
///
/// The assets keep their own brand colours (`template-rendering-intent: original`),
/// so no tint is applied here.
struct ProviderLogoView: View {
    let provider: QuotaProvider
    var size: CGFloat = 14

    var body: some View {
        Image(provider.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityLabel("\(provider.displayName) logo")
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(QuotaProvider.allCases, id: \.self) { provider in
            VStack {
                ProviderLogoView(provider: provider, size: 32)
                Text(provider.displayName).font(.caption)
            }
        }
    }
    .padding()
}
