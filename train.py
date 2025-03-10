import mlflow
import mlflow.sklearn
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
import os

def main():
    # Set MLflow tracking URI from environment variable or use default
    mlflow_uri = os.getenv('MLFLOW_TRACKING_URI', "http://localhost:5000")
    mlflow.set_tracking_uri(mlflow_uri)
    mlflow.set_experiment("Resume_Project_Experiment")

    try:
        # Load and prepare data
        data = pd.read_csv("https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-diabetes.data.csv", 
                          header=None,
                          names=['Pregnancies', 'Glucose', 'BloodPressure', 'SkinThickness', 
                                'Insulin', 'BMI', 'DiabetesPedigreeFunction', 'Age', 'Outcome'])
        
        # Split features and target
        X = data.drop('Outcome', axis=1)
        y = data['Outcome']

        # Split into train and test sets
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )

        # Define model parameters
        model_params = {
            "n_estimators": 100,
            "max_depth": 5,
            "random_state": 42
        }

        # Start MLflow Run
        with mlflow.start_run():
            # Train model
            model = RandomForestClassifier(**model_params)
            model.fit(X_train, y_train)
            
            # Make predictions and calculate accuracy
            y_pred = model.predict(X_test)
            accuracy = accuracy_score(y_test, y_pred)
            
            # Log parameters
            mlflow.log_params(model_params)
            
            # Log metrics
            mlflow.log_metric("accuracy", accuracy)
            
            # Log model
            mlflow.sklearn.log_model(model, "random_forest_model")

            print(f"Model trained and logged with accuracy: {accuracy:.4f}")

            # Log feature importance
            feature_importance = pd.DataFrame(
                model.feature_importances_,
                index=X.columns,
                columns=['importance']
            ).sort_values('importance', ascending=False)
            
            print("\nFeature Importance:")
            print(feature_importance)

    except Exception as e:
        print(f"Error during training: {str(e)}")
        raise

if __name__ == "__main__":
    main()
