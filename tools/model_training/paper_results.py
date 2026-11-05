"""Computes the evaluation results reported in the research paper.

Uses the saved test split and the app's preprocessing. Reports per-class
precision/recall/F1, confusion matrices, Wilson 95% confidence intervals,
accuracy on leaves with no near-duplicate in training, robustness to simulated
photo conditions, and behaviour on plant images excluded from training.

Usage (from the project root):
  python tools/model_training/paper_results.py
Outputs: tools/model_training/results/results.json and confusion_matrix.png
"""
import glob, json, math, os
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import tensorflow as tf
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)
NOT_LEAF = "Not a leaf"
PLANTS = ["bonsai", "joshua_tree", "lotus", "sunflower", "water_lilly", "strawberry"]


class Model:
    def __init__(self, path, labels):
        self.it = tf.lite.Interpreter(model_path=path)
        self.it.allocate_tensors()
        self.i = self.it.get_input_details()[0]["index"]
        self.o = self.it.get_output_details()[0]["index"]
        self.labels = [l.strip() for l in open(labels) if l.strip()]

    def probs(self, im):
        x = np.asarray(im.convert("RGB").resize((224, 224), Image.NEAREST), np.float32) / 255
        self.it.set_tensor(self.i, x[None])
        self.it.invoke()
        return self.it.get_tensor(self.o)[0]

    def predict(self, im):
        p = self.probs(im)
        return self.labels[int(p.argmax())], float(p.max())


def wilson(k, n, z=1.96):
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return (round((c - m) / d * 100, 1), round((c + m) / d * 100, 1))


def source_image(s):
    if s.startswith("synthetic:"):
        from train_model import SEED, synthetic_texture
        rng = np.random.default_rng(SEED * 1000 + int(s.split(":")[1]))
        return synthetic_texture(rng)
    return Image.open(s)


def ahash(p):
    a = np.asarray(Image.open(p).convert("L").resize((16, 16), Image.BILINEAR), np.float32)
    return (a > a.mean()).flatten()


def metrics(y_true, y_pred, classes):
    idx = {c: i for i, c in enumerate(classes)}
    cm = np.zeros((len(classes), len(classes)), int)
    for t, p in zip(y_true, y_pred):
        cm[idx[t], idx[p]] += 1
    rows = {}
    for c in classes:
        i = idx[c]
        tp = int(cm[i, i]); fp = int(cm[:, i].sum() - tp); fn = int(cm[i].sum() - tp)
        pr = tp / (tp + fp) if tp + fp else 0
        rc = tp / (tp + fn) if tp + fn else 0
        rows[c] = {"n": int(cm[i].sum()), "precision": round(pr * 100, 1), "recall": round(rc * 100, 1),
                   "f1": round(2 * pr * rc / (pr + rc) * 100, 1) if pr + rc else 0}
    return cm, rows


