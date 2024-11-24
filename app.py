from flask import Flask, jsonify
from flask_cors import CORS

app =  Flask(__name__)

CORS(app, resources={r"/*": {"origins": "*"}})

@app.route('/')
def hello():
    return jsonify({"message": "Hello from the Backend!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
