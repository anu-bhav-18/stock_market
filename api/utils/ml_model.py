"""
ML signal — logistic regression using numpy only.
Avoids sklearn which exceeds Vercel's 50MB Lambda size limit.
"""

import numpy as np
import pandas as pd

from .indicators import add_indicators

FEATURE_COLUMNS = [
    "RSI_14", "MACD", "MACD_hist",
    "Daily_return_pct", "Volatility_20", "Volume_change_pct",
]


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(x, -500, 500)))


def _fit_logistic(X: np.ndarray, y: np.ndarray, epochs: int = 300, lr: float = 0.05):
    mu = X.mean(axis=0)
    sigma = X.std(axis=0) + 1e-8
    Xn = (X - mu) / sigma
    w = np.zeros(Xn.shape[1])
    b = 0.0
    for _ in range(epochs):
        p = _sigmoid(Xn @ w + b)
        err = p - y
        w -= lr * (Xn.T @ err) / len(y)
        b -= lr * err.mean()
    return w, b, mu, sigma


def predict_probability_up(df: pd.DataFrame, horizon: int = 5) -> dict:
    data = add_indicators(df)
    data = data.copy()
    data["Future_return"] = data["Close"].shift(-horizon) / data["Close"] - 1
    data["Target"] = (data["Future_return"] > 0).astype(int)
    data = data.dropna(subset=FEATURE_COLUMNS + ["Target"])

    if len(data) < 80:
        return {"available": False, "reason": "Not enough history for ML model"}

    X = data[FEATURE_COLUMNS].values.astype(float)
    y = data["Target"].values.astype(float)

    split = int(len(X) * 0.8)
    w, b, mu, sigma = _fit_logistic(X[:split], y[:split])

    accuracy = None
    if len(X[split:]) > 5:
        Xn_test = (X[split:] - mu) / sigma
        preds = (_sigmoid(Xn_test @ w + b) >= 0.5).astype(int)
        accuracy = float((preds == y[split:].astype(int)).mean())

    # Retrain on full data
    w, b, mu, sigma = _fit_logistic(X, y, epochs=200)

    latest_row = add_indicators(df)[FEATURE_COLUMNS].iloc[[-1]].fillna(0).values.astype(float)
    Xn_latest = (latest_row - mu) / sigma
    proba_up = float(_sigmoid(Xn_latest @ w + b)[0])

    return {
        "available": True,
        "probability_up": proba_up,
        "horizon_days": horizon,
        "backtest_accuracy": accuracy,
        "samples_used": len(X),
    }
