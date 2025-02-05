 /*Copyright (c) 2016, Andrew Walz.

Redistribution and use in source and binary forms, with or without modification,are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import UIKit
import AVFoundation

// MARK: View Controller Declaration

/// A UIViewController Camera View Subclass

open class SwiftyCamViewController: UIViewController {

	// MARK: Enumeration Declaration

	/// Enumeration for Camera Selection

    public enum CameraSelection: String {

		/// Camera on the back of the device
		case rear = "rear"

		/// Camera on the front of the device
		case front = "front"

        public var captureDevicePosition: AVCaptureDevice.Position {
            switch self {
            case .rear: .back
            case .front: .front
            }
        }
	}
    
	/// Enumeration for video quality of the capture session. Corresponds to a AVCaptureSessionPreset


	public enum VideoQuality {

		/// AVCaptureSessionPresetHigh
		case high

		/// AVCaptureSessionPresetMedium
		case medium

		/// AVCaptureSessionPresetLow
		case low

		/// AVCaptureSessionPreset352x288
		case resolution352x288

		/// AVCaptureSessionPreset640x480
		case resolution640x480

		/// AVCaptureSessionPreset1280x720
		case resolution1280x720

		/// AVCaptureSessionPreset1920x1080
		case resolution1920x1080

		/// AVCaptureSessionPreset3840x2160
		case resolution3840x2160

		/// AVCaptureSessionPresetiFrame960x540
		case iframe960x540

		/// AVCaptureSessionPresetiFrame1280x720
		case iframe1280x720
	}

	/**

	Result from the AVCaptureSession Setup

	- success: success
	- notAuthorized: User denied access to Camera of Microphone
	- configurationFailed: Unknown error
	*/

	fileprivate enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}

	// MARK: Public Variable Declarations

	/// Public Camera Delegate for the Custom View Controller Subclass

	public weak var cameraDelegate: SwiftyCamViewControllerDelegate?

	/// Video capture quality

	public var videoQuality : VideoQuality       = .high

	/// Sets whether Pinch to Zoom is enabled for the capture session

	public var pinchToZoom                       = true

	/// Sets the maximum zoom scale allowed during gestures gesture

	public var maxZoomScale				         = CGFloat.greatestFiniteMagnitude

	/// Sets whether Tap to Focus and Tap to Adjust Exposure is enabled for the capture session

	public var tapToFocus                        = true

	/// Sets whether the capture session should adjust to low light conditions automatically
	///
	/// Only supported on iPhone 5 and 5C

	public var lowLightBoost                     = true

	/// Set whether SwiftyCam should allow background audio from other applications

	public var allowBackgroundAudio              = true

	/// Sets whether a double tap to switch cameras is supported

	public var doubleTapCameraSwitch            = true

    /// Sets whether swipe vertically to zoom is supported

    public var swipeToZoom                     = true

    /// Sets whether swipe vertically gestures should be inverted

    public var swipeToZoomInverted             = false

	/// Set default launch camera

	public var defaultCamera                   = CameraSelection.rear

    /// Sets whether or not View Controller supports auto rotation

    public var allowAutoRotate                = false

    /// Specifies the [videoGravity](https://developer.apple.com/reference/avfoundation/avcapturevideopreviewlayer/1386708-videogravity) for the preview layer.
    public var videoGravity                   : SwiftyCamVideoGravity = .resizeAspect

    /// Sets whether or not video recordings will record audio
    /// Setting to true will prompt user for access to microphone on View Controller launch.
    public var audioEnabled                   = true

    /// Sets whether or not app should display prompt to app settings if audio/video permission is denied
    /// If set to false, delegate function will be called to handle exception
    public var shouldPrompToAppSettings       = true

    /// Video will be recorded to this folder
    public var outputFolder: String           = NSTemporaryDirectory()
    
    /// Public access to Pinch Gesture
    fileprivate(set) public var pinchGesture  : UIPinchGestureRecognizer!

    /// Public access to Pan Gesture
    fileprivate(set) public var panGesture    : UIPanGestureRecognizer!


	// MARK: Public Get-only Variable Declarations

	/// Returns true if video is currently being recorded

	private(set) public var isVideoRecording      = false

	/// Returns true if the capture session is currently running

	private(set) public var isSessionRunning     = false

	/// Returns the CameraSelection corresponding to the currently utilized camera

	private(set) public var currentCamera        = CameraSelection.rear

	// MARK: Private Constant Declarations

	/// Current Capture Session

	public let session                           = AVCaptureSession()

	/// Serial queue used for setting up session

	fileprivate let sessionQueue                 = DispatchQueue(label: "session queue", attributes: [])

	// MARK: Private Variable Declarations

	/// Variable for storing current zoom scale

	fileprivate var zoomScale                    = CGFloat(1.0)

	/// Variable for storing initial zoom scale before Pinch to Zoom begins

	fileprivate var beginZoomScale               = CGFloat(1.0)

	/// Variable to store result of capture session setup

	fileprivate var setupResult                  = SessionSetupResult.success

	/// BackgroundID variable for video recording

	fileprivate var backgroundRecordingID        : UIBackgroundTaskIdentifier? = nil

	/// Video Input variable

	fileprivate var videoDeviceInput             : AVCaptureDeviceInput!

	/// Movie File Output variable

	fileprivate var movieFileOutput              : AVCaptureMovieFileOutput?

	/// Video Device variable

	fileprivate var videoDevice                  : AVCaptureDevice?

	/// PreviewView for the capture session

	fileprivate var previewLayer                 : PreviewView!

    /// Pan Translation

    fileprivate var previousPanTranslation       : CGFloat = 0.0

    /// Boolean to store when View Controller is notified session is running

    fileprivate var sessionRunning               = false

	/// Disable view autorotation for forced portrait recorindg

	override open var shouldAutorotate: Bool {
		return allowAutoRotate
	}

    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }

	/// Sets output video codec
    
    public var videoCodecType: AVVideoCodecType? = nil

	// MARK: ViewDidLoad

	/// ViewDidLoad Implementation

	override open func viewDidLoad() {
		super.viewDidLoad()
        previewLayer = PreviewView(frame: view.frame, videoGravity: videoGravity)
        previewLayer.center = view.center
        view.addSubview(previewLayer)
        view.sendSubviewToBack(previewLayer)

		// Add Gesture Recognizers

        addGestureRecognizers()

		previewLayer.session = session

		// Test authorization status for Camera and Micophone

		switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
		case .authorized:

			// already authorized
			break
		case .notDetermined:

			// not yet determined
			sessionQueue.suspend()
			AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
				if !granted {
					self.setupResult = .notAuthorized
				}
				self.sessionQueue.resume()
			})
		default:

			// already been asked. Denied access
			setupResult = .notAuthorized
		}
		sessionQueue.async { [unowned self] in
			self.configureSession()
		}
	}

    // MARK: ViewDidLayoutSubviews

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer.frame = view.bounds
    }

    // MARK: ViewWillAppear

    /// ViewWillAppear(_ animated:) Implementation

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionDidStartRunning), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(captureSessionDidStopRunning),  name: .AVCaptureSessionDidStopRunning,  object: nil)
    }

	// MARK: ViewDidAppear

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?

    private var rotationAngleObservation: Any?

	/// ViewDidAppear(_ animated:) Implementation
	override open func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// Subscribe to device rotation notifications
		if let videoDevice {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: videoDevice, previewLayer: previewLayer.videoPreviewLayer)
            rotationAngleObservation = rotationCoordinator?.observe(\.videoRotationAngleForHorizonLevelPreview, changeHandler: { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                self.previewLayer.videoPreviewLayer.connection?.videoRotationAngle = angle
            })
		}

		// Set background audio preference

		setBackgroundAudioPreference()

		sessionQueue.async {
			switch self.setupResult {
			case .success:
				// Begin Session
				self.session.startRunning()
				self.isSessionRunning = self.session.isRunning

                // Now we can update the video angle on the connection
                DispatchQueue.main.async {
                    if let coordinator = self.rotationCoordinator {
                        self.previewLayer.videoPreviewLayer.connection?.videoRotationAngle = coordinator.videoRotationAngleForHorizonLevelPreview
                    }
                }

			case .notAuthorized:
                if self.shouldPrompToAppSettings == true {
                    self.promptToAppSettings()
                } else {
                    self.cameraDelegate?.swiftyCamNotAuthorized(self)
                }

            case .configurationFailed:
				// Unknown Error
                DispatchQueue.main.async {
                    self.cameraDelegate?.swiftyCamDidFailToConfigure(self)
                }
			}
		}
	}

	// MARK: ViewDidDisappear

	/// ViewDidDisappear(_ animated:) Implementation


	override open func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self)
        sessionRunning = false

		// If session is running, stop the session
		if self.isSessionRunning == true {
			self.session.stopRunning()
			self.isSessionRunning = false
		}

		// Unsubscribe from device rotation notifications
        rotationCoordinator = nil
	}

	// MARK: Public Functions

	/**

	Begin recording video of current session

	SwiftyCamViewControllerDelegate function SwiftyCamDidBeginRecordingVideo() will be called

	*/

	public func startVideoRecording() {

        guard sessionRunning == true else {
            print("[SwiftyCam]: Cannot start video recoding. Capture session is not running")
            return
        }
		guard let movieFileOutput = self.movieFileOutput else {
			return
		}

		sessionQueue.async { [unowned self] in
			if !movieFileOutput.isRecording {
				if UIDevice.current.isMultitaskingSupported {
					self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
				}

				// Update the angle on the movie file output video connection before starting recording.
				let movieFileOutputConnection = self.movieFileOutput?.connection(with: AVMediaType.video)

				// Flip video output if front facing camera is selected
				if self.currentCamera == .front {
					movieFileOutputConnection?.isVideoMirrored = true
				}

                if let rotationCoordinator {
                    movieFileOutputConnection?.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
                }

				// Start recording to a temporary file.
				let outputFileName = UUID().uuidString
				let outputFilePath = (self.outputFolder as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
				movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
				self.isVideoRecording = true
				DispatchQueue.main.async {
					self.cameraDelegate?.swiftyCam(self, didBeginRecordingVideo: self.currentCamera)
				}
			}
			else {
				movieFileOutput.stopRecording()
			}
		}
	}

	/**

	Stop video recording video of current session

	SwiftyCamViewControllerDelegate function SwiftyCamDidFinishRecordingVideo() will be called

	When video has finished processing, the URL to the video location will be returned by SwiftyCamDidFinishProcessingVideoAt(url:)

	*/

	public func stopVideoRecording() {
		if self.isVideoRecording == true {
			self.isVideoRecording = false
			movieFileOutput!.stopRecording()

			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didFinishRecordingVideo: self.currentCamera)
			}
		}
	}

	/**

	Switch between front and rear camera

	SwiftyCamViewControllerDelegate function SwiftyCamDidSwitchCameras(camera:  will be return the current camera selection

	*/


	public func switchCamera() {
		guard isVideoRecording != true else {
			//TODO: Look into switching camera during video recording
			print("[SwiftyCam]: Switching between cameras while recording video is not supported")
			return
		}

        guard session.isRunning == true else {
            return
        }

		switch currentCamera {
		case .front:
			currentCamera = .rear
		case .rear:
			currentCamera = .front
		}

		session.stopRunning()

		sessionQueue.async { [unowned self] in

			// remove and re-add inputs and outputs

			for input in self.session.inputs {
				self.session.removeInput(input )
			}

			self.addInputs()
			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didSwitchCameras: self.currentCamera)
			}

			self.session.startRunning()
		}
	}

	// MARK: Private Functions

	/// Configure session, add inputs and outputs

	fileprivate func configureSession() {
		guard setupResult == .success else {
			return
		}

		// Set default camera

		currentCamera = defaultCamera

		// begin configuring session

		session.beginConfiguration()
		configureVideoPreset()
		addVideoInput()
		addAudioInput()
		configureVideoOutput()

		session.commitConfiguration()
	}

	/// Add inputs after changing camera()

	fileprivate func addInputs() {
		session.beginConfiguration()
		configureVideoPreset()
		addVideoInput()
		addAudioInput()
		session.commitConfiguration()
	}


	// Front facing camera will always be set to VideoQuality.high
	// If set video quality is not supported, videoQuality variable will be set to VideoQuality.high
	/// Configure image quality preset

	fileprivate func configureVideoPreset() {
		if currentCamera == .front {
			session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: .high))
		} else {
			if session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))) {
				session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))
			} else {
				session.sessionPreset = AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: .high))
			}
		}
	}

	/// Add Video Inputs

	fileprivate func addVideoInput() {
        videoDevice = SwiftyCamViewController.defaultCaptureDevice(preferringPosition: currentCamera.captureDevicePosition)
        guard let videoDevice else { return }

		do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("[SwiftyCam]: Could not add video device input to the session")
                print(session.canSetSessionPreset(AVCaptureSession.Preset(rawValue: videoInputPresetFromVideoQuality(quality: videoQuality))))
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            print("[SwiftyCam]: Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }

        do {
            try videoDevice.lockForConfiguration()
		} catch {
			print("[SwiftyCam]: Could not lock video device for configuration: \(error)")
			setupResult = .configurationFailed
            return
		}

        if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
            videoDevice.focusMode = .continuousAutoFocus
            if videoDevice.isSmoothAutoFocusSupported {
                videoDevice.isSmoothAutoFocusEnabled = true
            }
        }

        if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
            videoDevice.exposureMode = .continuousAutoExposure
        }

        if videoDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            videoDevice.whiteBalanceMode = .continuousAutoWhiteBalance
        }

        if videoDevice.isLowLightBoostSupported && lowLightBoost == true {
            videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
        }

        // Start out using the wide camera focal length when we have a triple or dual-wide cam.
        // This must be done after adding the video device input to the session.
        let zoomBoundaries = videoDevice.virtualDeviceSwitchOverVideoZoomFactors
        if videoDevice.deviceType == .builtInTripleCamera, let zoom = zoomBoundaries.first?.doubleValue {
            videoDevice.videoZoomFactor = zoom
        } else if videoDevice.deviceType == .builtInDualWideCamera, let zoom = zoomBoundaries.first?.doubleValue {
            videoDevice.videoZoomFactor = zoom
        }

        videoDevice.unlockForConfiguration()
    }

	/// Add Audio Inputs

	fileprivate func addAudioInput() {
        guard audioEnabled == true else {
            return
        }
		do {
            if let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio){
                let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioDeviceInput) {
                    session.addInput(audioDeviceInput)
                } else {
                    print("[SwiftyCam]: Could not add audio device input to the session")
                }
                
            } else {
                print("[SwiftyCam]: Could not find an audio device")
            }
            
		} catch {
			print("[SwiftyCam]: Could not create audio device input: \(error)")
		}
	}

	/// Configure Movie Output

	fileprivate func configureVideoOutput() {
		let movieFileOutput = AVCaptureMovieFileOutput()

		if self.session.canAddOutput(movieFileOutput) {
			self.session.addOutput(movieFileOutput)
			if let connection = movieFileOutput.connection(with: AVMediaType.video) {
				if connection.isVideoStabilizationSupported {
					connection.preferredVideoStabilizationMode = .auto
				}

                if let videoCodecType = videoCodecType {
                    if movieFileOutput.availableVideoCodecTypes.contains(videoCodecType) == true {
                        // Use the H.264 codec to encode the video.
                        movieFileOutput.setOutputSettings([AVVideoCodecKey: videoCodecType], for: connection)
                    }
                }
			}
			self.movieFileOutput = movieFileOutput
		}
	}

	/// Handle Denied App Privacy Settings

	fileprivate func promptToAppSettings() {
		// prompt User with UIAlertView

		DispatchQueue.main.async(execute: { [unowned self] in
			let message = NSLocalizedString("AVCam doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
			let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
			alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
			alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .default, handler: { action in
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
			}))
			self.present(alertController, animated: true, completion: nil)
		})
	}

	/**
	Returns an AVCapturePreset from VideoQuality Enumeration

	- Parameter quality: ViewQuality enum

	- Returns: String representing a AVCapturePreset
	*/

	fileprivate func videoInputPresetFromVideoQuality(quality: VideoQuality) -> String {
		switch quality {
		case .high: return AVCaptureSession.Preset.high.rawValue
		case .medium: return AVCaptureSession.Preset.medium.rawValue
		case .low: return AVCaptureSession.Preset.low.rawValue
		case .resolution352x288: return AVCaptureSession.Preset.cif352x288.rawValue
		case .resolution640x480: return AVCaptureSession.Preset.vga640x480.rawValue
		case .resolution1280x720: return AVCaptureSession.Preset.hd1280x720.rawValue
		case .resolution1920x1080: return AVCaptureSession.Preset.hd1920x1080.rawValue
		case .iframe960x540: return AVCaptureSession.Preset.iFrame960x540.rawValue
		case .iframe1280x720: return AVCaptureSession.Preset.iFrame1280x720.rawValue
		case .resolution3840x2160: return AVCaptureSession.Preset.hd4K3840x2160.rawValue
		}
	}

	/// Get Devices

    fileprivate class func defaultCaptureDevice(preferringPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInDualCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
	}

	/// Sets whether SwiftyCam should enable background audio from other applications or sources

	fileprivate func setBackgroundAudioPreference() {
		guard allowBackgroundAudio == true else {
			return
		}

        guard audioEnabled == true else {
            return
        }

		do{
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowAirPlay, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
			session.automaticallyConfiguresApplicationAudioSession = false
		}
		catch {
			print("[SwiftyCam]: Failed to set background audio preference")

		}
	}

    /// Called when Notification Center registers session starts running

    @objc private func captureSessionDidStartRunning() {
        sessionRunning = true
        DispatchQueue.main.async {
            self.cameraDelegate?.swiftyCamSessionDidStartRunning(self)
        }
    }

    /// Called when Notification Center registers session stops running

    @objc private func captureSessionDidStopRunning() {
        sessionRunning = false
        DispatchQueue.main.async {
            self.cameraDelegate?.swiftyCamSessionDidStopRunning(self)
        }
    }
}

