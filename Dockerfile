# Use an official Python runtime as the base image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy application code to the container
COPY app.py /app

# Install required dependencies
RUN pip install flask flask-cors

# Expose the application port
EXPOSE 5000

# Command to run the application
CMD ["python", "app.py"]
