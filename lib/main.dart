import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as m;

List<CameraDescription> cameras;
Future<Null> main() async {
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('$e.message');
  }
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(cameras),
    );
  }
}

const String yolo = "Tiny YOLOv2";

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  HomePage(this.cameras);
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _recs;
  int _imgH = 0;
  int _imgW = 0;
  String _model = "";

  @override
  void initState() {
    super.initState();
    goModel(yolo);
  }

  loadModel() async {
    String res;
    if (_model == yolo) {
      res = await Tflite.loadModel(
        model: "assets/yolo.tflite",
        labels: "assets/yolo.txt",
      );
    }
    print(res);
  }

  goModel(model) {
    setState(() {
      _model = model;
    });
    loadModel();
  }


  setRecs(recs, imgH, imgW) {
    setState(() {
      _recs = recs;
      _imgH = imgH;
      _imgW = imgW;
    });
  }


  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          Camera(
            widget.cameras,
            _model,
            setRecs,
          ),
          Emoje(
            _recs == null ? []: _recs,
            m.max(_imgH, _imgW),
            m.min(_imgH, _imgW),
            screen.height,
            screen.width,
          ),
        ],
      ),
    );
  }
}

typedef void Callback(List<dynamic> list, int h, int w);

class Camera extends StatefulWidget {
  final List<CameraDescription> cams;
  final Callback setRecs;
  final String model;
  Camera(this.cams, this.model, this.setRecs);
  @override
  _CameraState createState() => new _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController cam;
  bool isDet = false;
  @override
  void initState() {
    super.initState();
    if (widget.cams == null || widget.cams.length < 1) {
      print('nocam');
    } else {
      cam = new CameraController(
        widget.cams[0],
        ResolutionPreset.medium,
      );
      cam.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
        cam.startImageStream((CameraImage img) {
          if (!isDet) {
            isDet = true;
            Tflite.detectObjectOnFrame(
              bytesList: img.planes.map((plane) {
                return plane.bytes;
              }).toList(),
              model: "YOLO",
              imageHeight: img.height,
              imageWidth: img.width,
              imageMean: 0,
              imageStd: 255,
              numResultsPerClass: 1,
              threshold: 0.05,
            ).then((recognitions) {
              widget.setRecs(recognitions, img.height, img.width);
              isDet = false;
            });
          }
        });
      });
    }
  }

  @override
  void dispose() {
    cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cam == null || !cam.value.isInitialized) {
      return Container();
    }
    var tmp = MediaQuery.of(context).size;
    var sH = m.max(tmp.height, tmp.width);
    var sW = m.min(tmp.height, tmp.width);
    tmp = cam.value.previewSize;
    var pH = m.max(tmp.height, tmp.width);
    var pW = m.min(tmp.height, tmp.width);
    var sR = sH / sW;
    var pR = pH / pW;
    return OverflowBox(
      maxHeight: sR > pR ? sH : sW / pW * pH,
      maxWidth: sR > pR ? sH / pH * pW : sW,
      child: CameraPreview(cam),
    );
  }
}

class Emoje extends StatelessWidget {
  final List<dynamic> recs;
  final int pH;
  final int pW;
  final double sH;
  final double sW;

  Emoje(
    this.recs,
    this.pH,
    this.pW,
    this.sH,
    this.sW,
  );
  @override
  Widget build(BuildContext context) {

    List<Widget> _renderB() {
      return recs.map((re) {
        var _x = re["rect"]["x"];
        var _y = re["rect"]["y"];
        var _h = re["rect"]["h"];
        var scW, scH, x, y, h;
        scW = sH / pH * pW;
        scH = sH;
        var difW = (scW - sW) / scW;
        x = (_x - difW / 2) * scW;
        y = _y * scH;
        h = _h * scH;
        return Positioned(
            left: m.max(0, x),
            top: m.max(0, y),
            width: h+16,
            height: h+16,
            child:  RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: (h/3.236)*(re["confidenceInClass"]*1.618),
                  ),
                  text: "${re["detectedClass"]}",
                ),
              ),
        );
      }).toList();
    }

    return Stack(
      children: _renderB(),
    );
  }
}

