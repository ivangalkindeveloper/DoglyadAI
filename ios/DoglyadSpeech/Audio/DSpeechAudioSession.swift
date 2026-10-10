import AVFoundation
import Foundation

/// Where the sound is coming from right now. It drives both the session settings and
/// the hints given to the recognizer: a headset picks up speech at the mouth, the
/// built-in microphone picks it up from a distance and through room noise.
public enum DSpeechAudioRoute {
    /// Headset: AirPods, a wired lavalier, a USB microphone.
    case headset
    /// Built-in microphone: the phone in hand or lying next to the scanner.
    case builtIn
}

/// Audio session setup for examination dictation.
enum DSpeechAudioSession {
    /// Prepares the session and returns the actual input route.
    ///
    /// The category is deliberately `.playAndRecord` even though we play nothing.
    /// Voice processing is raised on the input and output node pair at once —
    /// enabling it on one automatically enables it on the other. On `.record` there
    /// is no output node, so the input one stays unconfigured and reports a format
    /// with a zero sample rate, on which `installTap` fails with
    /// `IsFormatSampleRateAndChannelCountValid`. For the same reason high-quality
    /// recording from a Bluetooth headset also requires a category with output.
    ///
    /// Mode `.default` rather than `.measurement`: the latter switches off all system
    /// signal processing, and for dictation from a distance that processing is exactly
    /// what we need. It is also the only mode compatible with `bluetoothHighQualityRecording`.
    @discardableResult
    static func activate() throws -> DSpeechAudioRoute {
        let session = AVAudioSession.sharedInstance()

        // HFP is always enabled: the narrow band is no obstacle here — recognizers work
        // at 16 kHz anyway, and a microphone at the mouth beats any built-in one.
        var options: AVAudioSession.CategoryOptions = [
            .duckOthers,
            .allowBluetoothHFP,
            // We play nothing, but without this the output goes to the receiver speaker,
            // and the microphone choice changes along with it.
            .defaultToSpeaker,
        ]
        if #available(iOS 26.0, *) {
            // Compatible AirPods record at full bandwidth; if the route cannot sustain it,
            // the system falls back to HFP on its own.
            options.insert(
                .bluetoothHighQualityRecording,
            )
        }

        // Errors here must not be swallowed: after a failed setup the input node
        // reports an invalid format, and the crash lands far from its cause.
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: options,
        )
        try session.setActive(
            true,
            options: .notifyOthersOnDeactivation,
        )
        // An incoming call in the middle of dictation cuts the recording short and the
        // examination has to start over — ask the system not to interrupt us.
        try? session.setPrefersNoInterruptionsFromSystemAlerts(
            true,
        )

        return currentRoute
    }

    static func deactivate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setPrefersNoInterruptionsFromSystemAlerts(
            false,
        )
        try? session.setActive(
            false,
            options: .notifyOthersOnDeactivation,
        )
    }

    /// The microphone counts as built-in only when there are no other inputs: anything
    /// else — headset, lavalier, USB — is certainly closer to the physician's mouth.
    static var currentRoute: DSpeechAudioRoute {
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        let isBuiltIn = inputs.allSatisfy { $0.portType == .builtInMic }

        return isBuiltIn ? .builtIn : .headset
    }
}

extension AVAudioFormat {
    /// `installTap` trips an assert on a format with a zero sample rate or no channels.
    /// The input node reports exactly that when the session failed to start, there is
    /// no microphone permission, or the node has not yet reconfigured after voice
    /// processing was enabled.
    var isValidForCapture: Bool {
        sampleRate > 0 && channelCount > 0
    }
}
