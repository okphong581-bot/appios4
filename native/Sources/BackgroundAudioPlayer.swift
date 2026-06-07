import Foundation
import AVFoundation

/// BackgroundAudioPlayer - Quản lý việc phát âm thanh im lặng trong nền.
/// Trách nhiệm:
/// 1. Cấu hình AVAudioSession hoạt động trong chế độ phát nền (Background Playback).
/// 2. Tạo một file âm thanh im lặng (silent WAV) động trong bộ nhớ để không cần file tài nguyên tĩnh.
/// 3. Phát lặp vô hạn file im lặng này để hệ điều hành giữ app chạy trong nền và không ẩn overlay.
class BackgroundAudioPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = BackgroundAudioPlayer()
    
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = false
    
    private override init() {
        super.init()
    }
    
    func start() {
        guard !isPlaying else { return }
        
        do {
            let session = AVAudioSession.sharedInstance()
            // Thiết lập category là playback để có thể chạy được trong nền
            // và option mixWithOthers để không ảnh hưởng đến âm thanh của các app khác
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let silentWavData = createSilentWavData()
            
            audioPlayer = try AVAudioPlayer(data: silentWavData)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // Lặp vô hạn
            audioPlayer?.volume = 0.0 // Hoàn toàn im lặng
            
            if audioPlayer?.prepareToPlay() == true {
                audioPlayer?.play()
                isPlaying = true
                print("[HaFloating] BackgroundAudioPlayer: Đã bắt đầu phát âm thanh im lặng trong nền.")
            } else {
                print("[HaFloating] BackgroundAudioPlayer: Không thể chuẩn bị trình phát âm thanh.")
            }
        } catch {
            print("[HaFloating] BackgroundAudioPlayer: Lỗi khởi tạo âm thanh nền: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        guard isPlaying else { return }
        audioPlayer?.stop()
        isPlaying = false
        print("[HaFloating] BackgroundAudioPlayer: Đã dừng phát âm thanh trong nền.")
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[HaFloating] BackgroundAudioPlayer: Lỗi hủy kích hoạt Audio Session: \(error.localizedDescription)")
        }
    }
    
    /// Tạo 1 giây âm thanh im lặng chuẩn WAV trong bộ nhớ
    private func createSilentWavData() -> Data {
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let duration: Int = 1
        let numSamples = Int(sampleRate) * duration
        let dataSize = numSamples * Int(bitsPerSample / 8)
        
        var header = Data()
        
        // Helper ghi giá trị binary dạng Little Endian
        func toData<T>(_ value: T) -> Data {
            var val = value
            return withUnsafeBytes(of: &val) { Data($0) }
        }
        
        // RIFF header
        header.append("RIFF".data(using: .utf8)!)
        header.append(toData(Int32(36 + dataSize).littleEndian))
        header.append("WAVE".data(using: .utf8)!)
        
        // format subchunk
        header.append("fmt ".data(using: .utf8)!)
        header.append(toData(Int32(16).littleEndian))
        header.append(toData(Int16(1).littleEndian)) // PCM
        header.append(toData(numChannels.littleEndian))
        header.append(toData(sampleRate.littleEndian))
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample / 8)
        header.append(toData(byteRate.littleEndian))
        let blockAlign = numChannels * (bitsPerSample / 8)
        header.append(toData(blockAlign.littleEndian))
        header.append(toData(bitsPerSample.littleEndian))
        
        // data subchunk
        header.append("data".data(using: .utf8)!)
        header.append(toData(Int32(dataSize).littleEndian))
        
        // Silence data (các byte giá trị 0)
        let silence = Data(repeating: 0, count: dataSize)
        header.append(silence)
        
        return header
    }
}
