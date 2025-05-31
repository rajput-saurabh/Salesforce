# Agentforce AI's Voice Agent

## Overview

A voice-controlled agent built as a Lightning Web Component (LWC) for Salesforce. This agent allows users to perform common Salesforce actions using voice commands directly within the Salesforce UI, leveraging browser-native Speech-to-Text, Text-to-Speech and Agentforce capabilities.

## Features

* **Voice-Activated Commands:** Interact with Salesforce using natural language.
* **Modern & Futuristic UI:** Dark-themed interface with an interactive orb button and visual feedback (listening animations, processing indicators).
* **Record Creation via Voice:**
    * Create **Accounts** (e.g., "Agent, create new account FutureTech Solutions")
    * Create **Opportunities** (e.g., "Agent, create opportunity for FutureTech, amount 50000, stage Prospecting")
    * Create **Contacts** (e.g., "Agent, create contact John Doe, email john.doe@futuretech.com")
    * Create **Leads** (e.g., "Agent, create lead Jane Smith, company Innovate Corp")
    * Create **Campaigns** (e.g., "Agent, create campaign Q3 Product Launch")
* **Real-time Transcription:** Converts spoken words to text instantly.
* **Spoken Responses:** The agent provides audible feedback and responses.
* **Client-Side Processing:** Utilizes Web Speech API for STT/TTS, minimizing server load for voice processing.
* **Salesforce Backend Integration:** Leverages Agentforce to perform actions on Salesforce Platform.

## How It Works

1.  **Activation:** User clicks the microphone orb.
2.  **Listening:** The LWC uses the browser's `SpeechRecognition` API to listen for commands. Visual cues indicate the listening state.
3.  **Transcription:** Spoken commands are transcribed into text.
4.  **Processing:** The transcribed text is sent to an Apex class (`AIAgentInvoker`).
5.  **Action & Response:** The Agentforce processes the command (e.g., identifies intent to create a record, extracts details) and performs the actions using Apex classes. It then formulates a text response.
6.  **Feedback:** The LWC receives the text response and uses the browser's `SpeechSynthesis` API to give an audible response. The UI also updates with status messages.

## Technology Stack

* **Salesforce Lightning Web Components (LWC):** For the frontend UI and client-side logic.
* **Web Speech API (Browser-Native):**
    * `SpeechRecognition` for Speech-to-Text (STT).
    * `SpeechSynthesis` for Text-to-Speech (TTS).
* **Agentforce AI:** Identifies user intent, extracts the necessary information to create records, maps the intent to corresponding Apex actions, and executes them to create the records while providing an appropriate response to the user. .
* **Apex:** For server-side logic, Salesforce records creation.
* **HTML & CSS:** For structuring and styling the user interface.

## Setup

1.  **Enable Einstein and Agentforce:** Enable both Einstein and Agentforce individually through Setup.
2.  **Deploy LWC:** Deploy the `voiceAgent` LWC bundle (HTML, JS, CSS, js-meta.xml) to your Salesforce org.
3.  **Deploy Apex Classes:** Deploy the all the Apex classes.
4.  **Deploy Bot:** Before deployment, ensure that your Agentforce bot is disabled to avoid deployment errors.
5.  **Deploy genAi:** Deploy all folders starting with genAi.
6.  **Add to Page:** Add the `voiceAgent` LWC to any desired Lightning Page (App Page, Record Page, Home Page) using the Lightning App Builder.
7.  **Permissions:** Ensure users have microphone permissions enabled in their browser and are accessing Salesforce via HTTPS.

## Usage

1.  Navigate to the page where the `voiceAgent` LWC is placed.
2.  Click the microphone orb.
3.  When the listening animation appears and the status indicates it's listening, speak your command clearly.
    * **Example Commands:**
        * "Agent, create new account named Quantum Leap Inc."
        * "Create a contact, John Smith, for Quantum Leap Inc, email john@qli.com."
        * "New opportunity for Quantum Leap, deal size seventy five thousand dollars, closing next month, stage qualification."
        * "Create lead, Sarah Connor, company Cyberdyne Systems, status Open."
        * "Make a new campaign called Summer Expo 2025."
        * "just wrapped up 2 deal with a new client Salesforce can you help me create records into the system one is a new partnership deal for 2 million dollar closed on May 22nd and the other is a service renewal of 80000 closed on May 21st"
4.  Listen for the agent's spoken response and observe UI status messages.
