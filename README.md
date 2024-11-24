# Cassini_ResqMe
Mobile app in Flutter for showing evacuation route omitting dangerous areas.

This project focuses on utilizing Sentinel satellite imagery to detect and predict natural disasters such as floods or fires, segment affected areas, mark danger zones, and navigate safely around them.

1. Downloading Images from Sentinel Database
The first step in this project involves obtaining satellite imagery from the Sentinel database (e.g., Sentinel-2, Sentinel-3). These satellites provide open-access, high-resolution images that can be used to monitor various environmental conditions, including fires and floods.

2. Detecting Floods or Fires
Once the Sentinel images are downloaded, the next step is to detect potential disasters like floods or fires in the images. This can be done using machine learning models and image processing techniques.

Fire Detection:
Utilize the Sentinel-3 SLSTR L1B TIR  to detect fires in vegetation areas.
Flood Detection:
Use the Sentinel-3 OLCI L2 Water to detect changes in water levels, identifying flooded areas.

3. Predicting and Interpolating Next Images
Prediction and interpolation help anticipate how a disaster might evolve. This can be done using time-series analysis and machine learning models like LSTM or convolutional neural networks (CNN) trained on historical image data and weather forecast.

Prediction: Use temporal data to predict the spread of fires or flood zones.
Interpolation: Generate intermediate images to fill gaps in time or provide smooth transitions between time steps.

4. Segmentation of Affected Areas
Once a disaster has been detected, segmentation is used to isolate the affected areas. This step involves applying segmentation models to create masks that highlight the regions impacted by the flood or fire.

5. Marking Danger Zones
Once segmentation is completed, the next step is to mark the identified danger zones. These zones are critical for risk assessment, evacuation planning, and resource deployment.

6. Navigating with Skipping Danger Zones
Once the danger zones are identified and marked, the system can suggest a safe navigation route that avoids these zones.
.


