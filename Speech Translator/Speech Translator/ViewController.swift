//
//  ViewController.swift
//  Speech Translator
//
//  Created by Ivan Pedrero on 20/02/21.
//

import UIKit
import AVFoundation
import iOSDropDown
import SpeechToText
import LanguageTranslator
import TextToSpeech

class ViewController: UIViewController {
    
    var speechToText: SpeechToText!
    var languageTranslator: LanguageTranslator!
    var textToSpeech: TextToSpeech!
    
    var isStreaming = false
    var accumulator = SpeechRecognitionResultsAccumulator()
    var player: AVAudioPlayer?
    var currentTranslation = String()
    
    var speechModel = "en-US_BroadbandModel"
    var translationCode = "en-ja"
    var translatedVoice = "ja-JP_EmiVoice"
    
    private var availableSpeechModels = Dictionary<String, String>()
    private var availableSpeechVoices = [Voice]()
    
    @IBOutlet weak var speechModelDropdown: DropDown!
    @IBOutlet weak var languageVoiceDropDown: DropDown!
    
    @IBOutlet weak var microphoneButton: UIButton!
    @IBOutlet weak var detectedSpeechTextView: UITextView!
    @IBOutlet weak var translationButton: UIButton!
    @IBOutlet weak var translatedSpeechTextView: UITextView!
    @IBOutlet weak var speechDetectionView: UIView!
    @IBOutlet weak var translationView: UIView!
    @IBOutlet weak var resetButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setTextViewDelegate()
        
        setUpStyle()
        
        setUpSpeechToText()
        setUpTranslator()
        setUpTextToSpeech()
        
