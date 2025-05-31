import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// Import the Apex method that will be called to interact with the backend Agent/AI
import invokeAgentBackendMethod from '@salesforce/apex/AIAgentInvoker.invokeJavaAction';

// Get browser's SpeechRecognition API, prefixed for compatibility (e.g., webkitSpeechRecognition for older Chrome/Safari)
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
// Get browser's SpeechSynthesis API for text-to-speech
const speechSynthesis = window.speechSynthesis;

export default class VoiceAgent extends LightningElement {
    // Reactive property to display status messages to the user in the UI.
    @track statusMessage = 'Tap the orb to start';
    // Reactive property to track if the agent is currently listening via SpeechRecognition.
    @track isListening = false;
    // Reactive property to track if the agent is processing a command (e.g., waiting for Apex response).
    @track isProcessing = false; 
    // Reactive property to track if the agent is currently speaking (TTS is active).
    @track isSpeaking = false;

    // Holds the instance of the SpeechRecognition API.
    recognition;

    /**
     * Getter: Determines the icon to display on the microphone button based on the current state.
     * @returns {string} The SLDS utility icon name (e.g., 'utility:mic', 'utility:close').
     */
    get micButtonIcon() {
        if (this.isListening) return 'utility:close'; // 'Stop' icon when listening
        if (this.isProcessing || this.isSpeaking) return 'utility:settings_analog'; // 'Processing/Speaking' icon (animated via CSS)
        return 'utility:mic'; // Default 'mic' icon
    }

    /**
     * Getter: Provides alternative text for the microphone button for accessibility (screen readers).
     * @returns {string} Descriptive text for the button's current action.
     */
    get micButtonAlternativeText() {
        if (this.isListening) return 'Stop Listening';
        if (this.isProcessing) return 'Processing your request';
        if (this.isSpeaking) return 'Agent is speaking';
        return 'Start Listening';
    }

    /**
     * Getter: Dynamically computes CSS classes for the microphone button based on state.
     * This allows for visual changes (e.g., color, animation) via CSS.
     * @returns {string} A string of CSS classes.
     */
    get micButtonClass() {
        let classes = 'mic-button slds-button_icon-border-filled slds-button_icon-inverse'; // Base styling classes
        if (this.isListening) {
            classes += ' mic-button-listening'; // Class when listening
        } else if (this.isProcessing || this.isSpeaking) {
            classes += ' mic-button-processing'; // Class when processing or speaking
        }
        return classes;
    }

    /**
     * Getter: Determines if the microphone button should be visually indicated as processing/busy.
     * Used to disable the button or change its appearance during critical operations.
     * @returns {boolean} True if processing or speaking, false otherwise.
     */
    get isProcessingVisuals() {
        return this.isProcessing || this.isSpeaking;
    }

    /**
     * Getter: Controls the visibility of the main processing spinner (lightning-spinner).
     * Shows spinner specifically when waiting for an Apex response, but not while TTS is active.
     * @returns {boolean} True if spinner should be shown, false otherwise.
     */
    get showProcessingSpinner() {
        return this.isProcessing && !this.isSpeaking; // Show spinner when calling Apex, hide when TTS starts
    }

    /**
     * Getter: Provides dynamic CSS classes for the spinner container.
     * @returns {string} CSS classes including slds-visible/slds-hidden.
     */
    get spinnerContainerClass() {
        return 'spinner-container slds-m-top_small ' + (this.showProcessingSpinner ? 'slds-visible' : 'slds-hidden');
    }

    /**
     * Lifecycle Hook: Called when the component is inserted into the DOM.
     * Checks for browser support for Web Speech APIs and initializes speech recognition.
     */
    connectedCallback() {
        if (!SpeechRecognition) {
            this.showError('Browser Not Supported', 'Speech Recognition API is not supported in this browser.');
            this.disableComponent('Unsupported'); // Visually disable component
            return;
        }
        if (!speechSynthesis) {
            this.showError('Browser Not Supported', 'Speech Synthesis API is not supported in this browser.');
            this.disableComponent('Unsupported'); // Setup SpeechRecognition instance
            return;
        }
        this.initializeSpeechRecognition();
    }

