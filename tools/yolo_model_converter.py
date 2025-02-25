# https://docs.ultralytics.com/models/yolov8/#supported-tasks-and-modes
# https://docs.ultralytics.com/modes/export/#usage-examples
# https://docs.ultralytics.com/modes/export/
# From command line: yolo export model=yolov8n.pt format=tflite
from ultralytics import YOLO

# Load offical YOLO model.
# Make sure the model is in the same directory with this code. Otherwise provide
# the path.
model = YOLO('yolo11m-cls.pt')

# Export the model to PyTorch TorchScript format.
# Yes it is correct. Without any extension the model is exported to the PyTorch 
# TorchScript format.
# model.export()

# Export the model to ONNX format.
# model.export(format="onnx")

# Export the model to TF SavedModel format.
# model.export(format="saved_model")

# Export the model to TF Lite format.
model.export(format='tflite')