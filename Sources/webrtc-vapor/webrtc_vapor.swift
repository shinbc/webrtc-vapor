import WebRTC

public protocol WebRTCClientVaporDelegate {
    func didGenerateCandidate(iceCandidate: RTCIceCandidate)
    func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState)
    func didOpenDataChannel()
    func didReceiveData(data: Data)
    func didReceiveMessage(message: String)
    func didConnectWebRTC()
    func didDisconnectWebRTC()
}

public class WebRTCClientVapor: NSObject, RTCPeerConnectionDelegate, RTCVideoViewDelegate, RTCDataChannelDelegate {
    public var iceServers = [RTCIceServer]()
    
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnections: [Int32: RTCPeerConnection?] = [:]
    private var videoCapturer: RTCVideoCapturer!
    private var localVideoTrack: RTCVideoTrack!
    private var localAudioTrack: RTCAudioTrack!
    var remoteStreams: [RTCMediaStream] = []
    private var dataChannels: [RTCDataChannel?] = []
    private var remoteDataChannel: [RTCDataChannel?] = []
    private var channels: (video: Bool, audio: Bool, datachannel: Bool) = (false, false, false)
    private var customFrameCapturer: Bool = false
    private var cameraDevicePosition: AVCaptureDevice.Position = .front
    
    public var delegate: WebRTCClientVaporDelegate?
    public private(set) var isConnected: Bool = false
    
    func localVideoView() -> (RTCVideoTrack?, RTCAudioTrack?) {
        return (localVideoTrack, localAudioTrack)
    }
    
    func remoteVideoView() -> RTCMediaStream? {
        return remoteStreams.first
    }
    
    override init() {
        super.init()
        print("WebRTC Client initialize")
    }
    
    deinit {
        print("WebRTC Client Deinit")
        self.peerConnectionFactory = nil
        self.peerConnections = [:]
    }
    
    // MARK: - Public functions
    public func setup(videoTrack: Bool, audioTrack: Bool, dataChannel: Bool, customFrameCapturer: Bool){
        print("set up")
        self.channels.video = videoTrack
        self.channels.audio = audioTrack
        self.channels.datachannel = dataChannel
        self.customFrameCapturer = customFrameCapturer
        
        var videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        var videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        
        self.peerConnectionFactory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        
        setupView()
        setupLocalTracks()
        
        if self.channels.video {
            startCaptureLocalVideo(cameraPositon: self.cameraDevicePosition, videoWidth: 720, videoHeight: 720*16/9, videoFps: 30)
            
            //self.localVideoTrack?.add(self.localRenderView!)
        }
    }
    
    func setupLocalViewFrame() {
//        localView.frame = frame
//        localRenderView?.frame = localView.frame
    }
    
    func setupRemoteViewFrame() {
//        remoteView.frame = frame
//        remoteRenderView?.frame = remoteView.frame
    }
    
