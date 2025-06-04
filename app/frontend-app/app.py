# app/frontend-app/app.py

from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/')
def hello_world():
    # Get the hostname of the EC2 instance for demonstration
    hostname = os.uname().nodename
    return f"Hello from the Frontend! This is instance: {hostname}\n"

@app.route('/health')
def health_check():
    # Simple health check endpoint for the load balancer
    return jsonify({"status": "healthy"}), 200

if __name__ == '__main__':
    # Listen on all available interfaces (0.0.0.0) on the specified port
    # The container_port variable in Terraform will map to this.
    port = int(os.environ.get("PORT", 8000))
    app.run(host='0.0.0.0', port=port)