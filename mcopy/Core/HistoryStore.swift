import Foundation
import GRDB

enum HistoryStoreError: Error {
    case databaseOpenFailed
    case saveFailed
    case deleteFailed
    case queryFailed
    case invalidRecord
}

actor HistoryStore {
    private var dbQueue: DatabaseQueue?
    private let maxItems = 100
    private let dbURL: URL
    private let imagesFolder: URL

    init() async throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appFolder = appSupport.appendingPathComponent("mcopy", isDirectory: true)
        self.imagesFolder = appFolder.appendingPathComponent("images", isDirectory: true)

        try FileManager.default.createDirectory(
            at: appFolder,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: imagesFolder,
            withIntermediateDirectories: true
        )

        dbURL = appFolder.appendingPathComponent("clipboard.db")
        dbQueue = try DatabaseQueue(path: dbURL.path)
        try await createTables()
    }

    private func createTables() async throws {
        guard let dbQueue = dbQueue else {
            throw HistoryStoreError.databaseOpenFailed
        }

        try await dbQueue.write { db in
            try db.create(table: "clipboardItem", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("contentType", .text).notNull()
                t.column("preview", .text)
                t.column("imagePath", .text)
            }
        }
    }

    func save(_ item: ClipboardItem) async throws {
        guard let dbQueue = dbQueue else {
            throw HistoryStoreError.databaseOpenFailed
        }

        let recentItems = try await getRecentItems(limit: 10)
        if recentItems.contains(where: { $0.content == item.content }) {
            return
        }

        _ = try await dbQueue.write { db in
            var insertable = item
            try insertable.insert(db)
        }

        await cleanupOldItems()
    }

    func getRecentItems(limit: Int = 100) async throws -> [ClipboardItem] {
        guard let dbQueue = dbQueue else {
            throw HistoryStoreError.databaseOpenFailed
        }

        return try await dbQueue.read { db in
            try ClipboardItem
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func deleteItem(id: UUID) async throws {
        guard let dbQueue = dbQueue else {
            throw HistoryStoreError.databaseOpenFailed
        }

        if let item = try await dbQueue.read({ db in
            try ClipboardItem.fetchOne(db, id: id)
        }), let imagePath = item.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }

        _ = try await dbQueue.write { db in
            try ClipboardItem.deleteOne(db, id: id)
        }
    }

    func clearAll() async throws {
        guard let dbQueue = dbQueue else {
            throw HistoryStoreError.databaseOpenFailed
        }

        let allItems = try await getRecentItems(limit: maxItems * 10)
        for item in allItems {
            if let imagePath = item.imagePath {
                try? FileManager.default.removeItem(atPath: imagePath)
            }
        }

        _ = try await dbQueue.write { db in
            try ClipboardItem.deleteAll(db)
        }
    }

    private func cleanupOldItems() async {
        guard let dbQueue = dbQueue else { return }

        do {
            try await dbQueue.write { [weak self] db in
                guard let self = self else { return }
                let count = try ClipboardItem.fetchCount(db)
                if count > self.maxItems {
                    let excess = count - self.maxItems
                    let itemsToDelete = try ClipboardItem
                        .order(Column("timestamp").asc)
                        .limit(excess)
                        .fetchAll(db)

                    for item in itemsToDelete {
                        if let imagePath = item.imagePath {
                            try? FileManager.default.removeItem(atPath: imagePath)
                        }
                        try ClipboardItem.deleteOne(db, id: item.id)
                    }
                }
            }
        } catch {
            print("Cleanup failed: \(error)")
        }
    }

    func close() {
        dbQueue = nil
    }
}

extension ClipboardItem: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column("id")
        static let content = Column("content")
        static let timestamp = Column("timestamp")
        static let contentType = Column("contentType")
        static let preview = Column("preview")
        static let imagePath = Column("imagePath")
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.content] = content
        container[Columns.timestamp] = timestamp
        container[Columns.contentType] = contentType.rawValue
        container[Columns.preview] = preview
        container[Columns.imagePath] = imagePath
    }

    init(row: Row) throws {
        guard let uuid = UUID(uuidString: row[Columns.id]) else {
            throw HistoryStoreError.invalidRecord
        }
        id = uuid
        content = row[Columns.content]
        timestamp = row[Columns.timestamp]
        contentType = ContentType(rawValue: row[Columns.contentType]) ?? .unknown
        preview = row[Columns.preview]
        imagePath = row[Columns.imagePath]
    }
}
