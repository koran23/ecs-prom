# Use an official Python runtime as a parent image
FROM python:3.8-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the Python script and requirements file into the container
COPY fetch_tasks.py ./
COPY requirements.txt ./

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Run fetch_tasks.py when the container launches
CMD ["python", "./fetch_tasks.py"]
