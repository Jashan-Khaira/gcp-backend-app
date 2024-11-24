from flask import Flask, jsonify
from flask_cors import CORS
import os

app = Flask(__name__)

CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/')
def hello():
    return jsonify({"message": "Hello from the Backend!"})

if __name__ == '__main__':
    # Bind to the PORT environment variable or default to 8080
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)
