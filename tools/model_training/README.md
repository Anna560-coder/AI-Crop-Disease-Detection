# Crop disease model: "Not a leaf" retraining

The app's model now has 9 classes: the 8 MangoLeafBD classes plus **Not a leaf**.
When a farmer photographs something that is not a leaf, the app says
"This doesn't look like a crop leaf" instead of naming a disease, and does not
save the result to their history.

## Why it was needed

The original 8-class model was trained only on leaves, so it always picked a
disease. On 80 non-leaf images it named a disease every time, often with high
confidence (a brick wall: 99.7% Bacterial Canker). Two cheaper fixes were tested
and rejected:

| Approach tested | Problem found |
| --- | --- |
| Reject photos with little green | Die Back (brown) and Cutting Weevil (purple) leaves have no green: nearly all rejected |
| Reject low-confidence results | Non-leaf images often scored 90-100%; no threshold separates them |

## Method

- **Leaves:** MangoLeafBD, 8 classes x 500 images.
- **Not a leaf (2,500 images):** 1,900 everyday objects and people from
  [Caltech-101](https://data.caltech.edu/records/mzrjq-6wc02) (20 per category; the
  6 plant categories excluded), 300 random scenes (Caltech `BACKGROUND_Google`),
  300 generated textures (walls, soil, noise, plain colours, dark photos).
- **Model:** MobileNetV2 pre-trained on ImageNet, frozen, with a new 9-class
  softmax layer. Input is a 224x224 image scaled to 0-1, exactly as the app
  sends it; the model rescales internally.
- **Split:** 70% train, 15% validation, 15% test, stratified, seed 42
  (`output/split.json` lists every file).

## Results

| Measure | Original model | New model |
| --- | --- | --- |
| Test leaves, all 600 | 91.8% | 99.0% |
| Test leaves with no near-duplicate in training (489) | 90.6% | **98.8%** |
| Sooty Mould test leaves | 58.7% | 98.7% |
| Held-out Caltech objects called "Not a leaf" | n/a | 328/328 |
| Independent non-leaf images called "Not a leaf"* | **0/80** | **80/80** |

\* Never used in training: 36 Windows wallpapers, the app's 3 illustration
images, 40 textures generated with a different random seed, and a pen on white
paper.

**Limitations to state in the report**

- 18% of MangoLeafBD test leaves have a near-identical photo in the training
  set (the dataset contains augmented copies), which inflates the 99.0% figure.
  The 98.8% figure excludes them.
- All MangoLeafBD photos show one leaf on a plain background. Photos of leaves
  still on the tree, in field light, have not been tested, so the app tells
  farmers to lay the leaf on white paper.
- A leaf from a different crop is not a "Not a leaf" case: the model has never
  seen other crops and will name a mango disease.
- The new model is 8.9 MB (the original was 2.1 MB) because it is stored
  unquantised for maximum accuracy.

## Reproduce

Python 3.12, from the project root:

```
pip install -r tools/model_training/requirements.txt
# Caltech-101: download caltech-101.zip from the link above, extract
# 101_ObjectCategories into tools/model_training/data/
python tools/model_training/train_model.py --dataset "<path to MangoLeafBD Dataset>" --nonleaf tools/model_training/data/101_ObjectCategories
python tools/model_training/evaluate_model.py --model tools/model_training/output/crop_disease_model.tflite --labels tools/model_training/output/labels.txt
```

Then copy `output/crop_disease_model.tflite` and `output/labels.txt` into `assets/`.
The labels file order must match the model's outputs; `train_model.py` writes both together.

The original model and labels are kept in `original_model/`. To compare, run
`evaluate_model.py --model tools/model_training/original_model/mobilenet_v1_1.0_224.tflite --labels tools/model_training/original_model/labels.txt`.
