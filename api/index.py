"""
StockSense FastAPI backend.

Local dev:  uvicorn api.index:app --reload --host 0.0.0.0 --port 8000
Vercel:     deployed automatically via vercel.json
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
import yfinance as yf
import pandas as pd

from .utils.indicators import add_indicators, technical_signal, historical_return
from .utils.stock_list import (
    ALL_STOCKS, INDICES, get_all_symbols, get_symbols_for_index, get_index_names
)
from .utils.fno import fetch_option_chain, parse_option_chain, FNO_INDICES

try:
    from .utils.ml_model import predict_probability_up as _ml_predict
    _ML_AVAILABLE = True
except Exception:
    _ML_AVAILABLE = False

app = FastAPI(title="StockSense API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------- Data helpers ----------

def _history(symbol: str, period: str = "1y") -> pd.DataFrame:
    try:
        df = yf.Ticker(symbol).history(period=period, interval="1d")
        return pd.DataFrame() if (df is None or df.empty) else df.reset_index()
    except Exception:
        return pd.DataFrame()


def _history_range(symbol: str, start: str, end: str) -> pd.DataFrame:
    try:
        df = yf.Ticker(symbol).history(start=start, end=end, interval="1d")
        return pd.DataFrame() if (df is None or df.empty) else df.reset_index()
    except Exception:
        return pd.DataFrame()


def _quote(symbol: str) -> dict:
    try:
        ticker = yf.Ticker(symbol)
        fast = ticker.fast_info
        price = fast.get("lastPrice") or fast.get("last_price")
        prev = fast.get("previousClose") or fast.get("previous_close")
        if price is None or prev is None:
            hist = ticker.history(period="5d")
            if hist.empty:
                return {}
            price = float(hist["Close"].iloc[-1])
            prev = float(hist["Close"].iloc[-2]) if len(hist) > 1 else price
        change = price - prev
        return {
            "price": float(price),
            "prev_close": float(prev),
            "change": float(change),
            "change_pct": float(change / prev * 100) if prev else 0.0,
        }
    except Exception:
        return {}


def _predict_ml(df: pd.DataFrame, horizon: int) -> dict:
    if not _ML_AVAILABLE:
        return {"available": False, "reason": "ML not available on this deployment"}
    try:
        return _ml_predict(df, horizon=horizon)
    except Exception as e:
        return {"available": False, "reason": str(e)}


def _composite(df: pd.DataFrame, horizon: int) -> dict:
    data = add_indicators(df)
    tech = technical_signal(data)
    ml = _predict_ml(df, horizon)
    tech_bull = (tech["score"] + 100) / 2
    composite = round(
        0.65 * tech_bull + 0.35 * ml["probability_up"] * 100, 1
    ) if ml.get("available") else round(tech_bull, 1)
    return {"composite_score": composite, "technical": tech, "ml": ml}


# ---------- Stock routes ----------

@app.get("/")
def root():
    return {"status": "ok", "service": "StockSense API v2", "ml_available": _ML_AVAILABLE}


@app.get("/indices")
def list_indices():
    return [{"name": n, "count": len(v)} for n, v in INDICES.items()]


@app.get("/stocks")
def list_stocks(index: str = Query(default="Nifty 50")):
    stocks = INDICES.get(index, {}) if index != "All" else ALL_STOCKS
    return [{"symbol": k, "name": v} for k, v in stocks.items()]


@app.get("/quote/{symbol}")
def get_quote(symbol: str):
    q = _quote(symbol)
    if not q:
        raise HTTPException(status_code=404, detail="Quote not available")
    return q


@app.get("/history/{symbol}")
def get_history(symbol: str, period: str = Query(default="6mo")):
    df = _history(symbol, period=period)
    if df.empty:
        raise HTTPException(status_code=404, detail="No history available")
    df = add_indicators(df)
    df["Date"] = df["Date"].astype(str)
    cols = ["Date", "Open", "High", "Low", "Close", "Volume",
            "SMA_20", "SMA_50", "RSI_14", "MACD", "BB_upper", "BB_lower"]
    cols = [c for c in cols if c in df.columns]
    return df[cols].replace({float("nan"): None}).to_dict(orient="records")


@app.get("/signal/{symbol}")
def get_signal(symbol: str, horizon: int = Query(default=5)):
    df = _history(symbol, period="1y")
    if df.empty:
        raise HTTPException(status_code=404, detail="No data available")
    return _composite(df, horizon)


@app.get("/screener")
def screener(
    index: str = Query(default="Nifty 50"),
    horizon: int = Query(default=5),
):
    symbols = get_symbols_for_index(index)
    results = []
    for symbol in symbols:
        df = _history(symbol, period="1y")
        if df.empty or len(df) < 60:
            continue
        result = _composite(df, horizon)
        last = float(df["Close"].iloc[-1])
        prev = float(df["Close"].iloc[-2]) if len(df) > 1 else last
        day_chg = (last - prev) / prev * 100 if prev else 0.0
        results.append({
            "symbol": symbol.replace(".NS", ""),
            "full_symbol": symbol,
            "name": ALL_STOCKS.get(symbol, symbol),
            "price": last,
            "day_change_pct": day_chg,
            "composite_score": result["composite_score"],
            "technical_label": result["technical"]["label"],
            "ml_prob_up": result["ml"].get("probability_up"),
        })
    results.sort(key=lambda x: x["composite_score"], reverse=True)
    return results


@app.get("/return/{symbol}")
def get_return(symbol: str, start: str = Query(...), end: str = Query(...)):
    df = _history_range(symbol, start=start, end=end)
    if df.empty:
        raise HTTPException(status_code=404, detail="No data for date range")
    result = historical_return(df, start_date=start, end_date=end)
    if not result:
        raise HTTPException(status_code=422, detail="Not enough data points in range")
    return result


# ---------- F&O routes ----------

@app.get("/fno/symbols")
def fno_symbols():
    """List of F&O index symbols and top F&O stocks."""
    fno_stocks = [
        {"symbol": k.replace(".NS", ""), "name": v, "type": "stock"}
        for k, v in ALL_STOCKS.items()
    ]
    indices = [{"symbol": s, "name": s, "type": "index"} for s in FNO_INDICES]
    return {"indices": indices, "stocks": fno_stocks[:50]}


@app.get("/fno/chain/{symbol}")
def option_chain(symbol: str, expiry: str = Query(default=None)):
    try:
        raw = fetch_option_chain(symbol)
        result = parse_option_chain(raw, expiry=expiry)

        # Return only ATM ± 15 strikes to keep payload small
        spot = result["spot"]
        strikes = result["strikes"]
        if spot > 0 and strikes:
            strikes_sorted = sorted(strikes, key=lambda s: abs(s["strike"] - spot))
            atm_strikes = set(s["strike"] for s in strikes_sorted[:31])
            result["strikes"] = [s for s in strikes if s["strike"] in atm_strikes]
            result["strikes"].sort(key=lambda s: s["strike"])

        return result
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"NSE data unavailable: {str(e)}")
