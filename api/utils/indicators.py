import numpy as np
import pandas as pd


def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty or "Close" not in df.columns:
        return df

    out = df.copy()
    close = out["Close"]

    out["SMA_20"] = close.rolling(20).mean()
    out["SMA_50"] = close.rolling(50).mean()
    out["EMA_12"] = close.ewm(span=12, adjust=False).mean()
    out["EMA_26"] = close.ewm(span=26, adjust=False).mean()

    out["MACD"] = out["EMA_12"] - out["EMA_26"]
    out["MACD_signal"] = out["MACD"].ewm(span=9, adjust=False).mean()
    out["MACD_hist"] = out["MACD"] - out["MACD_signal"]

    delta = close.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.rolling(14).mean()
    avg_loss = loss.rolling(14).mean()
    rs = avg_gain / avg_loss.replace(0, np.nan)
    out["RSI_14"] = 100 - (100 / (1 + rs))
    out["RSI_14"] = out["RSI_14"].fillna(50)

    sma20 = out["SMA_20"]
    std20 = close.rolling(20).std()
    out["BB_upper"] = sma20 + 2 * std20
    out["BB_lower"] = sma20 - 2 * std20

    if "Volume" in out.columns:
        out["Volume_SMA_20"] = out["Volume"].rolling(20).mean()
        out["Volume_change_pct"] = out["Volume"].pct_change() * 100

    out["Daily_return_pct"] = close.pct_change() * 100
    out["Volatility_20"] = out["Daily_return_pct"].rolling(20).std()

    return out


def technical_signal(df: pd.DataFrame) -> dict:
    if df.empty or len(df) < 30:
        return {"score": 0, "label": "Not enough data", "reasons": []}

    row = df.iloc[-1]
    score = 0
    reasons = []

    if pd.notna(row.get("SMA_20")) and pd.notna(row.get("SMA_50")):
        if row["Close"] > row["SMA_20"] > row["SMA_50"]:
            score += 25
            reasons.append("Price above both 20 & 50-day averages (uptrend)")
        elif row["Close"] < row["SMA_20"] < row["SMA_50"]:
            score -= 25
            reasons.append("Price below both 20 & 50-day averages (downtrend)")

    rsi = row.get("RSI_14", 50)
    if pd.notna(rsi):
        if rsi < 30:
            score += 15
            reasons.append(f"RSI {rsi:.0f} — oversold, possible bounce")
        elif rsi > 70:
            score -= 15
            reasons.append(f"RSI {rsi:.0f} — overbought, possible pullback")
        elif rsi > 55:
            score += 8
            reasons.append(f"RSI {rsi:.0f} — bullish momentum")
        elif rsi < 45:
            score -= 8
            reasons.append(f"RSI {rsi:.0f} — bearish momentum")

    macd_hist = row.get("MACD_hist", 0)
    prev_hist = df["MACD_hist"].iloc[-2] if len(df) > 1 else 0
    if pd.notna(macd_hist) and pd.notna(prev_hist):
        if macd_hist > 0 and prev_hist <= 0:
            score += 20
            reasons.append("MACD just crossed bullish")
        elif macd_hist < 0 and prev_hist >= 0:
            score -= 20
            reasons.append("MACD just crossed bearish")
        elif macd_hist > 0:
            score += 8
            reasons.append("MACD histogram positive")
        else:
            score -= 8
            reasons.append("MACD histogram negative")

    vol_chg = row.get("Volume_change_pct", 0)
    if pd.notna(vol_chg) and vol_chg > 30 and row.get("Daily_return_pct", 0) > 0:
        score += 12
        reasons.append("Price up on a volume surge")

    score = max(-100, min(100, score))

    if score >= 35:
        label = "Strong Buy"
    elif score >= 12:
        label = "Buy"
    elif score <= -35:
        label = "Strong Sell"
    elif score <= -12:
        label = "Sell"
    else:
        label = "Hold"

    return {"score": score, "label": label, "reasons": reasons}


def historical_return(df: pd.DataFrame, start_date=None, end_date=None) -> dict:
    if df.empty:
        return {}

    data = df.copy()
    if "Date" in data.columns:
        data["Date"] = pd.to_datetime(data["Date"]).dt.tz_localize(None)
        if start_date is not None:
            data = data[data["Date"] >= pd.to_datetime(start_date)]
        if end_date is not None:
            data = data[data["Date"] <= pd.to_datetime(end_date)]

    if len(data) < 2:
        return {}

    start_price = float(data["Close"].iloc[0])
    end_price = float(data["Close"].iloc[-1])
    pct_return = (end_price - start_price) / start_price * 100

    days = int((data["Date"].iloc[-1] - data["Date"].iloc[0]).days) if "Date" in data.columns else len(data)
    years = max(days / 365.25, 1 / 365.25)
    cagr = ((end_price / start_price) ** (1 / years) - 1) * 100 if start_price > 0 else 0

    daily_returns = data["Close"].pct_change().dropna()
    volatility = float(daily_returns.std() * 100 * np.sqrt(252)) if len(daily_returns) > 1 else 0.0

    return {
        "start_price": start_price,
        "end_price": end_price,
        "pct_return": pct_return,
        "cagr": cagr,
        "annualized_volatility": volatility,
        "days": days,
    }