extension SwiftyCamViewController : SwiftyCamButtonDelegate {

	/// Begin video when the button is pressed down

	public func buttonDidBeginPress() {
		startVideoRecording()
	}

	/// End video when the button is released

	public func buttonDidEndPress() {
		stopVideoRecording()
	}
}

// MARK: AVCaptureFileOutputRecordingDelegate

extension SwiftyCamViewController : AVCaptureFileOutputRecordingDelegate {

	/// Process newly captured video and write it to temporary directory

    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let currentBackgroundRecordingID = backgroundRecordingID {
            backgroundRecordingID = UIBackgroundTaskIdentifier.invalid

            if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
            }
        }

        if let currentError = error {
            print("[SwiftyCam]: Movie file finishing error: \(currentError)")
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didFailToRecordVideo: currentError)
            }
        } else {
            //Call delegate function with the URL of the outputfile
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didFinishProcessVideoAt: outputFileURL)
            }
        }
    }
}

// Mark: UIGestureRecognizer Declarations

extension SwiftyCamViewController {

	/// Handle pinch gesture

	@objc fileprivate func zoomGesture(pinch: UIPinchGestureRecognizer) {
		guard pinchToZoom == true && self.currentCamera == .rear else {
			//ignore pinch
			return
		}
		do {
            let captureDevice = Self.defaultCaptureDevice(preferringPosition: currentCamera.captureDevicePosition)
			try captureDevice?.lockForConfiguration()

			zoomScale = min(maxZoomScale, max(1.0, min(beginZoomScale * pinch.scale,  captureDevice!.activeFormat.videoMaxZoomFactor)))

			captureDevice?.videoZoomFactor = zoomScale

			// Call Delegate function with current zoom scale
			DispatchQueue.main.async {
				self.cameraDelegate?.swiftyCam(self, didChangeZoomLevel: self.zoomScale)
			}

			captureDevice?.unlockForConfiguration()

		} catch {
			print("[SwiftyCam]: Error locking configuration")
		}
	}

