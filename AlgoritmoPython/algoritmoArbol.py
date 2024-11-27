from flask import Flask, request, jsonify
from flask_cors import CORS
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
import pandas as pd

app = Flask(__name__)
CORS(app)  # Permitir solicitudes desde cualquier origen

# Datos ficticios para el modelo
data = {
    'edad_dispositivo': [1, 2, 3, 4, 5],
    'estado_bateria': [80, 70, 50, 40, 20],
    'rendimiento': [90, 75, 60, 50, 30],
    'frecuencia_reparacion': [0, 1, 2, 2, 3],
    'recomendacion': ['mantener', 'mantener', 'vender', 'cambiar', 'cambiar']
}

# Crear DataFrame
df = pd.DataFrame(data)

# Separar características y objetivo
X = df[['edad_dispositivo', 'estado_bateria',
        'rendimiento', 'frecuencia_reparacion']]
y = df['recomendacion']

# Dividir datos
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.3, random_state=42)

# Crear y entrenar el modelo
clf = DecisionTreeClassifier(random_state=42)
clf.fit(X_train, y_train)

# Ruta para recibir datos y predecir


@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Obtener datos enviados desde Flutter
        data = request.json
        edad_dispositivo = int(data.get('edad_dispositivo', -1))
        estado_bateria = int(data.get('estado_bateria', 70)
                             )  # Valor por defecto
        rendimiento = int(data.get('rendimiento', 80))  # Valor por defecto
        frecuencia_reparacion = int(
            data.get('frecuencia_reparacion', 0))  # Valor por defecto

        # Verificar que la edad del dispositivo sea válida
        if edad_dispositivo < 0:
            return jsonify({"error": "Edad del dispositivo no válida."}), 400

        # Crear entrada para el modelo
        nueva_entrada = [[edad_dispositivo, estado_bateria,
                          rendimiento, frecuencia_reparacion]]

        # Realizar predicción
        prediccion = clf.predict(nueva_entrada)
        return jsonify({"recomendacion": prediccion[0]}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
