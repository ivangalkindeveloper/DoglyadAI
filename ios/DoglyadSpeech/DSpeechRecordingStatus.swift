@frozen public enum DSpeechRecordingStatus {
    /// The session is starting up: the audio session is being configured and, on the
    /// WhisperKit, the language model may still be downloading on first launch.
    /// The microphone is not recording yet, so the screen must ask the user to wait
    /// rather than show an active recording.
    case preparing
    case recording
    /// The microphone is closed and the saved recording is being transcribed.
    case transcribing
    case stopped
}
