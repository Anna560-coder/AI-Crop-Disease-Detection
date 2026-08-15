import 'dart:io';
import 'package:ai_crop_disease_detection/Services/diagnosis_service.dart';
import 'package:ai_crop_disease_detection/View/detection_history_screen.dart';
import 'package:ai_crop_disease_detection/View/groq_screen.dart';
import 'package:ai_crop_disease_detection/Services/auth_services.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

AuthServices _authServices = AuthServices();

class FarmerScreen extends StatefulWidget {
  const FarmerScreen({super.key});

  @override
  State<FarmerScreen> createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen> {
  List<Map<String, dynamic>> detectionHistory = [];

  Future<void> saveDetectionHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || predictionLabel.isEmpty || filePath == null) {
      debugPrint("saveDetectionHistory skipped: missing user, label, or file.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('detection_history').add({
        'userId': user.uid,
        'imagePath': filePath!.path,
        'label': predictionLabel,
        'confidence': confidence,
        'treatment': treatmentAdvice,
        'symptoms': symptoms,
        'severityLevel': severityLevel,
        'cropType': cropType,
        'status': 'diagnosed',
        'remarks': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("Detection history saved successfully for $predictionLabel.");
    } catch (e) {
      debugPrint("FAILED to save detection history: $e");
    }
  }

  File? filePath;

  Interpreter? interpreter;

  List<String> labels = [];

  String predictionLabel = "";
  double confidence = 0.0;
  String treatmentAdvice = "";

  final DiagnosisService _diagnosisService = DiagnosisService();
  String symptoms = "";
  String severityLevel = "";
  String cropType = "";

  String getTreatment(String diseaseName) {
    if (diseaseName == "Sooty Mould") {
      return "Treatment: Wash affected leaves gently, control insects such as aphids and whiteflies, and improve air circulation.";
    } else if (diseaseName == "Gall Midge") {
      return "Treatment: Remove infected leaves and use approved insect control methods. Monitor the crop regularly.";
    } else if (diseaseName == "Healthy") {
      return "No treatment needed. Continue regular watering and monitoring.";
    } else {
      return "Treatment: Consult an agricultural expert for proper treatment advice.";
    }
  }

  @override
  void initState() {
    super.initState();

    _tfliteInit();
  }

  Future<void> _tfliteInit() async {
    interpreter = await Interpreter.fromAsset(
      'assets/mobilenet_v1_1.0_224.tflite',
    );

    String labelData = await rootBundle.loadString('assets/labels.txt');

    labels = labelData
        .split('\n')
        .where((label) => label.trim().isNotEmpty)
        .toList();

    debugPrint("Model Loaded");
  }

  Future<void> classifyImage(File image) async {
    img.Image? imageInput = img.decodeImage(image.readAsBytesSync());

    if (imageInput == null) return;

    img.Image resizedImage = img.copyResize(
      imageInput,
      width: 224,
      height: 224,
    );

    var input = List.generate(
      1,
      (index) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resizedImage.getPixel(x, y);

          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );

    var output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

    interpreter!.run(input, output);

    double maxConfidence = 0;
    int maxIndex = 0;

    for (int i = 0; i < labels.length; i++) {
      if (output[0][i] > maxConfidence) {
        maxConfidence = output[0][i];
        maxIndex = i;
      }
    }

    final label = labels[maxIndex];
    final conf = maxConfidence * 100;

    final diseaseInfo = await _diagnosisService.getDiseaseInfo(label);

    setState(() {
      predictionLabel = label;
      confidence = conf;
      symptoms = diseaseInfo["symptoms"];
      severityLevel = diseaseInfo["severity_level"];
      cropType = diseaseInfo["crop_type"];
      treatmentAdvice = diseaseInfo["treatment_advice"];
    });

    await saveDetectionHistory();
  }

  pickImageGallery() async {
    final picker = ImagePicker();
    // Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    var imageMap = File(image.path);

    setState(() {
      filePath = imageMap;
    });

    await classifyImage(imageMap);
  }

  pickImageCamera() async {
    final picker = ImagePicker();
    // Pick an image.
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    var imageMap = File(image.path);

    setState(() {
      filePath = imageMap;
    });

    await classifyImage(imageMap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('Farmer Screen'),

        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 12),
                Card(
                  elevation: 20,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 300,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 18),
                          Container(
                            height: 280,
                            width: 280,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: AssetImage('assets/upload_image.png'),
                              ),
                            ),
                            child: filePath == null
                                ? Text('')
                                : Image.file(filePath!, fit: BoxFit.fill),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsetsGeometry.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  "Label: ${predictionLabel.toString()}",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Confidence: ${confidence.toStringAsFixed(2)}%",
                                  style: TextStyle(fontSize: 18),
                                ),
                                SizedBox(height: 12),

                                if (severityLevel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      "Severity: $severityLevel",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: severityLevel == "High"
                                            ? Colors.red
                                            : severityLevel == "Moderate"
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                    ),
                                  ),
                                if (symptoms.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      "Symptoms: $symptoms",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),

                                if (treatmentAdvice.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      treatmentAdvice,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),

                                if (predictionLabel.isNotEmpty &&
                                    predictionLabel != "Healthy")
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GroqScreen(
                                            diseaseName: predictionLabel,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Ask AI for more recommendations",
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    pickImageCamera();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(13),
                    ),
                    foregroundColor: Colors.black,
                  ),
                  child: Text("Take a photo"),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    pickImageGallery();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusGeometry.circular(13),
                    ),
                    foregroundColor: Colors.black,
                  ),
                  child: Text("Pick from gallery"),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DetectionHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text("View Detection History"),
                ),

                ElevatedButton(
                  onPressed: () {
                    _authServices.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                  child: Text('SignOut'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
