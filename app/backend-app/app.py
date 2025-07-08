# app/backend-app/app.py

from flask import Flask, jsonify
import os
import psycopg2 # PostgresSQL adapter
from psycopg2 import OperationalError

app = Flask(__name__)

# Environment variables will be populated by ECS Task Definition
DB_HOST = os.environ.get("DB_HOST")
DB_NAME = os.environ.get("DB_NAME")
DB_USER = os.environ.get("DB_USER")
DB_PASSWORD = os.environ.get("DB_PASSWORD") # From Secrets Manager

def get_db_connection():
    conn = None
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        return conn
    except OperationalError as e:
        print(f"Database connection failed: {e}")
        return None
    
@app.route('/')
def hello_backend():
    hostname = os.uname().nodename
    return f"Hello from the Backend! This is instance: {hostname}\n"

@app.route('/health')
def health_check():
    # Simple health check endpoint for the internal load balancer
    return jsonify({"status": "healthy"}), 200

@app.route('/db-test')
def db_test():
    conn = get_db_connection()
    if conn:
        conn.close()
        return jsonify({"db_status": "Database connection successful!"}), 200
    else:
        return jsonify({"db_status": "Database connection failed."}), 500
    
if __name__=='__main__':
    # Flask app listens on all available interfaces (0.0.0.0) on the specified port
    # The container_port variable in Terraform will map to this.
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port)