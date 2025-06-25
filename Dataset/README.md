20# Disease and Urgency Prediction API

This project provides a FastAPI-based API for predicting diseases and urgency levels based on symptoms using a machine learning model.

## Features

- Predict disease and urgency level from a list of symptoms.
- Webhook endpoint for integration with chatbots or other services.
- Improved model with hyperparameter tuning and evaluation.
- Logging of errors and requests.

## Getting Started

### Prerequisites

- Python 3.8+
- pip
- Virtual environment (recommended)

### Installation

1. Clone the repository and navigate to the project directory.

2. Create and activate a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

3. Install dependencies:

```bash
pip install -r requirements.txt
```

### Running the API

Start the FastAPI server using Uvicorn:

```bash
uvicorn main:app --reload
```

The API will be available at `http://127.0.0.1:8000`.

### API Endpoints

- `POST /predict`

  Request body:

  ```json
  {
    "symptoms": ["headache", "nausea"]
  }
  ```

  Response:

  ```json
  {
    "predicted_disease": "Migraine",
    "urgency_level": "Medium"
  }
  ```

- `POST /webhook`

  Request body:

  ```json
  {
    "queryResult": {
      "queryText": "I have headache and nausea"
    }
  }
  ```

  Response:

  ```json
  {
    "fulfillmentText": "🦠 Possible Disease: Migraine\n⚠️ Urgency Level: Medium"
  }
  ```

### Model Training

To retrain or improve the model, run:

```bash
python model_training.py
```

This will train the model with hyperparameter tuning and save the updated model and encoders.

### Docker Deployment (Optional)

Build the Docker image:

```bash
docker build -t disease-prediction-api .
```

Run the container:

```bash
docker run -p 8000:8000 disease-prediction-api
```

### License

MIT License