    /**
     * Lifecycle Hook: Called when the component is removed from the DOM.
     * Cleans up by aborting any ongoing speech recognition or synthesis to prevent memory leaks or errors.
     */
    disconnectedCallback() {
        if (this.recognition) {
            this.recognition.abort(); // Stop speech recognition
        }
        if (speechSynthesis && speechSynthesis.speaking) {
            speechSynthesis.cancel(); // Stop any ongoing text-to-speech
        }
    }

    /**
     * Initializes or re-initializes the SpeechRecognition instance and its event handlers.
     */
    initializeSpeechRecognition() {
        this.recognition = new SpeechRecognition();
        this.recognition.continuous = false; // False: Stop listening after the first utterance.
        this.recognition.interimResults = false; // False: Only provide final results, not intermediate ones.
        this.recognition.lang = 'en-US'; // Set recognition language (can be made dynamic).

        // Event handler: Fired when speech recognition service has begun listening.
        this.recognition.onstart = () => {
            this.isListening = true;
            this.isProcessing = false; // Ensure not in processing state
            this.isSpeaking = false; // Ensure not in speaking state
            this.statusMessage = 'Listening...';
        };

        // Event handler: Fired when the speech recognition service returns a result.
        this.recognition.onresult = (event) => {
            const transcribedText = event.results[0][0].transcript.trim(); // Get the transcribed text
            this.statusMessage = `You said: "${transcribedText}"`;
            this.isListening = false; // Recognition part is done
            this.isProcessing = true; // Start processing this text
            this.handleAgentBackendInteraction(transcribedText);
        };

        // Event handler: Fired when a speech recognition error occurs.
        this.recognition.onerror = (event) => {
            console.error('Speech recognition error:', event.error);
            let errorMessage = 'An error occurred during speech recognition.';
            if (event.error === 'no-speech') {
                errorMessage = 'No speech detected. Please try again.';
            } else if (event.error === 'audio-capture') {
                errorMessage = 'Audio capture failed. Ensure microphone is enabled.';
            } else if (event.error === 'not-allowed') {
                errorMessage = 'Microphone access denied. Please allow microphone access.';
            }
            this.showError('Speech Recognition Error', errorMessage);
            this.resetToReady(); // Reset UI to a ready state
        };

        // Event handler: Fired when the speech recognition service has disconnected.
        this.recognition.onend = () => {
            // If recognition ends while 'isListening' is still true, it might be an unexpected stop.
            if (this.isListening) {
                this.isListening = false;
                this.resetToReady(); // Optionally reset if it ends without a result being processed
            }
        };
    }

    /**
     * Handles clicks on the main microphone button.
     * Manages starting/stopping listening, or stopping TTS if active.
     */
    handleVoiceButtonClick() {
        if (this.isSpeaking) { // If agent is speaking, clicking button stops TTS
            if (speechSynthesis && speechSynthesis.speaking) {
                speechSynthesis.cancel(); // Stop TTS
            }
            this.resetToReady(); // Reset state
            this.statusMessage = "Agent silenced. Tap to start again.";
            return;
        }

        // If the component is in a general processing state (e.g., waiting for Apex), do nothing.
        // The button should ideally be visually disabled via the 'isProcessingVisuals' getter.
        if (this.isProcessing) {
            return;
        }

        // Toggle listening state
        if (!this.isListening) {
            this.startListening();
        } else {
            this.stopListening();
        }
    }

    /**
     * Attempts to start the speech recognition service.
     */
    startListening() {
        if (!this.recognition) {
            this.showError('Error', 'Speech recognition not initialized.');
            return;
        }
        try {
            this.isProcessing = false;
            this.isSpeaking = false;
            this.recognition.start();
        } catch (error) {
            console.error('Error starting recognition:', error);
            if (error.name === 'InvalidStateError') {
                this.initializeSpeechRecognition(); 
                this.statusMessage = "Mic busy. Please try again."
            } else {
                this.showError('Mic Error', 'Could not start listening.');
            }
            this.resetToReady();
        }
    }

