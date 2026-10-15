import AVFoundation

enum AudioBufferConverter {
    static func convert(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter?,
                        to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.frameLength > 0 else { return nil }
        guard let converter else { return buffer }
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate))
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }
        var error: NSError?
        var suppliedInput = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            // A converter may ask for input more than once. Replaying this buffer
            // inserts duplicate samples and shifts the end of the recording.
            guard !suppliedInput else {
                outStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil else { return nil }
        return output
    }
}
