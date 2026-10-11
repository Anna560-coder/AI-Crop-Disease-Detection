"""Evaluate a .tflite crop disease model the same way the app runs it.

Reports:
  1. Accuracy per class on the held-out TEST split (images never used in training).
  2. "Not a leaf" detection on an independent set never used in training:
     Windows wallpapers, the app's illustration assets, and synthetic textures
     generated with a different random seed from training.

Usage (from the project root):
  python tools/model_training/evaluate_model.py --model <file.tflite> --labels <labels.txt>
"""
import argparse, glob, json, os
import numpy as np
from PIL import Image
try:
    from ai_edge_litert.interpreter import Interpreter
except ImportError:
    from tensorflow.lite.python.interpreter import Interpreter

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
IMG = 224


def load_image(im):
    im = im if isinstance(im, Image.Image) else Image.open(im)
    return np.asarray(im.convert("RGB").resize((IMG, IMG), Image.NEAREST), dtype=np.float32) / 255.0


def synthetic_texture(rng):
    kind = rng.integers(0, 5)
    base = rng.integers(0, 256, 3).astype(np.float32)
    if kind == 0:
        arr = base + rng.normal(0, 6, (IMG, IMG, 3))
    elif kind == 1:
        arr = base + rng.normal(0, rng.uniform(10, 40), (IMG, IMG, 3))
    elif kind == 2:
        t = np.linspace(0, 1, IMG)[None, :, None]
        arr = base * (1 - t) + rng.integers(0, 256, 3) * t + np.zeros((IMG, 1, 1))
    elif kind == 3:
        arr = rng.integers(0, 256, (IMG, IMG, 3)).astype(np.float32)
    else:
        arr = rng.normal(rng.uniform(5, 40), 5, (IMG, IMG, 3))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def independent_non_leaf_set():
    items = [(os.path.basename(f), Image.open(f)) for f in glob.glob(r"C:\Windows\Web\**\*.jpg", recursive=True)]
    for name in ["upload_image.png", "register_user.png", "user_login.png"]:
        p = os.path.join(PROJECT, "assets", name)
        if os.path.exists(p):
            items.append((name, Image.open(p)))
    rng = np.random.default_rng(999)  # different seed from training (42)
    for n in range(40):
        items.append((f"synthetic texture {n}", synthetic_texture(rng)))
    pen = np.full((IMG, IMG, 3), 240, np.uint8); pen[100:120, 30:190] = (30, 40, 140)
    items.append(("blue pen on white paper", Image.fromarray(pen)))
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--labels", required=True)
    ap.add_argument("--split", default=os.path.join(HERE, "output", "split.json"))
    args = ap.parse_args()

    interp = Interpreter(model_path=args.model)
    interp.allocate_tensors()
    inp = interp.get_input_details()[0]["index"]
    out = interp.get_output_details()[0]["index"]
    labels = [l.strip() for l in open(args.labels) if l.strip()]

    def predict(img):
        interp.set_tensor(inp, load_image(img)[None])
        interp.invoke()
        return interp.get_tensor(out)[0]

    split = json.load(open(args.split))
    train_classes = split["classes"]
    print(f"Model: {os.path.basename(args.model)}  ({len(labels)} classes)\n")

    # 1. Held-out test split, leaves only for a fair old-vs-new comparison.
    print("1. Accuracy on held-out test leaves (never used in training)")
    per_class, total, correct = {}, 0, 0
    for source, y in split["test"]:
        truth = train_classes[y]
        if truth == "Not a leaf" or source.startswith("synthetic:"):
            continue
        pred = labels[int(predict(source).argmax())]
        ok = pred == truth
        c = per_class.setdefault(truth, [0, 0])
        c[0] += ok; c[1] += 1
        correct += ok; total += 1
    for cls, (ok, n) in sorted(per_class.items()):
        print(f"   {cls:18s} {ok:3d}/{n:3d}  {ok / n * 100:5.1f}%")
    print(f"   {'ALL LEAVES':18s} {correct:3d}/{total:3d}  {correct / total * 100:5.1f}%")

    # Held-out non-leaf images from the training sources (Caltech-101 objects).
    if "Not a leaf" in labels:
        nl = [(s, y) for s, y in split["test"] if train_classes[y] == "Not a leaf" and not s.startswith("synthetic:")]
        hits = sum(labels[int(predict(s).argmax())] == "Not a leaf" for s, _ in nl)
        print(f"   {'Not a leaf (objects)':18s} {hits:3d}/{len(nl):3d}  {hits / len(nl) * 100:5.1f}%")

    # 2. Independent non-leaf images: never seen in training.
    print("\n2. Independent non-leaf images (never used in training)")
    rejected = 0
    items = independent_non_leaf_set()
    for name, img in items:
        p = predict(img)
        pred = labels[int(p.argmax())]
        is_rejected = pred == "Not a leaf"
        rejected += is_rejected
        if not name.startswith("synthetic texture"):
            print(f"   {name:32s} -> {pred:16s} {p.max() * 100:5.1f}%  {'correct' if is_rejected else 'WRONG (shown as a disease)'}")
    print(f"   Correctly identified as 'Not a leaf': {rejected}/{len(items)}  ({rejected / len(items) * 100:.1f}%)")


if __name__ == "__main__":
    main()
