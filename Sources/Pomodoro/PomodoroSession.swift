import Foundation

enum PomodoroSession {
    enum Kind {
        case focus
        case rest
    }

    case idle
    case running(kind: Kind, endDate: Date)

    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}
