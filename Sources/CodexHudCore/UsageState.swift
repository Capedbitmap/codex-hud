import Foundation

public struct UsageStateManager {
    public init() {}

    public func applyAssumedResetsIfNeeded(snapshot: RateLimitsSnapshot, now: Date) -> RateLimitsSnapshot {
        let updatedFiveHour = applyAssumedResetIfNeeded(window: snapshot.fiveHour, now: now)
        let updatedWeekly = applyAssumedResetIfNeeded(window: snapshot.weekly, now: now)
        if updatedFiveHour == snapshot.fiveHour && updatedWeekly == snapshot.weekly {
            return snapshot
        }
        return RateLimitsSnapshot(capturedAt: snapshot.capturedAt, fiveHour: updatedFiveHour, weekly: updatedWeekly, source: snapshot.source)
    }

    private func applyAssumedResetIfNeeded(window: UsageWindow, now: Date) -> UsageWindow {
        guard now >= window.resetsAt else { return window }
        if window.assumedReset { return window }
        return UsageWindow(
            kind: window.kind,
            usedPercent: 0,
            windowMinutes: window.windowMinutes,
            resetsAt: window.resetsAt,
            isStale: true,
            assumedReset: true
        )
    }
}
