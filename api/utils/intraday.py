"""
Intraday scanner — VWAP, Opening Range Breakout, RSI, volume spike.
Uses yfinance intraday intervals (5m / 15m / 30m).
"""

import numpy as np
import pandas as pd
import yfinance as yf


def _rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_g = gain.ewm(alpha=1 / period, adjust=False).mean()
    avg_l = loss.ewm(alpha=1 / period, adjust=False).mean()
    rs = avg_g / avg_l.replace(0, np.nan)
    return (100 - 100 / (1 + rs)).fillna(50)


def _vwap(df: pd.DataFrame) -> pd.Series:
    tp = (df["High"] + df["Low"] + df["Close"]) / 3
    return (tp * df["Volume"]).cumsum() / df["Volume"].cumsum()


def _fetch_today(symbol: str, interval: str) -> pd.DataFrame:
    """Fetch intraday data and return only today's candles."""
    try:
        df = yf.Ticker(symbol).history(period="2d", interval=interval)
        if df is None or df.empty:
            return pd.DataFrame()
        df = df.reset_index()
        col = "Datetime" if "Datetime" in df.columns else "Date"
        df[col] = pd.to_datetime(df[col])
        last_date = df[col].dt.date.iloc[-1]
        today = df[df[col].dt.date == last_date].copy()
        return today if len(today) >= 3 else pd.DataFrame()
    except Exception:
        return pd.DataFrame()


def intraday_signal(symbol: str, interval: str = "15m") -> dict | None:
    """Compute intraday signal for a single symbol. Returns None if data unavailable."""
    df = _fetch_today(symbol, interval)
    if df.empty:
        return None

    df["VWAP"] = _vwap(df)
    df["RSI"] = _rsi(df["Close"])

    # Opening Range: first 2 candles (30 min for 15m, 15 min for 5m)
    or_bars = 2
    or_high = float(df["High"].iloc[:or_bars].max())
    or_low = float(df["Low"].iloc[:or_bars].min())

    last = df.iloc[-1]
    price = float(last["Close"])
    vwap = float(last["VWAP"])
    rsi = float(last["RSI"])

    # Volume ratio: latest bar vs session average
    avg_vol = float(df["Volume"].mean())
    vol_ratio = float(last["Volume"]) / avg_vol if avg_vol > 0 else 1.0

    # Day change from session open
    open_price = float(df["Open"].iloc[0])
    day_chg_pct = (price - open_price) / open_price * 100 if open_price > 0 else 0.0

    above_vwap = price > vwap
    orb_breakout = price > or_high and len(df) > or_bars
    orb_breakdown = price < or_low and len(df) > or_bars

    # Signal logic
    if orb_breakout and above_vwap and rsi > 55:
        signal = "ORB Breakout"
    elif orb_breakdown and not above_vwap and rsi < 45:
        signal = "ORB Breakdown"
    elif above_vwap and rsi > 60 and vol_ratio > 1.8:
        signal = "Strong Buy"
    elif above_vwap and rsi > 52:
        signal = "Buy"
    elif not above_vwap and rsi < 40 and vol_ratio > 1.8:
        signal = "Strong Sell"
    elif not above_vwap and rsi < 48:
        signal = "Sell"
    else:
        signal = "Neutral"

    return {
        "symbol": symbol.replace(".NS", ""),
        "full_symbol": symbol,
        "price": round(price, 2),
        "vwap": round(vwap, 2),
        "rsi": round(rsi, 1),
        "volume_ratio": round(vol_ratio, 2),
        "day_chg_pct": round(day_chg_pct, 2),
        "above_vwap": above_vwap,
        "or_high": round(or_high, 2),
        "or_low": round(or_low, 2),
        "orb_breakout": orb_breakout,
        "orb_breakdown": orb_breakdown,
        "signal": signal,
        "candles": len(df),
    }


def scan_intraday(symbols: list, interval: str = "15m") -> list:
    """Scan a list of symbols and return sorted intraday signals."""
    results = []
    for sym in symbols:
        r = intraday_signal(sym, interval)
        if r:
            results.append(r)

    order = {
        "ORB Breakout": 0, "Strong Buy": 1, "Buy": 2,
        "Neutral": 3,
        "ORB Breakdown": 4, "Strong Sell": 5, "Sell": 6,
    }
    results.sort(key=lambda x: order.get(x["signal"], 9))
    return results


def intraday_chart(symbol: str, interval: str = "15m") -> list:
    """Return OHLCV + VWAP candles for a symbol (today only)."""
    df = _fetch_today(symbol, interval)
    if df.empty:
        return []
    df["VWAP"] = _vwap(df)
    col = "Datetime" if "Datetime" in df.columns else "Date"
    records = []
    for _, row in df.iterrows():
        records.append({
            "time": str(row[col]),
            "open": round(float(row["Open"]), 2),
            "high": round(float(row["High"]), 2),
            "low": round(float(row["Low"]), 2),
            "close": round(float(row["Close"]), 2),
            "volume": int(row["Volume"]),
            "vwap": round(float(row["VWAP"]), 2),
        })
    return records
