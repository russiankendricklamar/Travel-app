import SwiftUI
import SwiftData

struct BucketListView: View {
    @Query(sort: \BucketListItem.dateAdded, order: .reverse) var items: [BucketListItem]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false

    private var unconvertedItems: [BucketListItem] {
        items.filter { !$0.isConverted }
    }

    private var convertedItems: [BucketListItem] {
        items.filter(\.isConverted)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: AppTheme.spacingM) {
                    if items.isEmpty {
                        emptyState
                    } else {
                        if !unconvertedItems.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                GlassSectionHeader(title: "ЖЕЛАНИЯ", color: AppTheme.sakuraPink)
                                ForEach(unconvertedItems) { item in
                                    BucketItemCard(item: item)
                                        .contextMenu {
                                            Button {
                                                item.isConverted = true
                                                try? modelContext.save()
                                            } label: {
                                                Label("Отметить выполненным", systemImage: "checkmark.circle")
                                            }
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Удалить", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        if !convertedItems.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                GlassSectionHeader(title: "ВЫПОЛНЕНО", color: AppTheme.bambooGreen)
                                ForEach(convertedItems) { item in
                                    BucketItemCard(item: item)
                                        .contextMenu {
                                            Button {
                                                item.isConverted = false
                                                try? modelContext.save()
                                            } label: {
                                                Label("Вернуть в желания", systemImage: "arrow.uturn.backward")
                                            }
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                                try? modelContext.save()
                                            } label: {
                                                Label("Удалить", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
            }
            .sakuraGradientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("СПИСОК ЖЕЛАНИЙ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(AppTheme.sakuraPink)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.sakuraPink)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddBucketItemSheet()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingM) {
            Spacer(minLength: 80)

            Image(systemName: "bookmark.circle")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AppTheme.sakuraPink.opacity(0.4))

            Text("СПИСОК ПУСТ")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("Добавьте места мечты")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            Button {
                showAddSheet = true
            } label: {
                Text("ДОБАВИТЬ")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.sakuraPink, AppTheme.sakuraPink.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: AppTheme.sakuraPink.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, AppTheme.spacingXL)

            Spacer(minLength: 80)
        }
    }
}
