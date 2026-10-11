"""Retrain the crop disease model with a 9th class, "Not a leaf".

Why: the original 8-class model was trained only on leaves, so it always
picks a disease - even for a photo of a brick wall (99.7% "Bacterial Canker").
Adding a "Not a leaf" class trained on everyday objects and scenes lets the
app tell farmers when a photo is not a leaf.

Method (transfer learning):
  * MobileNetV2 pre-trained on ImageNet, frozen, as a feature extractor.
  * A new softmax layer with 9 outputs trained on top.
  * Input is a 224x224 RGB image scaled to 0-1, exactly what the app sends
    (farmer_screen.dart: nearest-neighbour resize, pixel / 255). The model
    rescales to MobileNetV2's -1..1 range internally.
  * Data split 70% train / 15% validation / 15% test, stratified, seed 42.

Usage (from the project root):
  python tools/model_training/train_model.py \
      --dataset "<path to MangoLeafBD Dataset>" \
      --nonleaf tools/model_training/data/101_ObjectCategories

Outputs (tools/model_training/output/):
  crop_disease_model.tflite, labels.txt, split.json (which file is in which split)
"""
import argparse, json, os, random
import numpy as np
from PIL import Image
from sklearn.model_selection import train_test_split
import tensorflow as tf

# Same order as the app's assets/labels.txt, plus the new class at the end.
DISEASE_CLASSES = [
    "Bacterial Canker", "Cutting Weevil", "Die Back", "Gall Midge",
    "Healthy", "Powdery Mildew", "Sooty Mould", "Anthracnose",
]
NOT_LEAF = "Not a leaf"
CLASSES = DISEASE_CLASSES + [NOT_LEAF]

# Caltech-101 categories that are plants: excluded so the model never learns
# that "plant" means "not a leaf".
PLANT_CATEGORIES = {"bonsai", "joshua_tree", "lotus", "sunflower", "water_lilly", "strawberry"}
PER_OBJECT_CATEGORY = 20   # images taken from each Caltech-101 category
BACKGROUND_IMAGES = 300    # from Caltech's BACKGROUND_Google (random scenes)
SYNTHETIC_TEXTURES = 300   # walls, soil, noise, plain colours
SEED = 42
IMG = 224


def load_image(path_or_array):
    """Exactly the app's preprocessing: RGB, nearest-neighbour 224x224, / 255."""
    im = path_or_array if isinstance(path_or_array, Image.Image) else Image.open(path_or_array)
    arr = np.asarray(im.convert("RGB").resize((IMG, IMG), Image.NEAREST), dtype=np.float32)
    return arr / 255.0


def synthetic_texture(rng):
    """Hard negatives that fooled the old model: walls, soil, noise, plain colour."""
    kind = rng.integers(0, 5)
    base = rng.integers(0, 256, 3).astype(np.float32)
    if kind == 0:   # plain colour with slight noise (wall, paper, sky)
        arr = base + rng.normal(0, 6, (IMG, IMG, 3))
    elif kind == 1:  # rough texture (soil, brick, concrete)
        arr = base + rng.normal(0, rng.uniform(10, 40), (IMG, IMG, 3))
    elif kind == 2:  # colour gradient
        t = np.linspace(0, 1, IMG)[None, :, None]
        arr = base * (1 - t) + rng.integers(0, 256, 3) * t + np.zeros((IMG, 1, 1))
    elif kind == 3:  # random noise
        arr = rng.integers(0, 256, (IMG, IMG, 3)).astype(np.float32)
    else:            # dark photo (camera in a pocket)
        arr = rng.normal(rng.uniform(5, 40), 5, (IMG, IMG, 3))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def collect(dataset_dir, nonleaf_dir):
    rng = random.Random(SEED)
    items = []  # (source, label_index); source = file path or "synthetic:<n>"
    for i, cls in enumerate(DISEASE_CLASSES):
        folder = os.path.join(dataset_dir, cls)
        for f in sorted(os.listdir(folder)):
            items.append((os.path.join(folder, f), i))
    not_leaf = CLASSES.index(NOT_LEAF)
    for cat in sorted(os.listdir(nonleaf_dir)):
        if cat in PLANT_CATEGORIES:
            continue
        files = sorted(os.listdir(os.path.join(nonleaf_dir, cat)))
        take = BACKGROUND_IMAGES if cat == "BACKGROUND_Google" else PER_OBJECT_CATEGORY
        for f in rng.sample(files, min(take, len(files))):
            items.append((os.path.join(nonleaf_dir, cat, f), not_leaf))
    for n in range(SYNTHETIC_TEXTURES):
        items.append((f"synthetic:{n}", not_leaf))
    return items


