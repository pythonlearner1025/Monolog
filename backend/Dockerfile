FROM python:3.9.16-bullseye

# Set environment varibles
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set work directory
WORKDIR /app

# Install dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# Copy project
COPY . /app/

# Uvicorn will listen on this port
EXPOSE 3000 

# Run the application:
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3000"]