def main():
    split = json.load(open(os.path.join(HERE, "output", "split.json")))
    classes = split["classes"]
    new = Model(os.path.join(PROJECT, "assets", "crop_disease_model.tflite"), os.path.join(PROJECT, "assets", "labels.txt"))
    old = Model(os.path.join(HERE, "original_model", "mobilenet_v1_1.0_224.tflite"), os.path.join(HERE, "original_model", "labels.txt"))
    res = {}

    # 1. New model, full held-out test split (9 classes).
    t, p, conf = [], [], []
    for s, y in split["test"]:
        lab, c = new.predict(source_image(s))
        t.append(classes[y]); p.append(lab); conf.append(c)
    cm, rows = metrics(t, p, classes)
    correct = sum(a == b for a, b in zip(t, p))
    res["test_all"] = {"n": len(t), "correct": correct, "accuracy": round(correct / len(t) * 100, 1), "ci95": wilson(correct, len(t)),
                       "macro_f1": round(float(np.mean([r["f1"] for r in rows.values()])), 1), "per_class": rows,
                       "errors": [[a, b] for a, b in zip(t, p) if a != b]}
    res["confidence"] = {"median_correct": round(float(np.median([c for a, b, c in zip(t, p, conf) if a == b])) * 100, 1),
                         "median_wrong": round(float(np.median([c for a, b, c in zip(t, p, conf) if a != b] or [0])) * 100, 1),
                         "below_60": sum(c < 0.6 for c in conf)}
    fig, ax = plt.subplots(figsize=(8.5, 7))
    ax.imshow(cm, cmap="Greens")
    ax.set_xticks(range(len(classes)), classes, rotation=45, ha="right"); ax.set_yticks(range(len(classes)), classes)
    ax.set_xlabel("Predicted class"); ax.set_ylabel("True class")
    for i in range(len(classes)):
        for j in range(len(classes)):
            if cm[i, j]:
                ax.text(j, i, cm[i, j], ha="center", va="center", color="white" if cm[i, j] > cm.max() / 2 else "black")
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "confusion_matrix.png"), dpi=200); plt.close(fig)

    # 2. Leaves only, old vs new, all and without near-duplicates in training.
    is_leaf = lambda s, y: not s.startswith("synthetic") and classes[y] != NOT_LEAF
    train = np.array([ahash(s) for s, y in split["train"] if is_leaf(s, y)])
    test_leaves = [(s, classes[y]) for s, y in split["test"] if is_leaf(s, y)]
    clean = [(s, c) for s, c in test_leaves if (train != ahash(s)).sum(axis=1).min() > 10]
    res["near_duplicate_share"] = {"test_leaves": len(test_leaves), "without_duplicate": len(clean)}
    for name, m in (("new", new), ("old", old)):
        for tag, data in (("all", test_leaves), ("clean", clean)):
            preds = [m.predict(Image.open(s))[0] for s, _ in data]
            k = sum(a == c for a, (_, c) in zip(preds, data))
            cm2, rows2 = metrics([c for _, c in data], preds, sorted(set(classes) | set(preds)))
            res[f"{name}_{tag}"] = {"n": len(data), "correct": k, "accuracy": round(k / len(data) * 100, 1), "ci95": wilson(k, len(data)),
                                    "recall": {c: r["recall"] for c, r in rows2.items() if r["n"]}}

    # 3. Robustness: simulated phone-photo conditions on duplicate-free leaves.
    conds = {
        "Original": lambda im: im,
        "Dark (50% brightness)": lambda im: ImageEnhance.Brightness(im).enhance(0.5),
        "Bright (150% brightness)": lambda im: ImageEnhance.Brightness(im).enhance(1.5),
        "Blurred (Gaussian, radius 3)": lambda im: im.filter(ImageFilter.GaussianBlur(3)),
        "Rotated 30 degrees": lambda im: im.convert("RGB").rotate(30, fillcolor=(235, 235, 235)),
        "Low resolution (64 px)": lambda im: im.convert("RGB").resize((64, 64), Image.BILINEAR),
    }
    res["robustness"] = {}
    for name, fn in conds.items():
        k = rej = 0
        for s, c in clean:
            lab, _ = new.predict(fn(Image.open(s)))
            k += lab == c; rej += lab == NOT_LEAF
        res["robustness"][name] = {"accuracy": round(k / len(clean) * 100, 1), "wrongly_not_leaf": rej, "n": len(clean)}

    # 4. Independent non-leaf images, old vs new.
    ood = [(f, Image.open(f)) for f in glob.glob(r"C:\Windows\Web\**\*.jpg", recursive=True)]
    for n in ["upload_image.png", "register_user.png", "user_login.png"]:
        ood.append((n, Image.open(os.path.join(PROJECT, "assets", n))))
    rng = np.random.default_rng(999)
    from train_model import synthetic_texture
    for i in range(40):
        ood.append((f"texture{i}", synthetic_texture(rng)))
    pen = np.full((224, 224, 3), 240, np.uint8); pen[100:120, 30:190] = (30, 40, 140)
    ood.append(("pen", Image.fromarray(pen)))
    photos = [x for x in ood if not x[0].startswith("texture")]
    res["independent"] = {
        "n": len(ood), "real_images": len(photos),
        "new_rejected": sum(new.predict(im)[0] == NOT_LEAF for _, im in ood),
        "new_rejected_real_images": sum(new.predict(im)[0] == NOT_LEAF for _, im in photos),
        "old_median_conf": round(float(np.median([old.predict(im)[1] for _, im in ood])) * 100, 1),
    }

    # 5. Plant categories excluded from training: never seen by the model.
    root = os.path.join(HERE, "data", "101_ObjectCategories")
    plants = {}
    for cat in PLANTS:
        fs = glob.glob(os.path.join(root, cat, "*"))
        preds = [new.predict(Image.open(f))[0] for f in fs]
        plants[cat] = {"n": len(fs), "not_a_leaf": sum(x == NOT_LEAF for x in preds), "named_disease": sum(x != NOT_LEAF for x in preds)}
    res["unseen_plants"] = plants

    json.dump(res, open(os.path.join(OUT, "results.json"), "w"), indent=1)
    print(json.dumps({k: v for k, v in res.items()}, indent=1))


if __name__ == "__main__":
    main()
