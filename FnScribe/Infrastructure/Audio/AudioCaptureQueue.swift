import AVFoundation
import Foundation

/// Owns copies of tap buffers until the main actor drains them. All mutable state
/// is protected by the lock; closing and draining also works before a UI wakeup.
final class AudioCaptureQueue: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var buffers: [AVAudioPCMBuffer] = []
    nonisolated(unsafe) private var isClosed = false

    /// Returns true only when a drain task needs to be scheduled.
    nonisolated func appendCopy(of buffer: AVAudioPCMBuffer) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isClosed, buffer.frameLength > 0,
              let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return false
        }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in source.indices {
            guard let from = source[index].mData, let to = destination[index].mData else { return false }
            memcpy(to, from, Int(source[index].mDataByteSize))
        }
        let needsDrain = buffers.isEmpty
        buffers.append(copy)
        return needsDrain
    }

    nonisolated func close() {
        lock.lock()
        defer { lock.unlock() }
        isClosed = true
    }

    nonisolated func drain() -> [AVAudioPCMBuffer] {
        lock.lock()
        defer { lock.unlock() }
        let captured = buffers
        buffers.removeAll(keepingCapacity: true)
        return captured
    }
}
