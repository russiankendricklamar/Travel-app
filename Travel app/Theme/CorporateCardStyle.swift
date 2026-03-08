import SwiftUI

struct CorporateCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CorporateColors.darkNavy)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusLarge)
                    .stroke(CorporateColors.electricBlue.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: CorporateColors.electricBlue.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func corporateCard() -> some View {
        modifier(CorporateCardStyle())
    }
}