    func switchCameraPosition() {
        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
            capturer.stopCapture {
                let position = (self.cameraDevicePosition == .front) ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
                self.cameraDevicePosition = position
                self.startCaptureLocalVideo(cameraPositon: position, videoWidth: 720, videoHeight: 720*16/9, videoFps: 30)
            }
        }
    }
    
    // MARK: Connect
    func connect(index: Int32, onSuccess: @escaping (RTCSessionDescription) -> Void) {
        if index > 0 {
            guard let peerConnection = setupPeerConnection() else { return }
            peerConnection.delegate = self
            
            if let stream = self.remoteStreams.first {
                if let videoTrack = stream.videoTracks.first {
                    
                    let videoSource = videoTrack.source// self.peerConnectionFactory.videoSource()
                    
                    self.videoCapturer = RTCVideoCapturer(delegate: videoSource)
                    
                    let videoTrack2 = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
                    
                    peerConnection.add(videoTrack, streamIds: ["stream0"])

                    print("remote stream added to ads")
                    
                    
                    //            capturer.startCapture(with: targetDevice!,
                    //                                  format: targetFormat!,
                    //                                  fps: videoFps)

                }
            }
            
            if self.channels.datachannel {
                let dataChannel = self.setupDataChannel(forPeerConnection: peerConnection)
                dataChannel.delegate = self
                self.dataChannels.append(dataChannel)
            }
            
            self.peerConnections[index] = peerConnection
            
            makeOffer(index: index, onSuccess: onSuccess)
            
            
            return
        }
        guard let peerConnection = setupPeerConnection() else { return }
        peerConnection.delegate = self
        
        if self.channels.video {
            peerConnection.add(localVideoTrack, streamIds: ["stream0"])
        }
        if self.channels.audio {
            peerConnection.add(localAudioTrack, streamIds: ["stream0"])
        }
        if self.channels.datachannel {
            let dataChannel = self.setupDataChannel(forPeerConnection: peerConnection)
            dataChannel.delegate = self
            self.dataChannels.append(dataChannel)
        }
        
        self.peerConnections[index] = peerConnection
        makeOffer(index: index, onSuccess: onSuccess)
    }
    
    // MARK: HangUp
    func disconnect(){
        self.peerConnections.forEach({$0.value?.close()})
    }
    
    // MARK: Signaling Event
    func receiveOffer(index: Int32, offerSDP: RTCSessionDescription, onCreateAnswer: @escaping (RTCSessionDescription) -> Void){
        if index > 0 {
            guard let peerConnection = setupPeerConnection() else { return }
            peerConnection.delegate = self
            
            if let stream = self.remoteStreams.first {
                if let videoTrack = stream.videoTracks.first {
                    
                    let videoSource = videoTrack.source// self.peerConnectionFactory.videoSource()
                    
                    self.videoCapturer = RTCVideoCapturer(delegate: videoSource)
                    
                    let videoTrack2 = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
                    
                    peerConnection.add(videoTrack, streamIds: ["stream0"])

                    print("remote stream added to ads")
                    
                    
                    //            capturer.startCapture(with: targetDevice!,
                    //                                  format: targetFormat!,
                    //                                  fps: videoFps)

                }
            }
            
            if self.channels.datachannel {
                let dataChannel = self.setupDataChannel(forPeerConnection: peerConnection)
                dataChannel.delegate = self
                self.dataChannels.append(dataChannel)
            }
            
            self.peerConnections[index] = peerConnection
            //if index < peerConnections.count {
            self.peerConnections[index]??.setRemoteDescription(offerSDP) { (err) in
                    if let error = err {
                        print("failed to set remote offer SDP")
                        print(error)
                        return
                    }
                    
                    print("succeed to set remote offer SDP")
                    self.makeAnswer(index: index, onCreateAnswer: onCreateAnswer)
                }
            //}
            
            return
        }
        
        
        
        
        
        
        if peerConnections[index] == nil {
            print("offer received, create peerconnection")
            guard let peerConnection = setupPeerConnection() else { return }
            peerConnection.delegate = self
            if self.channels.video {
                peerConnection.add(localVideoTrack, streamIds: ["stream-0"])
            }
            if self.channels.audio {
                peerConnection.add(localAudioTrack, streamIds: ["stream-0"])
            }
            if self.channels.datachannel {
                let dataChannel = self.setupDataChannel(forPeerConnection: peerConnection)
                dataChannel.delegate = self
                self.dataChannels.append(dataChannel)
            }
            self.peerConnections[index] = peerConnection
            self.peerConnections[index]??.setRemoteDescription(offerSDP) { (err) in
                if let error = err {
                    print("failed to set remote offer SDP")
                    print(error)
                    return
                }
                
                print("succeed to set remote offer SDP")
                self.makeAnswer(index: index, onCreateAnswer: onCreateAnswer)
            }
        }
        
        if index < peerConnections.count {
            print("set remote description")
            
        }
        
    }
    
    func receiveAnswer(index: Int32, answerSDP: RTCSessionDescription) {
//        if index >= peerConnections.count {
//            return
//        }
        self.peerConnections[index]??.setRemoteDescription(answerSDP) { (err) in
            if let error = err {
                print("failed to set remote answer SDP")
                print(error)
                return
            }
        }
    }
    
    func receiveCandidate(index: Int32, candidate: RTCIceCandidate) {
        //if index < self.peerConnections.count {
            self.peerConnections[index]??.add(candidate)
        //}
    }
    
    
    // MARK: DataChannel Event
    func sendMessge(message: String){
        for dataChannel in dataChannels {
            if let _dataChannel = dataChannel {
                if _dataChannel.readyState == .open {
                    let buffer = RTCDataBuffer(data: message.data(using: String.Encoding.utf8)!, isBinary: false)
                    _dataChannel.sendData(buffer)
                }else {
                    
                    print("data channel is not ready state")
                }
            }else{
                print("no data channel")
            }
        }
        
    }
    
    func sendData(data: Data) {
//        if let _dataChannel = self.remoteDataChannel {
//            if _dataChannel.readyState == .open {
//                let buffer = RTCDataBuffer(data: data, isBinary: true)
//                _dataChannel.sendData(buffer)
//            }
//        }
    }
    
    func captureCurrentFrame(sampleBuffer: CMSampleBuffer){
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturerVapor {
            capturer.capture(sampleBuffer)
        }
    }
    
    func captureCurrentFrame(sampleBuffer: CVPixelBuffer){
        if let capturer = self.videoCapturer as? RTCCustomFrameCapturerVapor {
            capturer.capture(sampleBuffer)
        }
    }
    
    // MARK: - Private functions
    // MARK: - Setup
    private func setupPeerConnection() -> RTCPeerConnection? {
        let rtcConf = RTCConfiguration()
        rtcConf.iceServers = self.iceServers
//        [RTCIceServer(urlStrings: ["stun:global.stun.twilio.com:3478?transport=udp"]),
//                              RTCIceServer(urlStrings: ["turn:global.turn.twilio.com:3478?transport=udp"], username: "ed34d142be056d219d860c1bc2a906a9b7b78ff2aa166009baef29c7506283bc", credential: "aCP9t4jjR7gBcU3txa8HvUq270OsNLuMpNiRo23Hvh0"),
//                              RTCIceServer(urlStrings: ["turn:global.turn.twilio.com:443?transport=tcp"], username: "ed34d142be056d219d860c1bc2a906a9b7b78ff2aa166009baef29c7506283bc", credential: "aCP9t4jjR7gBcU3txa8HvUq270OsNLuMpNiRo23Hvh0=")]

//        rtcConf.iceServers = iceServers
        
        let mediaConstraints = RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: nil)
        let pc = self.peerConnectionFactory.peerConnection(with: rtcConf, constraints: mediaConstraints, delegate: nil)
        
        return pc
    }
    
    private func setupView() {
        // local
//        localRenderView = RTCEAGLVideoView()
//        localRenderView!.delegate = self
//        localView = UIView()
//        localView.addSubview(localRenderView!)
//        // remote
//        remoteRenderView = RTCEAGLVideoView()
//        remoteRenderView?.delegate = self
//        remoteView = UIView()
//        remoteView.addSubview(remoteRenderView!)
    }
    
    //MARK: - Local Media
    private func setupLocalTracks() {
        if self.channels.video == true {
            self.localVideoTrack = createVideoTrack()
        }
        if self.channels.audio == true {
            self.localAudioTrack = createAudioTrack()
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.peerConnectionFactory.audioSource(with: audioConstrains)
        let audioTrack = self.peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        
        // audioTrack.source.volume = 10
        return audioTrack
    }
    
    private func createVideoTrack() -> RTCVideoTrack {
        let videoSource = self.peerConnectionFactory.videoSource()
        
        if self.customFrameCapturer {
            self.videoCapturer = RTCCustomFrameCapturerVapor(delegate: videoSource)
        } else {
            self.videoCapturer = RTCCustomFrameCapturerVapor(delegate: videoSource)
        }
        let videoTrack = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
        
        return videoTrack
    }
    
    private func startCaptureLocalVideo(cameraPositon: AVCaptureDevice.Position, videoWidth: Int, videoHeight: Int?, videoFps: Int) {
//        if let capturer = self.videoCapturer as? RTCCameraVideoCapturer {
//            var targetDevice: AVCaptureDevice?
//            var targetFormat: AVCaptureDevice.Format?
//
//            // find target device
//            let devicies = RTCCameraVideoCapturer.captureDevices()
//            devicies.forEach { (device) in
//                if device.position ==  cameraPositon{
//                    targetDevice = device
//                }
//            }
//
//            // find target format
//            let formats = RTCCameraVideoCapturer.supportedFormats(for: targetDevice!)
//            formats.forEach { (format) in
//                for _ in format.videoSupportedFrameRateRanges {
//                    let description = format.formatDescription as CMFormatDescription
//                    let dimensions = CMVideoFormatDescriptionGetDimensions(description)
//
//                    if dimensions.width == videoWidth && dimensions.height == videoHeight ?? 0{
//                        targetFormat = format
//                    } else if dimensions.width == videoWidth {
//                        targetFormat = format
//                    }
//                }
//            }
//
//            capturer.startCapture(with: targetDevice!,
//                                  format: targetFormat!,
//                                  fps: videoFps)
//        } else if let capturer = self.videoCapturer as? RTCFileVideoCapturer{
//            print("setup file video capturer")
//            if let _ = Bundle.main.path( forResource: "sample.mp4", ofType: nil ) {
//                capturer.startCapturing(fromFileNamed: "sample.mp4") { (err) in
//                    print(err)
//                }
//            }else{
//                print("file did not faund")
//            }
//        }
    }
    
    // MARK: - Local Data
    // MARK: - Local Data
    private func setupDataChannel(forPeerConnection pc: RTCPeerConnection) -> RTCDataChannel {
        let dataChannelConfig = RTCDataChannelConfiguration()
        dataChannelConfig.channelId = 0
        
        let _dataChannel = pc.dataChannel(forLabel: "dataChannel", configuration: dataChannelConfig)
        return _dataChannel!
    }
    
    // MARK: - Signaling Offer/Answer
    private func makeOffer(index: Int32, onSuccess: @escaping (RTCSessionDescription) -> Void) {
        self.peerConnections[index]??.offer(for: RTCMediaConstraints.init(mandatoryConstraints: nil, optionalConstraints: nil)) { (sdp, err) in
            if let error = err {
                print("error with make offer")
                print(error)
                return
            }
            
            if let offerSDP = sdp {
                print("make offer, created local sdp")
                self.peerConnections[index]??.setLocalDescription(offerSDP, completionHandler: { (err) in
                    if let error = err {
                        print("error with set local offer sdp")
                        print(error)
                        return
                    }
                    print("succeed to set local offer SDP")
                    onSuccess(offerSDP)
                })
            }
            
        }
    }
    
    private func makeAnswer(index: Int32, onCreateAnswer: @escaping (RTCSessionDescription) -> Void){
        self.peerConnections[index]??.answer(for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil), completionHandler: { (answerSessionDescription, err) in
            if let error = err {
                print("failed to create local answer SDP")
                print(error)
                return
            }
            
            print("succeed to create local answer SDP")
            if let answerSDP = answerSessionDescription{
                self.peerConnections[index]??.setLocalDescription( answerSDP, completionHandler: { (err) in
                    if let error = err {
                        print("failed to set local ansewr SDP")
                        print(error)
                        return
                    }
                    
                    print("succeed to set local answer SDP")
                    onCreateAnswer(answerSDP)
                })
            }
        })
    }
    
    // MARK: - Connection Events
    private func onConnected() {
        self.isConnected = true
        
        DispatchQueue.main.async {
            //self.remoteRenderView?.isHidden = false
            self.delegate?.didConnectWebRTC()
        }
    }
    
    private func onDisConnected() {
        self.isConnected = false
        
        DispatchQueue.main.async {
            print("--- on dis connected ---")
            self.peerConnections.forEach { (pc) in
                pc.value?.close()
            }
            self.peerConnections = [:]
            self.dataChannels = []
            self.delegate?.didDisconnectWebRTC()
        }
    }
}

