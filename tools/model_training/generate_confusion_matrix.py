"""Generate the confusion matrix (Figure 1) for the Crop Disease Detection paper.

Runs the TFLite model over the held-out test images, compares each prediction
to the true label (the folder it is in), and saves confusion_matrix.png and
classification_report.txt.

In Google Colab, upload this script, crop_disease_model.tflite, labels.txt and
test_data.zip, then run:
  !unzip -q -o test_data.zip -d test_data
  !python generate_confusion_matrix.py --model crop_disease_model.tflite --labels labels.txt --test_dir test_data
"""

import argparse
import os
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="Path to the .tflite model file")
    parser.add_argument("--labels", required=True, help="Path to labels.txt")
    parser.add_argument("--test_dir", required=True,
                        help="Path to the test set folder (one subfolder per class)")
    parser.add_argument("--out_prefix", default="confusion_matrix",
                        help="Output filename prefix")
    args = parser.parse_args()

    try:
        import numpy as np
        import tensorflow as tf
        from PIL import Image
        from sklearn.metrics import confusion_matrix, classification_report
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError as e:
        print(f"Missing package: {e}. Install with:")
        print("  pip install tensorflow scikit-learn matplotlib pillow")
        sys.exit(1)

    # Load labels in model order.
    with open(args.labels, "r") as f:
        labels = [line.strip() for line in f if line.strip()]
    print(f"Loaded {len(labels)} labels in model order: {labels}")

    # Load the TFLite model.
    interpreter = tf.lite.Interpreter(model_path=args.model)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    _, in_h, in_w, _ = input_details[0]["shape"]

    def predict(image_path):
        # Nearest-neighbour resize and / 255 match the app and the training.
        img = Image.open(image_path).convert("RGB").resize((in_w, in_h), Image.NEAREST)
        arr = np.asarray(img).astype(np.float32) / 255.0
        arr = np.expand_dims(arr, axis=0)
        interpreter.set_tensor(input_details[0]["index"], arr)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]["index"])[0]
        return int(np.argmax(output))

    y_true, y_pred, bad_files = [], [], []

    for class_idx, class_name in enumerate(labels):
        class_dir = os.path.join(args.test_dir, class_name)
        if not os.path.isdir(class_dir):
            print(f"WARNING: no folder found for class '{class_name}' at {class_dir} -- skipping.")
            continue
        files = [f for f in os.listdir(class_dir)
                 if f.lower().endswith((".jpg", ".jpeg", ".png"))]
        print(f"  {class_name}: {len(files)} images")
        for fname in files:
            fpath = os.path.join(class_dir, fname)
            try:
                pred_idx = predict(fpath)
            except Exception as e:
                bad_files.append((fpath, str(e)))
                continue
            y_true.append(class_idx)
            y_pred.append(pred_idx)

    if bad_files:
        print(f"\n{len(bad_files)} images failed to load/predict and were skipped:")
        for fpath, err in bad_files[:10]:
            print(f"  {fpath}: {err}")

    correct = sum(a == b for a, b in zip(y_true, y_pred))
    print(f"\nTotal evaluated: {len(y_true)} images, correct: {correct}")

    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(labels))))

    # Precision/recall/F1 per class, to check against Table 2.
    report = classification_report(y_true, y_pred, labels=list(range(len(labels))),
                                   target_names=labels, digits=3)
    with open(f"{args.out_prefix.replace('confusion_matrix', 'classification_report')}.txt", "w") as f:
        f.write(report)
    print("\n" + report)

    # Plot the confusion matrix.
    fig, ax = plt.subplots(figsize=(9, 8))
    im = ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(len(labels)))
    ax.set_yticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right")
    ax.set_yticklabels(labels)
    ax.set_xlabel("Predicted label")
    ax.set_ylabel("True label")
    ax.set_title("Confusion matrix: retrained model on held-out test set")

    thresh = cm.max() / 2.0
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            if cm[i, j] > 0:
                ax.text(j, i, str(cm[i, j]), ha="center", va="center",
                        color="white" if cm[i, j] > thresh else "black", fontsize=8)

    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    fig.tight_layout()
    out_path = f"{args.out_prefix}.png"
    fig.savefig(out_path, dpi=200)
    print(f"\nSaved confusion matrix to {out_path}")


if __name__ == "__main__":
    main()
