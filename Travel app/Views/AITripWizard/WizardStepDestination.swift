import SwiftUI
import MapKit

struct WizardStepDestination: View {
    @Binding var destination: String
    @Binding var originIata: String

    var onNext: () -> Void

    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var suggestions: [DestinationSuggestion] = []
    @State private var isLoadingSuggestions = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                stepHeader

                destinationField
                autocompleteResults
                originField
                suggestButton

                if isLoadingSuggestions {
                    ProgressView()
                        .tint(AppTheme.sakuraPink)
                        .padding(.top, AppTheme.spacingM)
                }

                if !suggestions.isEmpty {
                    suggestionsSection
                }

                Spacer(minLength: 40)

                nextButton
            }
            .padding(AppTheme.spacingM)
        }
    }

    // MARK: - Header

    private var stepHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            Image(systemName: "map.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.sakuraPink)
            Text("Куда едем?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
            Text("Введите направление или попросите AI подсказать")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.spacingXL)
    }

    // MARK: - Destination Field

    private var destinationField: some View {
        GlassFormField(label: "НАПРАВЛЕНИЕ", color: AppTheme.sakuraPink) {
            TextField("Стамбул, Турция", text: $destination)
                .textFieldStyle(GlassTextFieldStyle())
                .onChange(of: destination) { _, newValue in
                    searchCompleter.search(query: newValue)
                }
        }
    }

    // MARK: - Autocomplete Results

    @ViewBuilder
    private var autocompleteResults: some View {
        if !searchCompleter.results.isEmpty && !destination.isEmpty {
            VStack(spacing: 0) {
                ForEach(searchCompleter.results.prefix(4), id: \.self) { result in
                    Button {
                        destination = [result.title, result.subtitle]
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")
                        searchCompleter.results = []
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.sakuraPink)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if result != searchCompleter.results.prefix(4).last {
                        Divider().opacity(0.3)
                    }
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Origin Field

    private var originField: some View {
        GlassFormField(label: "ОТКУДА (IATA)", color: AppTheme.oceanBlue) {
            TextField("MOW", text: $originIata)
                .textFieldStyle(GlassTextFieldStyle())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
    }

    // MARK: - Suggest Button

    private var suggestButton: some View {
        Button {
            loadSuggestions()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("ПОДСКАЖИ МНЕ")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(AppTheme.sakuraPink)
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.sakuraPink.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoadingSuggestions)
        .opacity(isLoadingSuggestions ? 0.5 : 1)
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(spacing: AppTheme.spacingS) {
            GlassSectionHeader(title: "AI РЕКОМЕНДУЕТ", color: AppTheme.sakuraPink)

            ForEach(suggestions) { suggestion in
                Button {
                    destination = suggestion.country
                    originIata = originIata.isEmpty ? "MOW" : originIata
                    suggestions = []
                } label: {
                    suggestionCard(suggestion)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func suggestionCard(_ suggestion: DestinationSuggestion) -> some View {
        HStack(spacing: 12) {
            Text(suggestion.flag)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.country)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                Text(suggestion.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 12) {
                    Label(suggestion.estimatedCost, systemImage: "rublesign.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.bambooGreen)
                    Label(suggestion.bestFor, systemImage: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(AppTheme.spacingM)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.sakuraPink.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button {
            onNext()
        } label: {
            Text("ДАЛЕЕ")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.sakuraPink)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium))
        }
        .disabled(destination.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity(destination.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        .padding(.bottom, AppTheme.spacingM)
    }

    // MARK: - Load Suggestions

    private func loadSuggestions() {
        isLoadingSuggestions = true
        Task {
            let profileContext = AIPromptHelper.profileContext()
            let result = await AITripGeneratorService.shared.suggestDestinations(
                dates: nil,
                budget: nil,
                profileContext: profileContext
            )
            suggestions = result
            isLoadingSuggestions = false
        }
    }
}
