// Custom configuration for Jitsi Meet
// This file enables transcription infrastructure for multitrack recording

// Enable transcription (required for multitrack recorder to work)
// The multitrack recorder piggybacks on the transcription feature
config.transcription = {
    // Enable transcription UI and functionality
    enabled: true,

    // Do NOT invoke Jigasi (we're using multitrack recorder, not Jigasi)
    inviteJigasiOnBackendTranscribing: false,

    // Automatically enable transcription when recording starts
    autoTranscribeOnRecord: true
};

// Enable recording UI
config.recording = {
    enabled: true
};

// Enable file recording (this triggers the transcription infrastructure)
config.fileRecordingsEnabled = true;

// Disable local recording (we want server-side multitrack recording)
config.localRecording = {
    enabled: false
};