def to_image(source):
    if source.startswith("synthetic:"):
        rng = np.random.default_rng(SEED * 1000 + int(source.split(":")[1]))
        return load_image(synthetic_texture(rng))
    return load_image(source)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset", required=True)
    ap.add_argument("--nonleaf", required=True)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "output"))
    ap.add_argument("--epochs", type=int, default=60)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    tf.keras.utils.set_random_seed(SEED)

    items = collect(args.dataset, args.nonleaf)
    labels = [y for _, y in items]
    train, rest = train_test_split(items, test_size=0.30, stratify=labels, random_state=SEED)
    val, test = train_test_split(rest, test_size=0.50, stratify=[y for _, y in rest], random_state=SEED)
    print("images per class:", {CLASSES[i]: labels.count(i) for i in range(len(CLASSES))})
    print(f"train {len(train)}  val {len(val)}  test {len(test)}")

    # Frozen MobileNetV2 feature extractor; the app's 0-1 input is rescaled to -1..1.
    inputs = tf.keras.Input((IMG, IMG, 3))
    x = tf.keras.layers.Rescaling(2.0, offset=-1.0)(inputs)
    base = tf.keras.applications.MobileNetV2(include_top=False, weights="imagenet", pooling="avg", input_shape=(IMG, IMG, 3))
    base.trainable = False
    features = base(x, training=False)
    extractor = tf.keras.Model(inputs, features)

    def extract(split, name):
        feats = []
        for start in range(0, len(split), 64):
            batch = np.stack([to_image(s) for s, _ in split[start:start + 64]])
            feats.append(extractor.predict(batch, verbose=0))
            print(f"  {name}: {min(start + 64, len(split))}/{len(split)}", end="\r")
        print()
        return np.concatenate(feats), np.array([y for _, y in split])

    print("Extracting features (frozen MobileNetV2)...")
    Xtr, ytr = extract(train, "train")
    Xva, yva = extract(val, "val")

    # Train the new 9-class head on the cached features.
    head = tf.keras.Sequential([
        tf.keras.Input((Xtr.shape[1],)),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(len(CLASSES), activation="softmax", kernel_regularizer=tf.keras.regularizers.l2(1e-4)),
    ])
    head.compile(optimizer=tf.keras.optimizers.Adam(1e-3), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    head.fit(Xtr, ytr, validation_data=(Xva, yva), epochs=args.epochs, batch_size=64, verbose=2,
             callbacks=[tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=8, restore_best_weights=True)])

    # Full model: image (0-1) -> class probabilities, as the app expects.
    outputs = head(features)
    model = tf.keras.Model(inputs, outputs)
    tflite = tf.lite.TFLiteConverter.from_keras_model(model).convert()
    with open(os.path.join(args.out, "crop_disease_model.tflite"), "wb") as f:
        f.write(tflite)
    with open(os.path.join(args.out, "labels.txt"), "w", newline="\n") as f:
        f.write("\n".join(CLASSES) + "\n")
    with open(os.path.join(args.out, "split.json"), "w") as f:
        json.dump({"classes": CLASSES, "train": train, "val": val, "test": test}, f)
    print("Saved model, labels and split to", args.out)


if __name__ == "__main__":
    main()