    /**
     * Stops the speech recognition service if it's currently active.
     */
    stopListening() {
        if (this.recognition && this.isListening) {
            this.recognition.stop(); 
            this.isListening = false;
            this.statusMessage = 'Processing your command...';
        }
    }

    /**
     * Handles the interaction with the backend Apex method.
     * Sends the transcribed query and processes the response.
     * @param {string} queryText - The text transcribed from user's speech.
     */
    async handleAgentBackendInteraction(queryText) {
        this.isProcessing = true; 
        this.statusMessage = 'Accessing Agent Core...';

        try {
            console.log(queryText);
            let agentResponseText = await invokeAgentBackendMethod({ userMessage: queryText });
            this.isProcessing = false; // Backend call finished
            console.log(agentResponseText);
            
            agentResponseText=(JSON.parse(agentResponseText)).value;
            console.log(agentResponseText);

            if (agentResponseText !== null && agentResponseText !== undefined && agentResponseText.trim() !== "") {
                this.speakText(agentResponseText);
            } else {
                this.showError('Agent Interaction Error', 'Agent provided an empty response.');
                this.resetToReady();
            }
        } catch (error) {
            this.isProcessing = false;
            console.error('Error calling AgentIAInvoker.invokeJavaAction:', error);
            let errorMessage = 'An error occurred while contacting the agent.';
            if (error.body && error.body.message) {
                errorMessage = `Agent Error: ${error.body.message}`;
            } else if (error.message) {
                errorMessage = error.message;
            }
            this.showError('Agent Interaction Error', errorMessage);
            this.resetToReady();
        }
    }

    /**
     * Uses the browser's SpeechSynthesis API to speak the provided text.
     * @param {string} textToSpeak - The text that the agent should say.
     */
    speakText(textToSpeak) {
        if (!speechSynthesis) {
            this.showError('TTS Error', 'Speech Synthesis not supported.');
            this.resetToReady();
            return;
        }
        if (speechSynthesis.speaking) {
            speechSynthesis.cancel();
        }

        this.isSpeaking = true;
        this.statusMessage = 'Agent speaking...';

        const utterance = new SpeechSynthesisUtterance(textToSpeak);
        utterance.lang = 'en-US';

        utterance.onend = () => {
            this.isSpeaking = false;
            this.statusMessage = 'Tap the orb to start again';
            this.resetToReady();
        };

        utterance.onerror = (event) => {
            this.isSpeaking = false;
            console.error('Speech synthesis error:', event.error);
            this.showError('TTS Error', 'Could not synthesize speech: ' + event.error);
            this.resetToReady();
        };

        speechSynthesis.speak(utterance); // Initiate speech
    }

    /**
     * Resets the component's state to its initial ready state.
     * Stops any ongoing listening or speaking.
     */
    resetToReady() {
        this.isListening = false;
        this.isProcessing = false;
        this.isSpeaking = false;

        if (this.recognition && this.isListening) {
            this.recognition.abort();
        }
        if (speechSynthesis && speechSynthesis.speaking) {
            speechSynthesis.cancel();
        }
    }

    /**
     * Visually disables the component and shows an error message, typically if critical APIs are missing.
     * @param {string} label - A label indicating the reason for disabling (e.g., "Unsupported").
     */
    disableComponent(label) { 
        this.isProcessing = true;
        this.statusMessage = 'Component disabled: ' + label;
    }

    /**
     * Helper method to dispatch a toast notification.
     * @param {string} title - The title of the toast message.
     * @param {string} message - The main content of the toast message.
     * @param {string} [variant='error'] - The variant of the toast (e.g., 'error', 'success', 'warning', 'info').
     * @param {string} [mode='dismissible'] - The mode of the toast (e.g., 'dismissible', 'pester', 'sticky').
     */
    showError(title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: 'error',
                mode: 'dismissible'
            })
        );
        // Also update the component's status message for immediate visual feedback.
        this.statusMessage = `Error: ${message}`;
    }
}