        initRecognition()
    }
    
    func setTextViewDelegate() {
        detectedSpeechTextView.delegate = self
    }
    
    func setUpStyle() {
        resetButton.roundBorders(radius: 5)
        resetButton.drawShadow(radius: 8)
        
        microphoneButton.roundBorders(radius: 5)
        microphoneButton.drawShadow(radius: 2)
        
        translationButton.roundBorders(radius: 5)
        translationButton.drawShadow(radius: 2)
        
        detectedSpeechTextView.layer.borderWidth = 1
        detectedSpeechTextView.layer.borderColor = UIColor.systemGray5.cgColor
        detectedSpeechTextView.roundBorders(radius: 5)
        
        translatedSpeechTextView.layer.borderWidth = 1
        translatedSpeechTextView.layer.borderColor = UIColor.systemGray5.cgColor
        translatedSpeechTextView.roundBorders(radius: 5)
        
        speechDetectionView.roundBorders(radius: 10)
        speechDetectionView.drawShadow(radius: 15)
        
        translationView.roundBorders(radius: 10)
        translationView.drawShadow(radius: 15)
        
        speechModelDropdown.selectedRowColor = UIColor.systemTeal
        languageVoiceDropDown.selectedRowColor = UIColor.systemTeal
    }
    
    func setUpSpeechToText() {
        let authenticator = WatsonIAMAuthenticator(apiKey: Credentials.speechToTextApiKey)
        speechToText = SpeechToText(authenticator: authenticator)
        speechToText.serviceURL = Credentials.speechToTextUrl
        
        getSpeechToTextModels()
    }
    
    func setUpTranslator() {
        let authenticator = WatsonIAMAuthenticator(apiKey: Credentials.translatorApiKey)
        languageTranslator = LanguageTranslator(version: "2018-05-01", authenticator: authenticator)
        languageTranslator.serviceURL = Credentials.translatorUrl
    }
    
    func setUpTextToSpeech() {
        let authenticator = WatsonIAMAuthenticator(apiKey: Credentials.textToSpeechApiKey)
        textToSpeech = TextToSpeech(authenticator: authenticator)
        textToSpeech.serviceURL = Credentials.textToSpeechUrl
        
        getTextToSpeechLanguages()
    }
    
    private func getSpeechToTextModels() {
        speechToText.listModels() { [self]
            response, error in

                guard let speechModels = response?.result else {
                    print(error?.localizedDescription ?? "unknown error")
                    return
                }
                        
            for model in speechModels.models {
                if model.rate == 16000 {
                    let languageName = model.description.replacingOccurrences(of: " broadband model.", with: "")
                    self.availableSpeechModels.updateValue(model.name, forKey: languageName)
                    
                    print("Available speech to text models: ")
                    print("\(model.name) for language: \(languageName)")
                }
            }
            print("-------------------------------------")
            
            self.setSpeechModelData()
        }
    }
    
    private func setSpeechModelData() {
        let models = Array(availableSpeechModels.keys)
        speechModelDropdown.optionArray = models
        
        speechModelDropdown.didSelect {
            (selectedText , index ,id) in
            self.speechModel = self.getSpeechModelName(from: selectedText)
            
            print("Selected language: \(selectedText) for model: \(self.speechModel)")
            
            self.updateLanguageToTranslate()
        }
        
        // Initialize a value in the dropdown.
        DispatchQueue.main.async {
            self.speechModelDropdown.text = "US English"
        }
    }
    
    
    private func getSpeechModelName(from key: String) -> String {
        if self.availableSpeechModels.isEmpty {
            return ""
        }
        
        return self.availableSpeechModels[key] ?? ""
    }
    
    private func getTextToSpeechLanguages() {
        textToSpeech.listVoices() {
            response, error in

            guard let voices = response?.result else {
                print(error?.localizedDescription ?? "unknown error")
                return
            }
            
            self.availableSpeechVoices = voices.voices

            for voice in self.availableSpeechVoices {
                print(voice.language)
                print(voice.description)
                print(voice.name)
            }
            print("-------------------------------------")
            
            self.setLanguagesData()
        }
    }
    
    private func setLanguagesData() {
        var languages = [String]()
        for voice in availableSpeechVoices {
            languages.append(voice.description)
        }
        
        languageVoiceDropDown.optionArray = languages
        
        languageVoiceDropDown.didSelect {
            (selectedText , index ,id) in
            
            self.translatedVoice = self.getVoiceName(for: selectedText)
            
            print("Selected language: \(selectedText) for model: \(self.translatedVoice)")
            
            self.updateLanguageToTranslate()
        }
        
        // Initialize a value in the dropdown.
        DispatchQueue.main.async {
            self.languageVoiceDropDown.text = "Emi: Japanese (日本語) female voice. Dnn technology."
        }
    }
    
    private func getVoiceName(for description: String) -> String {
        if availableSpeechVoices.isEmpty {
            return ""
        }
        
        for voice in self.availableSpeechVoices {
            if voice.description == description {
                return voice.name
            }
        }
        
        return ""
    }
    
    private func updateLanguageToTranslate() {
        let toDetect = self.speechModel.components(separatedBy: "-").first
        let toTranslate = self.translatedVoice.components(separatedBy: "-").first
        
        self.translationCode = toDetect! + "-" + toTranslate!
        
        print("Translation to perform: \(self.translationCode)")
        
        // Reinitialize the recognition.
        initRecognition()
    }

    @IBAction func didPressMicrophoneButton(_ sender: UIButton) {
        if !isStreaming {
            startRecognition()
        } else {
            stopRecognition()
        }
    }
    
    @IBAction func didPressTranslateButton(_ sender: UIButton) {
        // Ensure there's a text.
        if self.currentTranslation == "" {
            return
        }
        
        // Synthesize the text
        textToSpeech.synthesize(text: self.currentTranslation, accept: "audio/wav", voice: translatedVoice) { (response, error) in
            if let error = error {
                print(error)
            }
            
            guard let data = response?.result else {
                print("Failed to synthesize text")
                return
            }
            
            do {
                self.player = try AVAudioPlayer(data: data)
                self.player!.play()
            } catch {
                print("Failed to create audio player.")
            }
        }
    }
    
    @IBAction func didPressResetButton(_ sender: UIButton) {
        if isStreaming {
            stopRecognition()
        }
        
        resetAudio()
    }
    
    private func initRecognition() {
        self.resetAudio()
        self.startRecognition()
        self.stopRecognition()
    }
    
    private func startRecognition() {
        isStreaming = true
        
        microphoneButton.setTitle("Stop Microphone", for: .normal)
        
        detectedSpeechTextView.disableEditing()
        
        var settings = RecognitionSettings(contentType: "audio/ogg;codecs=opus")
        settings.interimResults = true
        
        var callback = RecognizeCallback()
        callback.onError = { error in
            print(error)
        }
        callback.onResults = { results in
            if !self.isStreaming { return }
            
            self.accumulator.add(results: results)
            let textDetected = self.accumulator.bestTranscript
            
            // Display the detected speech.
            DispatchQueue.main.async {
                self.displayDetectedSpeech(speech: textDetected)
            }
            
            self.translate(textSpeech: textDetected, manualInput: false)
        }
        
        speechToText.recognizeMicrophone(settings: settings, model: self.speechModel, baseModelVersion: nil, languageCustomizationID: nil, acousticCustomizationID: nil, learningOptOut: nil, customerID: nil, compress: false, configureSession: false, headers: nil, callback: callback)
    }
    
    private func stopRecognition() {
        isStreaming = false
        microphoneButton.setTitle("Start Microphone", for: .normal)
        detectedSpeechTextView.enableEditing()
        speechToText.stopRecognizeMicrophone()
    }
    
    private func resetAudio() {
        accumulator = SpeechRecognitionResultsAccumulator()
        self.detectedSpeechTextView.text = ""
        self.translatedSpeechTextView.text = ""
        self.currentTranslation = String()
    }
    
    private func translate(textSpeech: String, manualInput: Bool) {
        languageTranslator.translate(text: [textSpeech], modelID: translationCode) {
          response, error in
            
            if !self.isStreaming && !manualInput {
                return
            }

            guard let translation = response?.result else {
                let errorMessage = error?.localizedDescription ?? "unknown error"
                print(errorMessage)
                
                // Show an error message in the translation.
                DispatchQueue.main.async {
                    self.displayTranslation(translation: errorMessage)
                }
                
                return
            }
            
            self.currentTranslation = translation.translations[0].translation
            
            print(self.currentTranslation)
            
            // Display the translation.
            DispatchQueue.main.async {
                self.displayTranslation(translation: self.currentTranslation)
            }
        }
    }
    
    private func displayDetectedSpeech(speech: String) {
        self.detectedSpeechTextView.text = speech
    }
    
    private func displayTranslation(translation: String){
        self.translatedSpeechTextView.text = translation
    }
}

extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if isStreaming { return }
        
        print("Starting manual translation...")
        translate(textSpeech: textView.text, manualInput: true)
    }
}
