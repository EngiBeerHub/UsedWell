"""Regenerate the pre-photo SwiftData fixture from the shipped model source.

Run on macOS with Xcode installed. Only a temporary store is created; user stores
are never opened. The fixture has two items, four notes, and fixed identities.
"""
import argparse
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RUNNER = r'''
import Foundation
import SwiftData

@main struct MigrationRunner {
  @MainActor static func main() throws {
    let url = URL(fileURLWithPath: CommandLine.arguments[1])
    let container = try ModelContainer(for: Item.self, UsageNote.self, configurations: ModelConfiguration(url: url))
    let context = container.mainContext
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    for (index, name) in ["Legacy active", "Legacy history"].enumerated() {
      let item = Item(name: name, category: .camera, purchaseDate: date, purchasePrice: 123456, targetMonths: 48, completedDate: index == 1 ? date.addingTimeInterval(86400 * 500) : nil, createdAt: date)
      context.insert(item)
      item.navigationID = UUID(uuidString: index == 0 ? "11111111-1111-1111-1111-111111111111" : "22222222-2222-2222-2222-222222222222")!
      item.notificationID = UUID(uuidString: index == 0 ? "33333333-3333-3333-3333-333333333333" : "44444444-4444-4444-4444-444444444444")!
      item.usageNotes.append(UsageNote(date: date, text: "Preserve this note", createdAt: date, updatedAt: date))
      item.usageNotes.append(UsageNote(date: date.addingTimeInterval(86400), text: "Second note", createdAt: date, updatedAt: date))
    }
    try context.save()
    print("Created legacy store: \(try context.fetchCount(FetchDescriptor<Item>())) items")
  }
}
'''

parser = argparse.ArgumentParser()
parser.add_argument("--revision", default="7f5bd45", help="Pre-photo source revision")
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix="usedwell-legacy-") as temporary:
    work = Path(temporary)
    for name in ("Item.swift", "UsageNote.swift"):
        source = subprocess.check_output(
            ["git", "show", f"{args.revision}:UsedWell/{name}"], cwd=ROOT)
        (work / name).write_bytes(source)
    (work / "Runner.swift").write_text(RUNNER)
    subprocess.run(["xcrun", "swiftc", "-module-name", "UsedWell",
                    str(work / "Item.swift"), str(work / "UsageNote.swift"),
                    str(work / "Runner.swift"), "-o", str(work / "generate")], check=True)
    store = work / "legacy.store"
    subprocess.run([str(work / "generate"), str(store)], check=True)
    with sqlite3.connect(store) as database:
        database.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    destination = ROOT / "UsedWellTests/Fixtures/legacy-photo-v1.store"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(store, destination)
    print(f"Wrote {destination} from {args.revision}")
