import Foundation
import AVFoundation
import MediaPlayer
import Observation

// MARK: - AudioPlayerManager

@MainActor
@Observable
class AudioPlayerManager {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemEndObserver: NSObjectProtocol?

    var isPlaying = false
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Float = 1.0
    var isLoading = false
    var loadedURL: String? = nil

    // Metadata shown on lock screen / Control Center
    private var nowPlayingTitle: String = ""
    private var nowPlayingArtist: String = ""

    static let rateOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    // MARK: - Load

    func load(urlString: String, episodeTitle: String = "", storyTitle: String = "") {
        guard urlString != loadedURL else { return }
        stop()
        guard let url = URL(string: urlString) else { return }

        nowPlayingTitle = episodeTitle
        nowPlayingArtist = storyTitle
        isLoading = true
        loadedURL = urlString

        configureAudioSession()
        setupRemoteCommands()

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.rate = 0

        Task {
            do {
                let dur = try await item.asset.load(.duration)
                self.duration = dur.seconds.isFinite ? dur.seconds : 0
                self.isLoading = false
                self.updateNowPlayingInfo()
            } catch {
                self.isLoading = false
            }
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                self.updateNowPlayingElapsed()
            }
        }

        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: .zero)
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.rate = playbackRate
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = seconds
        updateNowPlayingElapsed()
    }

    func skipForward(by seconds: Double = 15) {
        seek(to: min(currentTime + seconds, duration))
    }

    func skipBackward(by seconds: Double = 15) {
        seek(to: max(currentTime - seconds, 0))
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
            updateNowPlayingInfo()
        }
    }

    func stop() {
        removeRemoteCommands()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        loadedURL = nil
        isLoading = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Computed Helpers

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var formattedCurrentTime: String { formatTime(currentTime) }
    var formattedDuration: String { formatTime(duration) }
    var formattedRemaining: String { "-" + formatTime(max(0, duration - currentTime)) }

    // MARK: - AVAudioSession

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothHFP, .allowAirPlay]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Playback may still work on simulator
        }
    }

    // MARK: - Lock Screen / Control Center (MPRemoteCommandCenter)

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        cc.skipForwardCommand.isEnabled = true
        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward()
            return .success
        }

        cc.skipBackwardCommand.isEnabled = true
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward()
            return .success
        }

        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: e.positionTime)
            return .success
        }
    }

    private func removeRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.removeTarget(nil)
        cc.pauseCommand.removeTarget(nil)
        cc.togglePlayPauseCommand.removeTarget(nil)
        cc.skipForwardCommand.removeTarget(nil)
        cc.skipBackwardCommand.removeTarget(nil)
        cc.changePlaybackPositionCommand.removeTarget(nil)
    }

    // MARK: - Now Playing Info (Lock Screen metadata)

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:            nowPlayingTitle.isEmpty ? "Episode" : nowPlayingTitle,
            MPMediaItemPropertyArtist:           nowPlayingArtist.isEmpty ? "Moonlit Stories" : nowPlayingArtist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]
        // App icon as artwork fallback
        if let image = UIImage(named: "AppIcon") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // Lightweight update — only elapsed time & rate (called every 0.5s during playback)
    private func updateNowPlayingElapsed() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackRate) : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        let m = s / 60
        let rem = s % 60
        return "\(m):\(String(format: "%02d", rem))"
    }
}
