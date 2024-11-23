from flask import Flask, request, jsonify

app = Flask(__name__)

# Example function that processes coordinates
def process_coordinates(coordinates):
    return [[1.2, 1.2], [1.3, 1.3]]

def process_danger_zone(coordinates):
    return [[1.2, 1.2, 1.2, 1.2], [1.3, 1.3, 1.3, 1.3]]

@app.route('/navigate', methods=['POST'])
def process_coordinates_endpoint():
    # Receive JSON data from the request
    data = request.get_json()

    # Ensure the data contains 'coordinates'
    if 'target' not in data:
        return jsonify({"error": "No coordinates found in the request"}), 400
    
    target = data['target']
    # Process the coordinates
    processed_coords = process_coordinates(target)

    # Return the processed coordinates as a JSON response
    return jsonify({"path": processed_coords, "danger_zone": process_danger_zone(target)})

if __name__ == '__main__':
    # Run the Flask app on localhost port 5000
    app.run(debug=True)
