import 'package:ai_crop_disease_detection/Services/groq_service.dart';
import 'package:flutter/material.dart';

class GroqScreen extends StatefulWidget {
  final String diseaseName;

  const GroqScreen({super.key, required this.diseaseName});

  @override
  State<GroqScreen> createState() => _GroqScreenState();
}

class _GroqScreenState extends State<GroqScreen> {
  final GroqService groqService = GroqService();

  String result = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRecommendation();
  }

  Future<void> loadRecommendation() async {
    String response = await groqService.getDiseaseRecommendation(
      widget.diseaseName,
    );

    setState(() {
      result = response;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI Recommendation")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Text(result, style: TextStyle(fontSize: 18)),
              ),
      ),
    );
  }
}
