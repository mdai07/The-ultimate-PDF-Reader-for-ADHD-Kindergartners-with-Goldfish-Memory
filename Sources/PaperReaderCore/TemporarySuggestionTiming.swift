import Foundation

public struct TemporarySuggestionTiming: Equatable {
    public struct State: Equatable {
        public var fadeStartAt: Date
        public var expiresAt: Date
        public var extensionCount: Int

        public init(fadeStartAt: Date, expiresAt: Date, extensionCount: Int) {
            self.fadeStartAt = fadeStartAt
            self.expiresAt = expiresAt
            self.extensionCount = extensionCount
        }
    }

    public var visibleSeconds: TimeInterval
    public var fadeSeconds: TimeInterval
    public var extensionStepSeconds: TimeInterval

    public init(
        visibleSeconds: TimeInterval = 10,
        fadeSeconds: TimeInterval = 6,
        extensionStepSeconds: TimeInterval = 5
    ) {
        self.visibleSeconds = visibleSeconds
        self.fadeSeconds = fadeSeconds
        self.extensionStepSeconds = extensionStepSeconds
    }

    public func initialState(now: Date) -> State {
        state(now: now, extensionCount: 0)
    }

    public func extendedState(from state: State, now: Date) -> State {
        self.state(now: now, extensionCount: state.extensionCount + 1)
    }

    public func opacity(at now: Date, state: State) -> Double {
        if now < state.fadeStartAt {
            return 1
        }
        if now >= state.expiresAt {
            return 0
        }

        let remaining = state.expiresAt.timeIntervalSince(now)
        return max(0, min(1, remaining / max(fadeSeconds, 0.001)))
    }

    public func isExpired(at now: Date, state: State) -> Bool {
        now >= state.expiresAt
    }

    private func state(now: Date, extensionCount: Int) -> State {
        let visibleDuration = visibleSeconds + Double(extensionCount) * extensionStepSeconds
        let fadeStartAt = now.addingTimeInterval(visibleDuration)
        return State(
            fadeStartAt: fadeStartAt,
            expiresAt: fadeStartAt.addingTimeInterval(fadeSeconds),
            extensionCount: extensionCount
        )
    }
}
