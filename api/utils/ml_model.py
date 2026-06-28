"""
ML signal — RandomForest trained on-the-fly per stock.
No streamlit dependency; plain sklearn.
"""

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

from .indicators import add_indicators

FEATURE_COLUMNS = [
    "RSI_14", "MACD", "MACD_hist",
    "Daily_return_pct", "Volatility_20", "Volume_change_pct",
]


def predict_probability_up(df: pd.DataFrame, horizon: int = 5) -> dict:
    data = add_indicators(df)
    data["Future_return"] = data["Close"].shift(-horizon) / data["Close"] - 1
    data["Target"] = (data["Future_return"] > 0).astype(int)
    data = data.dropna(subset=FEATURE_COLUMNS + ["Target"])

    if len(data) < 80:
        return {"available": False, "reason": "Not enough history for a reliable model"}

    X = data[FEATURE_COLUMNS].values
    y = data["Target"].values
    latest = add_indicators(df)[FEATURE_COLUMNS].iloc[[-1]].fillna(0).values

    split = int(len(X) * 0.8)
    model = RandomForestClassifier(
        n_estimators=100, max_depth=4, min_samples_leaf=10, random_state=42
    )
    model.fit(X[:split], y[:split])
    accuracy = float(model.score(X[split:], y[split:])) if len(X[split:]) > 5 else None
    model.fit(X, y)
    proba_up = float(model.predict_proba(latest)[0][1])

    return {
        "available": True,
        "probability_up": proba_up,
        "horizon_days": horizon,
        "backtest_accuracy": accuracy,
        "samples_used": len(X),
    }
