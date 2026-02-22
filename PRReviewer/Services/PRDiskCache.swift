import Foundation

/// Persistent disk cache for PR data using JSON files.
/// Enables instant app launch by loading cached data from disk.
actor PRDiskCache {
    static let shared = PRDiskCache()

    private let cacheDirectory: URL
    private let fileManager = FileManager.default

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("PRReviewer/cache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // Visible for testing
    init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - PR List

    func savePRList(_ prs: [PullRequest]) throws {
        let data = try encoder.encode(prs)
        let url = cacheDirectory.appendingPathComponent("pr-list.json")
        try data.write(to: url, options: .atomic)
    }

    func loadPRList() -> [PullRequest]? {
        let url = cacheDirectory.appendingPathComponent("pr-list.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([PullRequest].self, from: data)
    }

    // MARK: - PR Snapshots

    func saveSnapshot(_ snapshot: PRSnapshot, for prId: Int) throws {
        let dir = prDirectory(for: prId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try encoder.encode(snapshot)
        try data.write(to: dir.appendingPathComponent("snapshot.json"), options: .atomic)
    }

    func loadSnapshot(for prId: Int) -> PRSnapshot? {
        let url = prDirectory(for: prId).appendingPathComponent("snapshot.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(PRSnapshot.self, from: data)
    }

    // MARK: - Cleanup

    func deleteSnapshot(for prId: Int) throws {
        let dir = prDirectory(for: prId)
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
    }

    func cleanupClosedPRs(openPRIds: Set<Int>) throws {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("pr-"),
                  let idString = name.split(separator: "-").last,
                  let prId = Int(idString) else {
                continue
            }

            if !openPRIds.contains(prId) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - Private

    private func prDirectory(for prId: Int) -> URL {
        cacheDirectory.appendingPathComponent("pr-\(prId)", isDirectory: true)
    }
}
