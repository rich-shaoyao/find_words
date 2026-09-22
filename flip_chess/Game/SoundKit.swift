//
//  SoundKit.swift
//  Flip Chess: Dark Xiangqi — 音效合成
//
//  对应 ui.js 里用 WebAudio 现场合成的那几个短音（走子 / 吃子 / 选中 / 结算）。
//  iOS 侧用 AVAudioEngine + 手写波形，同样**不带任何音频资源文件** ——
//  音色由代码决定，省资源也让 App 包里没有可被比对的素材。
//

import AVFoundation

public final class SoundKit {

    public static let shared = SoundKit()

    public enum Waveform { case sine, square, triangle, sawtooth }

    public var enabled = true

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44_100
    private var started = false

    private init() {}

    /// 播放一个短音。参数含义与 ui.js 的 beep 完全一致。
    public func beep(frequency: Double,
                     duration: Double,
                     waveform: Waveform = .sine,
                     volume: Double = 0.1) {
        guard enabled else { return }
        guard let buffer = makeBuffer(frequency: frequency, duration: duration,
                                      waveform: waveform, volume: volume) else { return }
        do {
            if !started {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                started = true
            }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) { [weak self] in
                DispatchQueue.main.async {
                    self?.engine.detach(player)
                }
            }
            player.play()
        } catch {
            // 音频不可用时静默：音效是锦上添花，不该影响下棋
        }
    }

    // MARK: 语义化封装（与 ui.js 的调用点一一对应）

    /// 选中棋子
    public func pick() { beep(frequency: 680, duration: 0.06, waveform: .sine, volume: 0.06) }

    /// 走子 / 吃子
    public func move(didCapture: Bool) {
        beep(frequency: didCapture ? 190 : 300,
             duration: didCapture ? 0.17 : 0.08,
             waveform: didCapture ? .square : .triangle,
             volume: didCapture ? 0.13 : 0.1)
    }

    /// 获胜
    public func win() { beep(frequency: 660, duration: 0.12, waveform: .sine, volume: 0.1) }

    /// 落败
    public func lose() { beep(frequency: 200, duration: 0.3, waveform: .sawtooth, volume: 0.09) }

    // MARK: 波形合成

    private func makeBuffer(frequency: Double, duration: Double,
                            waveform: Waveform, volume: Double) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard frameCount > 0,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = frameCount
        let phaseStep = 2 * Double.pi * frequency / sampleRate

        for i in 0..<Int(frameCount) {
            let phase = phaseStep * Double(i)
            let raw: Double
            switch waveform {
            case .sine:     raw = sin(phase)
            case .square:   raw = sin(phase) >= 0 ? 1 : -1
            case .triangle: raw = 2 / Double.pi * asin(sin(phase))
            case .sawtooth: raw = 2 * (frequency * Double(i) / sampleRate - floor(0.5 + frequency * Double(i) / sampleRate))
            }
            // 两端各做 3ms 淡入淡出，避免爆音
            let t = Double(i) / Double(frameCount)
            let fade = min(1, min(t, 1 - t) / 0.02)
            channel[i] = Float(raw * volume * fade)
        }
        return buffer
    }
}