	/// Handle single tap gesture

	@objc fileprivate func singleTapGesture(tap: UITapGestureRecognizer) {
		guard tapToFocus == true else {
			// Ignore taps
			return
		}

		let screenSize = previewLayer!.bounds.size
		let tapPoint = tap.location(in: previewLayer!)
		let x = tapPoint.y / screenSize.height
		let y = 1.0 - tapPoint.x / screenSize.width
		let focusPoint = CGPoint(x: x, y: y)

		if let device = videoDevice {
			do {
				try device.lockForConfiguration()

				if device.isFocusPointOfInterestSupported == true {
					device.focusPointOfInterest = focusPoint
					device.focusMode = .autoFocus
				}
				device.exposurePointOfInterest = focusPoint
				device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
				device.unlockForConfiguration()
				//Call delegate function and pass in the location of the touch

				DispatchQueue.main.async {
					self.cameraDelegate?.swiftyCam(self, didFocusAtPoint: tapPoint)
				}
			}
			catch {
				// just ignore
			}
		}
	}

	/// Handle double tap gesture

	@objc fileprivate func doubleTapGesture(tap: UITapGestureRecognizer) {
		guard doubleTapCameraSwitch == true else {
			return
		}
		switchCamera()
	}

    @objc private func panGesture(pan: UIPanGestureRecognizer) {

        guard swipeToZoom == true && self.currentCamera == .rear else {
            //ignore pan
            return
        }
        let currentTranslation    = pan.translation(in: view).y
        let translationDifference = currentTranslation - previousPanTranslation

        do {
            let captureDevice = Self.defaultCaptureDevice(preferringPosition: currentCamera.captureDevicePosition)
            try captureDevice?.lockForConfiguration()

            let currentZoom = captureDevice?.videoZoomFactor ?? 0.0

            if swipeToZoomInverted == true {
                zoomScale = min(maxZoomScale, max(1.0, min(currentZoom - (translationDifference / 75),  captureDevice!.activeFormat.videoMaxZoomFactor)))
            } else {
                zoomScale = min(maxZoomScale, max(1.0, min(currentZoom + (translationDifference / 75),  captureDevice!.activeFormat.videoMaxZoomFactor)))

            }

            captureDevice?.videoZoomFactor = zoomScale

            // Call Delegate function with current zoom scale
            DispatchQueue.main.async {
                self.cameraDelegate?.swiftyCam(self, didChangeZoomLevel: self.zoomScale)
            }

            captureDevice?.unlockForConfiguration()

        } catch {
            print("[SwiftyCam]: Error locking configuration")
        }

        if pan.state == .ended || pan.state == .failed || pan.state == .cancelled {
            previousPanTranslation = 0.0
        } else {
            previousPanTranslation = currentTranslation
        }
    }

	/**
	Add pinch gesture recognizer and double tap gesture recognizer to currentView

	- Parameter view: View to add gesture recognzier

	*/

	fileprivate func addGestureRecognizers() {
		pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(zoomGesture(pinch:)))
		pinchGesture.delegate = self
		previewLayer.addGestureRecognizer(pinchGesture)

		let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTapGesture(tap:)))
		singleTapGesture.numberOfTapsRequired = 1
		singleTapGesture.delegate = self
		previewLayer.addGestureRecognizer(singleTapGesture)

		let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTapGesture(tap:)))
		doubleTapGesture.numberOfTapsRequired = 2
		doubleTapGesture.delegate = self
		previewLayer.addGestureRecognizer(doubleTapGesture)

        panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(pan:)))
        panGesture.delegate = self
        previewLayer.addGestureRecognizer(panGesture)
	}
}


// MARK: UIGestureRecognizerDelegate

extension SwiftyCamViewController : UIGestureRecognizerDelegate {

	/// Set beginZoomScale when pinch begins

	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
			beginZoomScale = zoomScale
		}
		return true
	}
}
