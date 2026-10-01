import Foundation

/// 本地 PTY 传输层。
/// 目前是占位，后续接入 posix_spawn + socketpair。
final class LocalPTY {
    private(set) var isRunning = false

    func start() {
        // TODO: posix_spawn("/path/to/busybox", ["sh"], ...)
        isRunning = true
    }

    func write(_ data: Data) {
        // TODO: 写入 PTY master fd
    }

    func onOutput(_ handler: @escaping (Data) -> Void) {
        // TODO: 读取 PTY master fd 并回调
    }

    func stop() {
        isRunning = false
    }
}