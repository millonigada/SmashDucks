// @dart=2.9
import 'dart:async';

import 'package:flutter/src/material/colors.dart' as colors;
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ArCoreController arCoreController;
  // ArCorePlane plane;
  // ArCoreNode node;
  // vector.Vector3 lastPosition;
  // String anchorId;

  ARSessionManager arSessionManager;
  ARObjectManager arObjectManager;
  ARAnchorManager arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Distance Tracker'),
          centerTitle: true,
        ),
        body: Container(
          child: Stack(
            children: [
              ARView(
                onARViewCreated: onARViewCreated,
                planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
              ),
              Align(
                alignment: FractionalOffset.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                        onPressed: onRemoveEverything,
                        child: Text("Remove Everything")
                    ),
                    ElevatedButton(
                        onPressed: onTakeScreenshot,
                        child: const Text("Take Screenshot")
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        // body: ArCoreView(
        //   onArCoreViewCreated: _onArCoreViewCreated,
        // ),
      ),
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "assets/images/triangle.png",
      showWorldOrigin: true,
    );
    this.arObjectManager.onInitialize();

    this.arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
    this.arObjectManager.onNodeTap = onNodeTapped;
  }

  Future<void> onRemoveEverything() async {
    /*nodes.forEach((node) {
      this.arObjectManager.removeNode(node);
    });*/
    anchors.forEach((anchor) {
      this.arAnchorManager.removeAnchor(anchor);
    });
    anchors = [];
  }

  Future<void> onTakeScreenshot() async {
    ImageProvider<Object> image = await arSessionManager.snapshot();
    await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            decoration: BoxDecoration(
                image: DecorationImage(image: image, fit: BoxFit.cover)),
          ),
        ));
  }

  Future<void> onNodeTapped(List<String> nodes) async {
    debugPrint("TAPPED NODES: ${nodes}");
    var number = nodes.length;
    for(int i=0; i<this.nodes.length; i++){
      debugPrint("NODE NAME: ${this.nodes[i].name}");
      debugPrint("NODE NAME 2: ${nodes[0][0]}");
      if(nodes[0].contains(this.nodes[i].name)){
        debugPrint("displaying something");
        vector.Vector3 oldScale = this.nodes[i].scale;
        vector.Vector3 newScale = vector.Vector3(
          oldScale.x - 0.1,
          oldScale.y - 0.1,
          oldScale.z - 0.1
        );
        if(newScale.x!=0){
          this.nodes[i].scale = newScale;
        } else {
          this.nodes.remove(this.nodes[i]);
          //onPlaneOrPointTapped();
        }
        //displayText(this.nodes[i]);
        break;
      } else {
        debugPrint("displaying nothing");
      }
    }
    this.arSessionManager.onError("Tapped $number node(s)");
  }

  Future<void> onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstWhere(
            (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);
    if (singleHitTestResult != null) {
      double distanceFromScreen = singleHitTestResult.distance;

      debugPrint("single hit test distance: ${singleHitTestResult.distance}");
      debugPrint("world transform co-ordinates: ${singleHitTestResult.worldTransform}");

      vector.Matrix4 coordinates = generateRandomMatrix();

      var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
      //var newAnchor = ARPlaneAnchor(transformation: coordinates);
      bool didAddAnchor = await this.arAnchorManager.addAnchor(newAnchor);

      if (didAddAnchor) {
        this.anchors.add(newAnchor);
        // Add note to anchor
        var newNode = ARNode(
            type: NodeType.webGLB,
            uri:
            "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Duck/glTF-Binary/Duck.glb",
            scale: Vector3(0.5, 0.5, 0.5),
            position: Vector3(0.0, 0.0, 0.0),
            rotation: Vector4(1.0, 0.0, 0.0, 0.0),
          data: {
              "distance": distanceFromScreen
          }
        );
        bool didAddNodeToAnchor =
        await this.arObjectManager.addNode(newNode, planeAnchor: newAnchor);
        this.nodes.add(newNode);
        if (didAddNodeToAnchor) {
          this.nodes.add(newNode);

        } else {
          this.arSessionManager.onError("Adding Node to Anchor failed");
        }
      } else {
        this.arSessionManager.onError("Adding Anchor failed");
      }
      /*
      // To add a node to the tapped position without creating an anchor, use the following code (Please mind: the function onRemoveEverything has to be adapted accordingly!):
      var newNode = ARNode(
          type: NodeType.localGLTF2,
          uri: "Models/Chicken_01/Chicken_01.gltf",
          scale: Vector3(0.2, 0.2, 0.2),
          transformation: singleHitTestResult.worldTransform);
      bool didAddWebNode = await this.arObjectManager.addNode(newNode);
      if (didAddWebNode) {
        this.nodes.add(newNode);
      }*/
    }
  }

  vector.Matrix4 generateRandomMatrix(){
    List randomNos = [];
    var random = Random();
    for(int i=0;i<12;i++){
      double num = random.nextDouble();
      bool pn = random.nextBool();
      bool e = random.nextBool();
      int intnum = random.nextInt(5);
      if(!pn){
        num -= intnum;
      } else {
        num += intnum;
      }
      if(e&&(i==4)){
        num = num*(0.0000000000000000001);
      }
      randomNos.add(num);
    }
    debugPrint("RANDOM MATRIX: $randomNos");
    return vector.Matrix4(
      randomNos[0],randomNos[1],randomNos[2],randomNos[3],
      randomNos[4],randomNos[5],randomNos[6],randomNos[7],
      randomNos[8],randomNos[9],randomNos[10],randomNos[11],
      0.0,0.0,0.0,1.0
    );
  }

  String calculateDistanceBetweenPoints(vector.Vector3 A, vector.Vector3 B){
    final length = A.distanceTo(B);
    return "${(length*100).toStringAsFixed(2)}cm";
  }

  vector.Vector3 getMidPoint(vector.Vector3 A, vector.Vector3 B){
    return vector.Vector3(
      (A.x + B.x)/2,
      (A.y + B.y)/2,
      (A.z + B.z)/2,
    );
  }

  displayText(ARNode A) async {
    await showDialog(
        context: context,
        builder: (_) => Dialog(
          child: Container(
            child: Center(
              child: Text(
                "${A.data["distance"]}"
              ),
            ),
        )
      )
    );
  }

  // void _onArCoreViewCreated(ArCoreController controller) {
  //   arCoreController = controller;
  //
  //   _addSphere(arCoreController);
  //   _addCylindre(arCoreController);
  //   _addCube(arCoreController);
  // }

  // void _addSphere(ArCoreController controller) {
  //   final material = ArCoreMaterial(
  //       color: Color.fromARGB(120, 66, 134, 244));
  //   final sphere = ArCoreSphere(
  //     materials: [material],
  //     radius: 0.1,
  //   );
  //   final node = ArCoreNode(
  //     shape: sphere,
  //     position: vector.Vector3(0, 0, -1.5),
  //   );
  //   controller.addArCoreNode(node);
  // }
  //
  // void _addCylindre(ArCoreController controller) {
  //   final material = ArCoreMaterial(
  //     color: Color.fromARGB(120, 16, 213, 224),
  //     reflectance: 1.0,
  //   );
  //   final cylindre = ArCoreCylinder(
  //     materials: [material],
  //     radius: 0.5,
  //     height: 0.3,
  //   );
  //   final node = ArCoreNode(
  //     shape: cylindre,
  //     position: vector.Vector3(0.0, -0.5, -2.0),
  //   );
  //   controller.addArCoreNode(node);
  // }
  //
  // void _addCube(ArCoreController controller) {
  //   final material = ArCoreMaterial(
  //     color: Color.fromARGB(120, 66, 134, 244),
  //     metallic: 1.0,
  //   );
  //   final cube = ArCoreCube(
  //     materials: [material],
  //     size: vector.Vector3(0.5, 0.5, 0.5),
  //   );
  //   final node = ArCoreNode(
  //     shape: cube,
  //     position: vector.Vector3(-0.5, 0.5, -3.5),
  //   );
  //   controller.addArCoreNode(node);
  // }

  @override
  void dispose() {
    //arCoreController.dispose();
    arSessionManager.dispose();
    super.dispose();
  }
}