import 'dart:io';
import 'package:ai_crop_disease_detection/Services/diagnosis_service.dart';
import 'package:ai_crop_disease_detection/View/detection_history_screen.dart';
import 'package:ai_crop_disease_detection/View/groq_screen.dart';
import 'package:ai_crop_disease_detection/Services/label_utils.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/market_updates_button.dart';
import 'package:ai_crop_disease_detection/View/onboarding_screen.dart';
import 'package:ai_crop_disease_detection/View/widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FarmerScreen extends StatefulWidget {
  const FarmerScreen({super.key});

  @override
  State<FarmerScreen> createState() => _FarmerScreenState();
}

class _FarmerScreenState extends State<FarmerScreen> {
  Future<void> saveDetectionHistory() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || predictionLabel.isEmpty || filePath == null) {
      debugPrint("saveDetectionHistory skipped: missing user, label, or file.");
      return;
    }

    try {
      final savedImagePath = await _persistImage(filePath!);
      await FirebaseFirestore.instance.collection('detection_history').add({
        'userId': user.uid,
        'imagePath': savedImagePath,
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
      if (mounted) setState(() => savedToHistory = true);
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

  // Future that completes once the model and labels are ready, so a photo
  // picked before loading finishes waits instead of crashing.
  late final Future<void> _modelReady;
  bool isProcessing = false;
  bool savedToHistory = false;
  // True when the model says the photo is not a crop leaf.
  bool notALeaf = false;
  String farmerName = "";

  @override
  void initState() {
    super.initState();

    _modelReady = _tfliteInit();
    _loadFarmerName();
  }

  /// Reads the farmer's name for the greeting at the top of the screen.
  Future<void> _loadFarmerName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .get();
      final name = (doc.data()?['name'] as String?)?.trim() ?? "";
      if (mounted && name.isNotEmpty) {
        // Use the first name only, e.g. "Anna Mosala" -> "Anna".
        setState(() => farmerName = name.split(' ').first);
      }
    } catch (_) {
      // Greeting just shows without a name.
    }
  }

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }

  Future<void> _tfliteInit() async {
    interpreter = await Interpreter.fromAsset(
      'assets/crop_disease_model.tflite',
    );

    String labelData = await rootBundle.loadString('assets/labels.txt');

    labels = parseLabels(labelData);

    final outputClasses = interpreter!.getOutputTensor(0).shape.last;
    if (outputClasses != labels.length) {
      throw StateError(
        "Model outputs $outputClasses classes but labels.txt has ${labels.length} labels.",
      );
    }

    debugPrint("Model Loaded");
  }

  /// Copies the picked image into the app's documents directory. The
  /// image_picker file lives in a cache folder that Android/iOS can clear at
  /// any time, which would make images disappear from detection history.
  Future<String> _persistImage(File image) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final historyDir = Directory('${dir.path}/detection_images');
      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }
      final extension = image.path.contains('.')
          ? image.path.substring(image.path.lastIndexOf('.'))
          : '.jpg';
      final saved = await image.copy(
        '${historyDir.path}/${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      return saved.path;
    } catch (e) {
      debugPrint("Could not persist image, using original path: $e");
      return image.path;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _processImage(File image) async {
    if (isProcessing) return;
    setState(() {
      isProcessing = true;
    });

    try {
      await _modelReady;
      await classifyImage(image);
    } catch (e) {
      debugPrint("Image classification failed: $e");
      _showMessage("Could not analyse this image. Please try another photo.");
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> classifyImage(File image) async {
    img.Image? imageInput = img.decodeImage(await image.readAsBytes());

    if (imageInput == null) {
      _showMessage("This file is not a supported image.");
      return;
    }

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

    // Not a leaf: show a "retake" message instead of a disease, and don't
    // look it up or save it to the farmer's history.
    if (isNotLeafLabel(label)) {
      if (!mounted) return;
      setState(() {
        notALeaf = true;
        predictionLabel = "";
        confidence = conf;
      });
      return;
    }

    final diseaseInfo = await _diagnosisService.getDiseaseInfo(label);

    if (!mounted) return;
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

  Future<void> pickImage(ImageSource source) async {
    if (isProcessing) return;

    final XFile? image;
    try {
      image = await ImagePicker().pickImage(source: source);
    } catch (e) {
      debugPrint("Image picker failed: $e");
      _showMessage(
        "Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}. Please check app permissions.",
      );
      return;
    }

    if (image == null || !mounted) return;

    var imageMap = File(image.path);

    setState(() {
      filePath = imageMap;
      // Clear the previous result so it isn't shown for the new photo.
      predictionLabel = "";
      confidence = 0.0;
      symptoms = "";
      severityLevel = "";
      cropType = "";
      treatmentAdvice = "";
      savedToHistory = false;
      notALeaf = false;
    });

    await _processImage(imageMap);
  }

  void _openGuide() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(openedFromApp: true),
      ),
    );
  }

  void _openAiAdvice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroqScreen(diseaseName: predictionLabel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco),
            SizedBox(width: 8),
            Text(AppStrings.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "How to use this app",
            icon: const Icon(Icons.help_outline),
            onPressed: _openGuide,
          ),
          IconButton(
            tooltip: "Sign out",
            icon: const Icon(Icons.logout),
            onPressed: () => confirmSignOut(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildGreeting(),
          const SizedBox(height: 16),
          // Before a photo is chosen show the step-by-step guide; afterwards
          // show the result for that photo.
          filePath == null ? _buildScanCard() : _buildResultCard(),
          const SizedBox(height: 24),
          const SectionTitle("More for your farm", icon: Icons.agriculture),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: HomeActionTile(
                    icon: Icons.history,
                    title: "My past scans",
                    subtitle: "See every leaf you have checked",
                    color: AppColors.soil,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DetectionHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Shows a red badge with the number of unread posts.
                const Expanded(child: MarketUpdatesButton()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          HomeActionTile(
            icon: Icons.forum_outlined,
            title: "Ask the AI",
            subtitle: "Ask any farming question and get an answer in seconds",
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GroqScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // "Dumela" is a Sesotho greeting, the main language in Nketoana.
                  farmerName.isEmpty ? "Dumela!" : "Dumela, $farmerName!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Let's check the health of your crops today.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa, color: AppColors.accent, size: 34),
          ),
        ],
      ),
    );
  }

  /// Shown before a photo is taken: explains the 3 steps in plain words.
  Widget _buildScanCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Check a leaf for disease",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              "It only takes a few seconds.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            const _StepRow(
              number: 1,
              icon: Icons.photo_camera,
              text: "Take a clear photo of one leaf",
            ),
            const _StepRow(
              number: 2,
              icon: Icons.search,
              text: "The app checks it for disease",
            ),
            const _StepRow(
              number: 3,
              icon: Icons.healing,
              text: "Follow the treatment advice",
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => pickImage(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text("Take a photo"),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () => pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text("Choose from gallery"),
            ),
            const SizedBox(height: 16),
            const _TipBox(
              icon: Icons.lightbulb_outline,
              text:
                  "Tip: for the best result, pick one leaf, lay it on white paper and take the photo in daylight.",
            ),
          ],
        ),
      ),
    );
  }

  /// Shown after a photo is chosen: the photo, then the diagnosis.
  Widget _buildResultCard() {
    final healthy = isHealthyLabel(predictionLabel);
    final hasResult = predictionLabel.isNotEmpty;
    final severityKnown =
        severityLevel.isNotEmpty && severityLevel.toLowerCase() != "unknown";
    final statusColor = healthy
        ? AppColors.healthy
        : (severityKnown ? severityColor(severityLevel) : AppColors.danger);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The farmer's photo, with a "checking" overlay while analysing.
          SizedBox(
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  filePath!,
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 14),
                        Text(
                          "Checking your leaf...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isProcessing)
                  Text(
                    "Please wait, this takes a few seconds.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else if (notALeaf)
                  const _NotALeafMessage()
                else if (!hasResult)
                  const _TipBox(
                    icon: Icons.error_outline,
                    color: AppColors.danger,
                    text:
                        "We could not check this photo. Please try again with a clear photo of one leaf.",
                  )
                else ...[
                  // Big, clear status banner.
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          healthy ? Icons.check_circle : Icons.warning_rounded,
                          color: statusColor,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            healthy
                                ? "Good news! Your crop looks healthy."
                                : "Disease found on this leaf",
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    predictionLabel,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (cropType.isNotEmpty &&
                          cropType.toLowerCase() != "unknown")
                        StatusChip(
                          label: cropType,
                          color: AppColors.soil,
                          icon: Icons.grass,
                        ),
                      if (!healthy && severityKnown)
                        StatusChip(
                          label: "$severityLevel severity",
                          color: severityColor(severityLevel),
                          icon: Icons.speed,
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Confidence shown as words + a bar, not just a number.
                  Row(
                    children: [
                      Text(
                        "How sure is the app?",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        "${confidence.toStringAsFixed(0)}% · ${confidenceLabel(confidence)}",
                        style: TextStyle(
                          color: confidenceColor(confidence),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (confidence / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      color: confidenceColor(confidence),
                      backgroundColor: const Color(0xFFE6EBE3),
                    ),
                  ),
                  if (confidence < 60) ...[
                    const SizedBox(height: 12),
                    const _TipBox(
                      icon: Icons.info_outline,
                      color: AppColors.warning,
                      text:
                          "The app is not sure about this result. Take another photo in good light, close to one leaf.",
                    ),
                  ],
                  const SizedBox(height: 18),

                  if (symptoms.isNotEmpty && symptoms != "Not documented.")
                    _InfoBlock(
                      icon: Icons.visibility_outlined,
                      title: "Signs to look for",
                      text: symptoms,
                    ),
                  if (treatmentAdvice.isNotEmpty)
                    _InfoBlock(
                      icon: Icons.healing,
                      title: healthy ? "Keep it healthy" : "What to do",
                      text: treatmentAdvice,
                    ),

                  if (!healthy) ...[
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: _openAiAdvice,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Get more advice from AI"),
                    ),
                  ],
                  if (savedToHistory) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Saved to your past scans",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],

                // Check another leaf.
                if (!isProcessing) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    "Check another leaf",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera),
                          label: const Text("Camera"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text("Gallery"),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the model says the photo is not a crop leaf.
class _NotALeafMessage extends StatelessWidget {
  const _NotALeafMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.eco_outlined, color: AppColors.warning, size: 32),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "This doesn't look like a crop leaf",
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "The app can only check leaves. Please take a new photo:",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 10),
        const _StepRow(
          number: 1,
          icon: Icons.back_hand_outlined,
          text: "Pick one leaf from the plant",
        ),
        const _StepRow(
          number: 2,
          icon: Icons.description_outlined,
          text: "Lay it on white paper or a plain surface",
        ),
        const _StepRow(
          number: 3,
          icon: Icons.wb_sunny_outlined,
          text: "Take the photo in daylight, close to the leaf",
        ),
      ],
    );
  }
}

/// One numbered step in the "how to check a leaf" guide.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.icon,
    required this.text,
  });

  final int number;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              "$number",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// Coloured box with an icon, used for tips and warnings.
class _TipBox extends StatelessWidget {
  const _TipBox({
    required this.icon,
    required this.text,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color == AppColors.accent ? AppColors.soil : color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Titled block of diagnosis information (symptoms, treatment).
class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
