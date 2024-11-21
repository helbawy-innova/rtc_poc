import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key, required this.actionType, this.callId});

  final String actionType;
  final String? callId;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  CollectionReference signalingServer = FirebaseFirestore.instance.collection("calls");
  String callId = "";
  late RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  List<RTCIceCandidate> candidates = [];

  _createPeerConnection() async {
    await _startLocalStream();
    await _setPeerConnectionConfiguration();
    if (widget.actionType == "Join") {
      _joinCall(widget.callId!);
    }
    if (widget.actionType == "Create") {
      _createCallOffer();
    }
  }

  _setPeerConnectionConfiguration() async {
    //set the configuration of the peer connection
    final configuration = {
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302']
        }
      ]
    };
    //create peer connection
    _peerConnection = await createPeerConnection(configuration);
    //add the local stream to the peer connection
    // _peerConnection!.addStream(_localStream!);
    _localStream!.getVideoTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
    _localStream!.getAudioTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    //set the listener for receiving the remote stream of the other peer
    _peerConnection!.onAddStream = (MediaStream stream) async {
      print("Remote Stream:");
      print(stream.toString());
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };

    //set the listener for receiving your own ICE candidates and send them to the other peer
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _onReceivingOwnICECandidate(candidate);
      print("Candidate: ${candidate.candidate ?? "no"}");
    };
  }

  _startLocalStream() async {
    //start local stream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640', // Provide your preferred resolution
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
      },
    });
    //attach the local stream to the local renderer
    _localRenderer.srcObject = _localStream;
    setState(() {});
  }

  _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _closeRenderers() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  _onReceivingOwnICECandidate(RTCIceCandidate candidate) async {
    if (await _peerConnection!.getLocalDescription() != null) {
      String collectionName = (await _peerConnection!.getLocalDescription())!.type == "offer" ? "callerCandidates" : "calleeCandidates";
      print("Collection Name: $collectionName");
      try {
        print("Collection:${callId}");
        signalingServer.doc(callId).collection(collectionName).add({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      } catch (e) {
        print(e);
      }
    }
  }

  _createCallOffer() async {
    // create an offer / SDP
    var offer = await _peerConnection!.createOffer();
    // set the offer as the local description of the peer connection
    await _peerConnection!.setLocalDescription(offer);

    // connecting to the signaling server as the caller
    await _connectingToSignalingServerAsCaller(offer);
  }

  _connectingToSignalingServerAsCaller(RTCSessionDescription offer) {
    // send the offer to signaling server
    DocumentReference callReference = signalingServer.doc()
      ..set({
        "offer": {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });
    callId = callReference.id;
    setState(() {});
    // set listener for receiving the answer from the other peer
    callReference.snapshots().listen((DocumentSnapshot snapshot) {
      if (snapshot.exists) {
        var data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey("answer")) {
          _onReceivingCallAnswer(data);
        }
      }
    });

    // set listener for receiving the ICE candidates from the other peer
    callReference.collection("calleeCandidates").snapshots().listen((QuerySnapshot snapshot) {
      snapshot.docChanges.forEach((DocumentChange change) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    });
  }

  _joinCall(String callId) async {
    DocumentSnapshot snapshot = await signalingServer.doc(callId).get();
    if (snapshot.exists) {
      var data = snapshot.data() as Map<String, dynamic>;
      _connectingToSignalingServerAsCallee(data["offer"]);
    }
  }

  _connectingToSignalingServerAsCallee(Map<String, dynamic> data) async {
    // receive the offer from the signaling server
    var receivedOffer = RTCSessionDescription(data['sdp'], "offer");
    // set the offer as the remote description of the peer connection
    await _peerConnection!.setRemoteDescription(receivedOffer);
    // respond to the offer with an answer
    RTCSessionDescription answer = await _createAnswerForCall();
    // send the answer to the signaling server
    signalingServer.doc(callId).update({
      "answer": {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    });

    // set listener for receiving the ICE candidates from the other peer
    signalingServer.doc(callId).collection("callerCandidates").snapshots().listen((QuerySnapshot snapshot) {
      snapshot.docChanges.forEach((DocumentChange change) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      });
    });
  }

  Future<RTCSessionDescription> _createAnswerForCall() async {
    // create an answer / SDP
    var answer = await _peerConnection!.createAnswer();
    // set the answer as the local description of the peer connection
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  _onReceivingCallAnswer(Map<String, dynamic> data) async {
    print("Receiving Answer: $data");
    // receiving answer
    var receivedAnswer = RTCSessionDescription(data["answer"]['sdp'], "answer");
    // set the answer as the remote description of the peer connection
    await _peerConnection!.setRemoteDescription(receivedAnswer);
  }

  @override
  void initState() {
    callId = widget.callId ?? "";
    _createPeerConnection();
    _initRenderers();
    super.initState();
  }

  @override
  void dispose() {
    _closeRenderers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              RTCVideoView(
                _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              Column(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    color: Colors.black,
                    child: Text(
                      "Call ID: $callId",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _localStream!.getVideoTracks().forEach((track) {
                            track.enabled = !track.enabled;
                          });
                          setState(() {});
                        },
                        icon: Icon(Icons.videocam),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: IconButton(
                          onPressed: () {
                            _localStream!.getAudioTracks().forEach((track) {
                              track.enabled = !track.enabled;
                            });
                            setState(() {});
                          },
                          icon: Icon(Icons.mic),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _peerConnection!.close();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.call_end),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: SizedBox(
                  height: 150,
                  width: 90,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      _remoteRenderer,
                      mirror: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
