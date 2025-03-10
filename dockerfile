FROM python:3.8-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    mlflow \
    pandas \
    numpy \
    scikit-learn

COPY . .

CMD ["python", "train.py"]
