import Foundation

/// A cancellable scheduled action.
protocol DebounceToken {
    func cancel()
}

/// Schedules work after a delay — abstracted so tests can drive it deterministically.
protocol DebounceScheduling {
    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void) -> DebounceToken
}

final class DispatchDebounceToken: DebounceToken {
    private let item: DispatchWorkItem
    init(_ item: DispatchWorkItem) { self.item = item }
    func cancel() { item.cancel() }
}

/// Default scheduler backed by a `DispatchQueue`.
final class DispatchDebounceScheduler: DebounceScheduling {
    private let queue: DispatchQueue
    init(queue: DispatchQueue = .main) { self.queue = queue }

    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void) -> DebounceToken {
        let item = DispatchWorkItem(block: work)
        queue.asyncAfter(deadline: .now() + interval, execute: item)
        return DispatchDebounceToken(item)
    }
}

/// Coalesces rapid `signal()` calls into a single `action` after a quiet `interval`.
final class Debouncer {
    private let interval: TimeInterval
    private let scheduler: DebounceScheduling
    private let action: () -> Void
    private var pending: DebounceToken?

    init(interval: TimeInterval, scheduler: DebounceScheduling = DispatchDebounceScheduler(), action: @escaping () -> Void) {
        self.interval = interval
        self.scheduler = scheduler
        self.action = action
    }

    func signal() {
        pending?.cancel()
        pending = scheduler.schedule(after: interval) { [weak self] in
            self?.pending = nil
            self?.action()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
    }
}

/// Watches a directory (not a file — survives `.atomic` inode replacement) for changes and
/// fires a debounced `onChange` on the main queue.
final class ConfigFileWatcher {
    private let directory: URL
    private let onChange: () -> Void
    private let debouncer: Debouncer
    private var stream: FSEventStreamRef?

    init(directory: URL, debounce: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.directory = directory
        self.onChange = onChange
        self.debouncer = Debouncer(interval: debounce, action: onChange)
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<ConfigFileWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.debouncer.signal()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        debouncer.cancel()
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}
