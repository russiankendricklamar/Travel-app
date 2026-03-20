import Foundation
import AVFoundation
import CoreLocation

final class NavigationVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    /// Tracks which distance thresholds have been announced per step instruction
    /// Key format: "{instruction}-{thresholdMeters}"
    private var announcedDistances: Set<String> = []

    /// Distance thresholds in meters — announce at 500m, 200m, arrival (15m)
    private let triggerDistances: [CLLocationDistance] = [500, 200, 15]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    /// Check if distance triggers an announcement for the given step
    /// Called on every GPS update by NavigationEngine
    func checkDistanceTrigger(_ distance: CLLocationDistance, stepInstruction: String) {
        for threshold in triggerDistances {
            let key = "\(stepInstruction)-\(Int(threshold))"
            if distance <= threshold && !announcedDistances.contains(key) {
                announcedDistances.insert(key)
                let text = buildAnnouncement(instruction: stepInstruction, distance: distance, threshold: threshold)
                speak(text)
                return  // Only one announcement per GPS tick
            }
        }
    }

    /// Announce a new step immediately (e.g., after reroute or step advancement)
    func announceStep(instruction: String, distanceRemaining: CLLocationDistance) {
        let text = buildAnnouncement(instruction: instruction, distance: distanceRemaining, threshold: distanceRemaining)
        speak(text)
    }

    /// Reset tracked announcements for a specific step (call when step advances)
    func resetForStep(_ instruction: String) {
        announcedDistances = announcedDistances.filter { !$0.hasPrefix(instruction) }
    }

    /// Reset all tracked announcements (call when navigation stops or reroutes)
    func resetAll() {
        announcedDistances.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Speech

    private func speak(_ text: String) {
        // Cancel any queued speech to prevent stale announcements
        synthesizer.stopSpeaking(at: .word)

        // Activate audio session with ducking
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        // Use device locale, fall back to Russian
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "ru")
            ?? AVSpeechSynthesisVoice(language: "ru-RU")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    /// Pitfall 2: deactivate audio session 0.5s after speech ends to unduck music.
    /// Synchronous deactivation fails with error 560030580.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    // MARK: - Announcement Builder

    private func buildAnnouncement(instruction: String, distance: CLLocationDistance, threshold: CLLocationDistance) -> String {
        if threshold <= 15 {
            // Arrival announcement — just the instruction
            return instruction
        } else if threshold <= 200 {
            return "Через \(Int(distance)) метров, \(instruction)"
        } else {
            return "Через \(Self.formatDistanceForSpeech(distance)), \(instruction)"
        }
    }

    private static func formatDistanceForSpeech(_ meters: CLLocationDistance) -> String {
        if meters >= 1000 {
            let km = meters / 1000
            if km == Double(Int(km)) {
                return "\(Int(km)) километров"
            }
            return String(format: "%.1f километров", km)
        }
        // Round to nearest 50m for cleaner speech
        let rounded = Int((meters / 50).rounded()) * 50
        return "\(max(rounded, 50)) метров"
    }
}