// MARK: - PeerConnection Delegeates
extension WebRTCClientVapor {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        var state = ""
        if stateChanged == .stable{
            state = "stable"
        }
        
        if stateChanged == .closed{
            state = "closed"
        }
        
        print("signaling state changed: ", state)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        
        switch newState {
        case .connected, .completed:
            if !self.isConnected {
                self.onConnected()
            }
        default:
            if self.isConnected{
                self.onDisConnected()
            }
        }
        
        DispatchQueue.main.async {
            self.delegate?.didIceConnectionStateChanged(iceConnectionState: newState)
        }
    }
    
    func replaceStream() {
        if let stream = self.remoteStreams.first {
            if let videoTrack = stream.videoTracks.first {
                
                let videoSource = videoTrack.source// self.peerConnectionFactory.videoSource()
                
                self.videoCapturer = RTCVideoCapturer(delegate: videoSource)
                
                let videoTrack2 = self.peerConnectionFactory.videoTrack(with: videoSource, trackId: "video0")
                
                if let f = peerConnections.first {
                    f.value?.add(videoTrack2, streamIds: ["stream0"])
                }
                
                
                
                //            capturer.startCapture(with: targetDevice!,
                //                                  format: targetFormat!,
                //                                  fps: videoFps)

            }
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("did add stream")
        self.remoteStreams.append(stream)
        
        if let track = stream.videoTracks.first {
            print("video track faund")
            //track.add(remoteRenderView!)
        }
        
        if let audioTrack = stream.audioTracks.first{
            print("audio track faund")
            audioTrack.source.volume = 8
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.didGenerateCandidate(iceCandidate: candidate)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("--- did remove stream ---")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        remoteDataChannel.append(dataChannel)
        self.delegate?.didOpenDataChannel()
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
}

// MARK: - RTCVideoView Delegate
extension WebRTCClientVapor{
    public func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
//        let isLandScape = size.width < size.height
//        var renderView: RTCEAGLVideoView?
//        var parentView: UIView?
//        if videoView.isEqual(localRenderView){
//            print("local video size changed")
//            renderView = localRenderView
//            parentView = localView
//        }
//
//        if videoView.isEqual(remoteRenderView!){
//            print("remote video size changed to: ", size)
//            renderView = remoteRenderView
//            parentView = remoteView
//        }
//
//        guard let _renderView = renderView, let _parentView = parentView else {
//            return
//        }
//
//        if(isLandScape){
//            let ratio = size.width / size.height
//            _renderView.frame = CGRect(x: 0, y: 0, width: _parentView.frame.height * ratio, height: _parentView.frame.height)
//            _renderView.center.x = _parentView.frame.width/2
//        }else{
//            let ratio = size.height / size.width
//            _renderView.frame = CGRect(x: 0, y: 0, width: _parentView.frame.width, height: _parentView.frame.width * ratio)
//            _renderView.center.y = _parentView.frame.height/2
//        }
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCClientVapor {
    public func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        //DispatchQueue.main.async {
            if buffer.isBinary {
                self.delegate?.didReceiveData(data: buffer.data)
            }else {
                self.delegate?.didReceiveMessage(message: String(data: buffer.data, encoding: String.Encoding.utf8)!)
            }
        //}
    }
    
    public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("data channel did change state")
        switch dataChannel.readyState {
        case .closed:
            print("closed")
        case .closing:
            print("closing")
        case .connecting:
            print("connecting")
        case .open:
            print("open")
        }
    }
}
