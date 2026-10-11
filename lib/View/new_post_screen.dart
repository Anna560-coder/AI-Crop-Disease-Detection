import 'dart:convert';

import 'package:ai_crop_disease_detection/Services/market_update_service.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/market_updates_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Form an Agriculture Expert fills in to post an update for farmers.
/// Returns true to the previous screen when a post was published.
class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final MarketUpdateService _marketUpdateService = MarketUpdateService();

  String selectedCategory = MarketUpdateService.categories.first;
  late String showFor = MarketUpdateService.defaultShowFor(selectedCategory);
  // Once the expert picks a duration, changing category no longer resets it.
  bool showForChosenByExpert = false;

  /// The optional photo, already shrunk and base64-encoded for Firestore.
  String? imageBase64;
  Uint8List? imagePreview;
  bool isPreparingImage = false;
  bool isSubmitting = false;

  /// Short hint for each category so experts know what to write.
  static const Map<String, String> _categoryHints = {
    "Market Price Update": "e.g. Mango prices at the Bethlehem market",
    "Seasonal Advice": "e.g. Prepare your trees for spring flowering",
    "Alert": "e.g. New leaf disease seen in Nketoana",
  };

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked;
    try {
      // The picker already shrinks the photo; encodePostImage makes sure it
      // fits in the post.
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      _showMessage(
        "Could not open the camera or gallery. Check app permissions.",
      );
      return;
    }
    if (picked == null) return;

    setState(() => isPreparingImage = true);
    final bytes = await picked.readAsBytes();
    // Resize and compress in the background so the screen doesn't freeze.
    final encoded = await compute(MarketUpdateService.encodePostImage, bytes);
    if (!mounted) return;
    setState(() {
      isPreparingImage = false;
      imageBase64 = encoded;
      imagePreview = encoded == null ? null : base64Decode(encoded);
    });
    if (encoded == null) {
      _showMessage("This photo could not be used. Please try another one.");
    }
  }

  void _removeImage() {
    setState(() {
      imageBase64 = null;
      imagePreview = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => isSubmitting = true);
    final error = await _marketUpdateService.createUpdate(
      category: selectedCategory,
      title: titleController.text,
      message: messageController.text,
      showFor: MarketUpdateService.showForOptions[showFor]!,
      imageBase64: imageBase64,
    );
    if (!mounted) return;
    setState(() => isSubmitting = false);

    if (error == null) {
      Navigator.pop(context, true);
    } else {
      _showMessage(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = isSubmitting || isPreparingImage;

    return Scaffold(
      appBar: AppBar(
        title: const Text("New post"),
        leading: IconButton(
          tooltip: "Cancel",
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              //Dropdown for the kind of post
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: "What kind of post is it?",
                ),
                items: MarketUpdateService.categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(
                          MarketUpdatesList.categoryIcon(category),
                          color: MarketUpdatesList.categoryColor(category),
                        ),
                        const SizedBox(width: 10),
                        Text(category),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: busy
                    ? null
                    : (String? newValue) {
                        if (newValue == null) return;
                        setState(() {
                          selectedCategory = newValue;
                          if (!showForChosenByExpert) {
                            showFor = MarketUpdateService.defaultShowFor(
                              newValue,
                            );
                          }
                        });
                      },
              ),
              const SizedBox(height: 16),
              //Input for title
              TextFormField(
                controller: titleController,
                enabled: !busy,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: "Title",
                  hintText: _categoryHints[selectedCategory],
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Please enter a title"
                    : null,
              ),
              const SizedBox(height: 8),
              //Input for message body
              TextFormField(
                controller: messageController,
                enabled: !busy,
                maxLength: 2000,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: "Message",
                  hintText: "Use simple words. Say what farmers should do.",
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? "Please enter a message"
                    : null,
              ),
              const SizedBox(height: 8),

              //How long farmers see the post before it disappears
              DropdownButtonFormField<String>(
                initialValue: showFor,
                key: ValueKey(showFor),
                decoration: const InputDecoration(
                  labelText: "Show to farmers for",
                  helperText:
                      "After this, the post disappears from farmers' screens.",
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: MarketUpdateService.showForOptions.keys
                    .map(
                      (option) =>
                          DropdownMenuItem(value: option, child: Text(option)),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        setState(() {
                          showFor = value;
                          showForChosenByExpert = true;
                        });
                      },
              ),
              const SizedBox(height: 20),

              //Optional photo, e.g. of a new disease in the area
              Text(
                "Photo (optional)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                "Add a photo so farmers can recognise the problem, e.g. a leaf with a new disease.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (isPreparingImage)
                const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (imagePreview != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        imagePreview!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        tooltip: "Remove photo",
                        onPressed: busy ? null : _removeImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text("Camera"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text("Gallery"),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              isSubmitting
                  ? const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : ElevatedButton.icon(
                      onPressed: busy ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: const Text("Post update"),
                    ),
              const SizedBox(height: 8),
              Text(
                "Every farmer using the app will see this post.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
