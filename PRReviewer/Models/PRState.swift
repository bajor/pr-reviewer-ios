import Foundation

struct PRState: Codable, Equatable {
    let prId: Int
    let prNumber: Int
    let repositoryFullName: String
    let lastCommitSHA: String
    let commentCount: Int
    let lastChecked: Date

    init(prId: Int, prNumber: Int, repositoryFullName: String, lastCommitSHA: String, commentCount: Int) {
        self.prId = prId
        self.prNumber = prNumber
        self.repositoryFullName = repositoryFullName
        self.lastCommitSHA = lastCommitSHA
        self.commentCount = commentCount
        self.lastChecked = Date()
    }
}

struct PRStateCache {
    private static let userDefaultsKey = "PRStateCache"

    static func load() -> [Int: PRState] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let states = try? JSONDecoder().decode([Int: PRState].self, from: data) else {
            return [:]
        }
        return states
    }

    static func save(_ states: [Int: PRState]) {
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    static func getState(for prId: Int) -> PRState? {
        load()[prId]
    }

    static func setState(_ state: PRState, for prId: Int) {
        var states = load()
        states[prId] = state
        save(states)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
