import os
import requests
import ee
import vertexai
from flask import Flask, render_template, request, jsonify, send_from_directory
from vertexai.preview.vision_models import Image, ImageGenerationModel
from io import BytesIO
import base64
from google.oauth2 import service_account

app = Flask(__name__, static_folder='.', template_folder='.')

# --- AUTH & CONFIG ---
PROJECT_ID = "rnd-geocoding-1538682427772"
LOCATION = "us-central1"
KEY_PATH = "service-account-key.json"

# Set credentials for Google Cloud SDK
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = KEY_PATH

def init_ai_services():
    """Helper to ensure services are initialized before use"""
    try:
        # Check if already initialized (using internal flag as a hint)
        if not hasattr(ee, 'data') or not getattr(ee.data, '_initialized', False):
            print("Initializing Earth Engine...")
            credentials = service_account.Credentials.from_service_account_file(KEY_PATH)
            scoped_credentials = credentials.with_scopes([
                'https://www.googleapis.com/auth/cloud-platform', 
                'https://www.googleapis.com/auth/earthengine'
            ])
            ee.Initialize(credentials=scoped_credentials, project=PROJECT_ID)
            
        # Vertex AI is usually fine to init multiple times, but we'll be safe
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        return True
    except Exception as e:
        print(f"Initialization Error: {e}")
        return False

# Initial attempt at startup
init_ai_services()

@app.route('/')
def index():
    # Serve the 3D Flight Simulator
    return render_template('index.html')

@app.route('/slides')
def slides():
    # Serve the workshop slides
    return render_template('slides.html')

@app.route('/<path:filename>')
def serve_static(filename):
    return send_from_directory('.', filename)

@app.route('/terraform', methods=['POST'])
def terraform():
    # Ensure initialized before processing request
    if not init_ai_services():
        return jsonify({"error": "AI Services (Earth Engine/Vertex) failed to initialize. Check service-account-key.json"}), 500

    try:
        data = request.json
        lat = data.get('lat')
        lon = data.get('lon')
        prompt = data.get('prompt')
        
        # Size of the "Terraformed" patch (approx 500m)
        offset = 0.0025 
        
        # 1. Earth Engine: Fetch Satellite Image
        region = ee.Geometry.Rectangle([lon - offset, lat - offset, lon + offset, lat + offset])
        s2 = ee.ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
        image = s2.filterBounds(region).filterDate('2023-01-01', '2024-01-01') \
                  .sort('CLOUDY_PIXEL_PERCENTAGE').first().clip(region)

        vis_params = {
            'min': 0, 'max': 3000, 
            'bands': ['B4', 'B3', 'B2'], 
            'dimensions': 1024,
            'region': region
        }
        
        original_img_url = image.getThumbURL(vis_params)

        # 2. Vertex AI: Generate Transformation
        response = requests.get(original_img_url)
        base_image = Image(image_bytes=response.content)
        model = ImageGenerationModel.from_pretrained("imagegeneration@006")
        
        # Simplified call for broader SDK compatibility
        generated_images = model.edit_image(
            base_image=base_image,
            prompt=f"A photorealistic high-resolution aerial view of {prompt}. Match perspective and lighting.",
        )
        
        output_buffer = BytesIO()
        generated_images[0].save(output_buffer, include_generation_parameters=False)
        generated_img_b64 = base64.b64encode(output_buffer.getvalue()).decode('utf-8')

        return jsonify({
            "image": generated_img_b64,
            "bounds": [lat - offset, lon - offset, lat + offset, lon + offset]
        })

    except Exception as e:
        print(f"Terraforming Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=8080)
