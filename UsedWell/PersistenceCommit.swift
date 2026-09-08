import SwiftData

/// A user operation either commits completely or leaves the context at its last saved state.
/// Draft input stays in the View, outside the context. Never suspend inside this boundary.
@MainActor struct PersistenceCommit {
  var save: (ModelContext) throws -> Void = { try $0.save() }

  enum Failure: Error { case unrelatedChanges }

  func callAsFunction<Value>(
    in context: ModelContext, applying change: () throws -> Value
  ) throws -> Value {
    guard !context.hasChanges else { throw Failure.unrelatedChanges }
    do {
      let result = try change()
      if context.hasChanges { try save(context) }
      return result
    } catch {
      // Flush relationship changes before rollback so failed inserts/deletes can be undone.
      context.processPendingChanges()
      context.rollback()
      // SwiftData can retain mutated values in live model backing data after rollback.
      // Refetch both model types to refresh those same instances before another UI action.
      _ = try context.fetch(FetchDescriptor<Item>())
      _ = try context.fetch(FetchDescriptor<UsageNote>())
      throw error
    }
  }
}
