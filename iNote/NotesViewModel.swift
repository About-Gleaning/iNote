import Foundation
import SwiftData

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = true
    private var offset: Int = 0
    private let pageSize: Int = 20

    func refresh(context: ModelContext) async {
        offset = 0
        hasMore = true
        await loadMore(context: context, reset: true)
    }

    func loadMore(context: ModelContext, reset: Bool = false) async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }

        var descriptor = FetchDescriptor<Note>()
        descriptor.sortBy = [SortDescriptor(\Note.createdAt, order: .reverse)]
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = offset

        do {
            let fetched = try context.fetch(descriptor)
            if reset { notes = fetched } else { notes += fetched }
            if fetched.count < pageSize { hasMore = false }
            offset += fetched.count
        } catch {
            hasMore = false
        }
    }
}