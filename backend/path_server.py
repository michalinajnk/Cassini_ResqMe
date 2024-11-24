import ast
import json
import os

import polyline
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)


# Example function that processes coordinates
def process_coordinates(start, target, danger_zone_coord):
    """
    Returns:
    list of coordinates of the subsequent steps in map eg:
    [(50.75638, 17.61983),
     (50.7565, 17.61958),
     (50.75737, 17.61826),
     (50.75751, 17.61799),
     (50.75746, 17.61792)
     ]
    """
    coordinates = [start, target]

    avoid_polygon = {
        "type": "MultiPolygon",
        "coordinates": [
            [danger_zone_coord[i]] for i in range(len(danger_zone_coord))
        ],
    }

    body = {
        "coordinates": coordinates,
        "options": {
            "avoid_polygons": avoid_polygon,
        },
    }

    API_KEY = os.getenv("API_KEY")
    headers = {
        "Accept": "application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8",
        "Authorization": API_KEY,
        "Content-Type": "application/json; charset=utf-8",
    }

    call = requests.post(
        "https://api.openrouteservice.org/v2/directions/foot-walking",
        json=body,
        headers=headers,
    )

    route_data = call.json()
    route_geometry = route_data["routes"][0]["geometry"]
    route_geometry = polyline.decode(route_geometry)

    return route_geometry


def process_danger_zone(rect_coord):
    """
    return:
        list_of_coordinates: coordinates of points of each polygon, format is as follows:
        list_of_coordinates = [
                                [
                                    [longitude_1, latitude_1],
                                    [longitude_2, latitude_2],
                                    [longitude_3, latitude_3],
                                    [longitude_4, latitude_4],
                                    [longitude_1, latitude_1],
                                ] # polygon 1
                                ...
                                [] # polygon n
                                ]
    """
    result = []

    for bbox in rect_coord:
        # Unpack the two vertices (longitude and latitude)
        lon1, lat1, lon2, lat2 = bbox

        # Define the 5 coordinates: A, B, C, D, A
        rect_coords = [
            [lon1, lat1],  # A: Bottom-left (long1, lat1)
            [lon2, lat1],  # B: Bottom-right (long2, lat1)
            [lon2, lat2],  # C: Top-right (long2, lat2)
            [lon1, lat2],  # D: Top-left (long1, lat2)
            [lon1, lat1],  # A: Closing the rectangle (same as the first point)
        ]

        # Append the coordinates of the rectangle to the result list
        result.append(rect_coords)

    return result
    # return [[1.2, 1.2, 1.2, 1.2], [1.3, 1.3, 1.3, 1.3]]


# temporary function
def read_bbox_file(file_path):
    with open(file_path, "r") as file:
        # Read the content of the file and parse it into a list of lists
        bbox_list = ast.literal_eval(
            file.read()
        )  # safely parse the content into a list
    return bbox_list

def mock_generate_path(start, target):
    """
    Generates a mock path as a list of coordinate points between start and target.
    """
    # Extract start and target coordinates
    start_lon, start_lat = start
    target_lon, target_lat = target

    # Determine the number of steps in the mock path
    steps = 100

    # Generate intermediate points between start and target
    path = []
    for i in range(steps + 1):
        fraction = i / steps
        lon = start_lon + fraction * (target_lon - start_lon)
        lat = start_lat + fraction * (target_lat - start_lat)
        path.append([lon, lat])

    return path


@app.route("/", methods=["GET"])
def home():
    return "Welcome to ResQMe app server. Use /navigate for API requests.", 200


@app.route("/navigate", methods=["GET", "POST"])
def process_coordinates_endpoint():
    start, target = None, None

    if request.method == "GET":
        # Extract and validate query parameters
        start = request.args.get("start")
        target = request.args.get("target")

        if not start or not target:
            return jsonify({"error": "Missing 'start' or 'target'"}), 400

        # Convert strings to lists of floats
        try:
            start = [float(coord) for coord in start.split(",")]
            target = [float(coord) for coord in target.split(",")]
        except ValueError:
            return jsonify({"error": "Invalid 'start' or 'target' format"}), 400

    elif request.method == "POST":
        # Extract and validate JSON payload
        data = request.get_json()
        if not data or "start" not in data or "target" not in data:
            return jsonify({"error": "Missing 'start' or 'target' in the request"}), 400

        start = data["start"]
        target = data["target"]

    # Validate start and target are lists of coordinates
    if not (isinstance(start, list) and isinstance(target, list) and len(start) == 2 and len(target) == 2):
        return jsonify({"error": "'start' and 'target' must be lists of two coordinates [longitude, latitude]"}), 400

    try:
        rect_coord = read_bbox_file("tmp_rect_coord.txt")
        danger_zone_coord = process_danger_zone(rect_coord)

        # Temporary hardcoded processed data (replace with actual processing logic)
        with open("tmp_processed_coord.txt", "r") as file:
            processed_coord = ast.literal_eval(file.read())  # safely parse the content into a list
    except Exception as e:
        return jsonify({"error": f"Server processing error: {str(e)}"}), 500

    # Return the processed coordinates and danger zones
    return jsonify({"path": processed_coord, "danger_zone": danger_zone_coord})


if __name__ == "__main__":
    # Run the Flask app on localhost port 5000
    app.run(debug=True)
