"""
StockSense FastAPI backend.

Local dev:  uvicorn api.index:app --reload --host 0.0.0.0 --port 8000
Vercel:     deployed automatically via vercel.json
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from concurrent.futures import ThreadPoolExecutor, as_completed
import yfinance as yf
import pandas as pd
import numpy as np


def _jsonify(obj):
    """Recursively convert numpy/pandas scalars to Python natives for JSON."""
    if isinstance(obj, dict):
        return {k: _jsonify(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_jsonify(v) for v in obj]
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, (np.bool_,)):
        return bool(obj)
    if isinstance(obj, float) and (obj != obj):   # NaN
        return None
    return obj

# Vercel filesystem is read-only except /tmp — point yfinance cache there
yf.set_tz_cache_location("/tmp")

from .utils.indicators import add_indicators, technical_signal, historical_return
from .utils.stock_list import (
    ALL_STOCKS, INDICES, get_all_symbols, get_symbols_for_index, get_index_names
)
from .utils.fno import fetch_option_chain, parse_option_chain, FNO_INDICES, _get_spot, _yf_symbol
from .utils.fno_bs import build_synthetic_chain
from .utils.intraday import intraday_signal, scan_intraday, intraday_chart
from .utils.levels import pivot_points, support_resistance
from .utils.patterns import detect_patterns

try:
    from .utils.ml_model import predict_probability_up as _ml_predict
    _ML_AVAILABLE = True
except Exception:
    _ML_AVAILABLE = False

app = FastAPI(title="StockSense API", version="3.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Data helpers ──────────────────────────────────────────────────────────────

def _history(symbol: str, period: str = "6mo") -> pd.DataFrame:
    """Use yf.download (faster than Ticker.history) with auto_adjust for clean prices."""
    try:
        df = yf.download(symbol, period=period, interval="1d",
                         auto_adjust=True, progress=False, threads=False)
        if df is None or df.empty:
            return pd.DataFrame()
        df = df.reset_index()
        # yf.download may return MultiIndex columns when single ticker — flatten
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = [c[0] if c[1] == symbol or c[1] == "" else c[0] for c in df.columns]
        return df
    except Exception:
        return pd.DataFrame()


def _history_range(symbol: str, start: str, end: str) -> pd.DataFrame:
    try:
        df = yf.download(symbol, start=start, end=end, interval="1d",
                         auto_adjust=True, progress=False, threads=False)
        if df is None or df.empty:
            return pd.DataFrame()
        df = df.reset_index()
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = [c[0] for c in df.columns]
        return df
    except Exception:
        return pd.DataFrame()


def _quote(symbol: str) -> dict:
    """Get quote from last 5d download — avoids a second HTTP round-trip."""
    try:
        df = yf.download(symbol, period="5d", interval="1d",
                         auto_adjust=True, progress=False, threads=False)
        if df is None or df.empty:
            return {}
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = [c[0] for c in df.columns]
        price = float(df["Close"].iloc[-1])
        prev  = float(df["Close"].iloc[-2]) if len(df) > 1 else price
        change = price - prev
        return {
            "price":      price,
            "prev_close": prev,
            "change":     float(change),
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
    tech_bull = (tech["score"] + 100) / 2.0
    prob_up = ml.get("probability_up")
    # Guard against NaN: pd.notna handles both None and float('nan')
    if ml.get("available") and pd.notna(prob_up):
        composite = float(round(0.65 * tech_bull + 0.35 * float(prob_up) * 100, 1))
        ml["probability_up"] = float(prob_up)
    else:
        composite = float(round(tech_bull, 1))
        ml["probability_up"] = None
    acc = ml.get("backtest_accuracy")
    ml["backtest_accuracy"] = float(acc) if pd.notna(acc) else None
    return {"composite_score": composite, "technical": tech, "ml": ml}


# ── Basic routes ──────────────────────────────────────────────────────────────

@app.get("/")
def root():
    return {"status": "ok", "service": "StockSense API v3", "ml_available": _ML_AVAILABLE}


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
    return JSONResponse(content=_jsonify(q))


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
    records = df[cols].replace({float("nan"): None}).to_dict(orient="records")
    return JSONResponse(content=_jsonify(records))


@app.get("/signal/{symbol}")
def get_signal(symbol: str, horizon: int = Query(default=5)):
    df = _history(symbol, period="6mo")
    if df.empty:
        raise HTTPException(status_code=404, detail="No data available")
    try:
        result = _composite(df, horizon)
        result["patterns"] = detect_patterns(df)
        return JSONResponse(content=_jsonify(result))
    except Exception as e:
        import traceback
        raise HTTPException(status_code=500, detail=f"Signal error: {str(e)} | {traceback.format_exc()[-300:]}")


@app.get("/screener")
def screener(
    index: str = Query(default="Nifty 50"),
    horizon: int = Query(default=5),
):
    symbols = get_symbols_for_index(index)

    def _process(symbol):
        try:
            df = _history(symbol, period="3mo")
            if df.empty or len(df) < 50:
                return None
            result = _composite(df, horizon)
            last = float(df["Close"].iloc[-1])
            prev = float(df["Close"].iloc[-2]) if len(df) > 1 else last
            day_chg = float((last - prev) / prev * 100) if prev else 0.0
            patterns = detect_patterns(df)
            return {
                "symbol": symbol.replace(".NS", ""),
                "full_symbol": symbol,
                "name": ALL_STOCKS.get(symbol, symbol),
                "price": last,
                "day_change_pct": day_chg,
                "composite_score": result["composite_score"],
                "technical_label": result["technical"]["label"],
                "ml_prob_up": result["ml"].get("probability_up"),
                "pattern": patterns[0]["name"] if patterns else None,
            }
        except Exception:
            return None

    results = []
    with ThreadPoolExecutor(max_workers=10) as ex:
        futures = {ex.submit(_process, s): s for s in symbols}
        for f in as_completed(futures):
            r = f.result()
            if r:
                results.append(r)

    results.sort(key=lambda x: x["composite_score"], reverse=True)
    return JSONResponse(content=_jsonify(results))


@app.get("/stock/{symbol}")
def get_stock_detail(symbol: str, horizon: int = Query(default=5)):
    """All-in-one stock detail: quote + signal + levels + indicators."""
    try:
        df = _history(symbol, period="6mo")
        if df.empty:
            raise HTTPException(status_code=404, detail="No data for symbol")
        q = _quote(symbol)
        result = _composite(df, horizon)
        result["patterns"] = detect_patterns(df)
        pivots = pivot_points(df)
        sr = support_resistance(df)
        # Key indicators from last row
        data = add_indicators(df)
        last = data.iloc[-1]
        indicators = {
            "rsi": float(last.get("RSI_14", 50) or 50),
            "macd": float(last.get("MACD", 0) or 0),
            "macd_hist": float(last.get("MACD_hist", 0) or 0),
            "sma20": float(last.get("SMA_20", 0) or 0),
            "sma50": float(last.get("SMA_50", 0) or 0),
            "bb_upper": float(last.get("BB_upper", 0) or 0),
            "bb_lower": float(last.get("BB_lower", 0) or 0),
            "volume": int(last.get("Volume", 0) or 0),
            "volume_sma20": float(last.get("Volume_SMA_20", 0) or 0),
            "volatility_20": float(last.get("Volatility_20", 0) or 0),
        }
        return {
            "symbol": symbol,
            "quote": q,
            **result,
            **pivots,
            **sr,
            "indicators": indicators,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stock detail error: {str(e)}")


@app.get("/return/{symbol}")
def get_return(symbol: str, start: str = Query(...), end: str = Query(...)):
    df = _history_range(symbol, start=start, end=end)
    if df.empty:
        raise HTTPException(status_code=404, detail="No data for date range")
    result = historical_return(df, start_date=start, end_date=end)
    if not result:
        raise HTTPException(status_code=422, detail="Not enough data points in range")
    return result


# ── Levels & Patterns ─────────────────────────────────────────────────────────

@app.get("/levels/{symbol}")
def get_levels(symbol: str):
    """Pivot points + swing S/R levels for a stock."""
    df = _history(symbol, period="6mo")
    if df.empty:
        raise HTTPException(status_code=404, detail="No data available")
    pivots = pivot_points(df)
    sr = support_resistance(df)
    return JSONResponse(content=_jsonify({**pivots, **sr}))


@app.get("/patterns/{symbol}")
def get_patterns(symbol: str):
    """Candlestick pattern detection on last 5 daily candles."""
    df = _history(symbol, period="3mo")
    if df.empty:
        raise HTTPException(status_code=404, detail="No data available")
    return {"patterns": detect_patterns(df)}


# ── Intraday ──────────────────────────────────────────────────────────────────

@app.get("/intraday/scan")
def intraday_scan(
    index: str = Query(default="Nifty Bank"),
    interval: str = Query(default="15m"),
):
    """
    Scan an index for intraday signals (VWAP, ORB, RSI, volume).
    Uses parallel fetching for speed within Vercel's time limits.
    """
    if interval not in ("5m", "15m", "30m"):
        raise HTTPException(status_code=400, detail="interval must be 5m, 15m, or 30m")
    symbols = get_symbols_for_index(index)
    results = []
    with ThreadPoolExecutor(max_workers=10) as ex:
        futures = {ex.submit(intraday_signal, s, interval): s for s in symbols}
        for f in as_completed(futures):
            r = f.result()
            if r:
                results.append(r)
    order = {"ORB Breakout": 0, "Strong Buy": 1, "Buy": 2, "Neutral": 3,
             "ORB Breakdown": 4, "Strong Sell": 5, "Sell": 6}
    results.sort(key=lambda x: order.get(x["signal"], 9))
    return JSONResponse(content=_jsonify(results))


@app.get("/intraday/{symbol}")
def get_intraday(symbol: str, interval: str = Query(default="15m")):
    """Return OHLCV + VWAP candles for today + intraday signal."""
    if interval not in ("5m", "15m", "30m"):
        raise HTTPException(status_code=400, detail="interval must be 5m, 15m, or 30m")
    sig = intraday_signal(symbol, interval=interval)
    candles = intraday_chart(symbol, interval=interval)
    if not candles:
        raise HTTPException(status_code=404, detail="No intraday data — market may be closed")
    return {"signal": sig, "candles": candles}


# ── F&O ───────────────────────────────────────────────────────────────────────

@app.get("/fno/symbols")
def fno_symbols():
    fno_stocks = [
        {"symbol": k.replace(".NS", ""), "name": v, "type": "stock"}
        for k, v in ALL_STOCKS.items()
    ]
    indices = [{"symbol": s, "name": s, "type": "index"} for s in FNO_INDICES]
    return JSONResponse(content=_jsonify({"indices": indices, "stocks": fno_stocks[:50]}))


@app.get("/stock/fundamentals/{symbol}")
def stock_fundamentals(symbol: str):
    """P/E, P/B, EPS, Market Cap, Dividends, Debt/Equity, ROE from yfinance."""
    try:
        tk = yf.Ticker(symbol)
        info = tk.info or {}
        def _v(key, default=None):
            val = info.get(key, default)
            return None if val in (None, "N/A", "", "None") else val

        # VWAP from last 20 trading days
        hist = tk.history(period="20d")
        vwap = None
        if not hist.empty and "Volume" in hist.columns:
            tp = (hist["High"] + hist["Low"] + hist["Close"]) / 3
            total_vol = hist["Volume"].sum()
            vwap = float((tp * hist["Volume"]).sum() / total_vol) if total_vol > 0 else None

        # Fibonacci levels from 52-week range
        high52 = _v("fiftyTwoWeekHigh")
        low52  = _v("fiftyTwoWeekLow")
        fib = {}
        if high52 and low52:
            diff = float(high52) - float(low52)
            fib = {
                "0":    round(float(low52), 2),
                "23.6": round(float(high52) - diff * 0.236, 2),
                "38.2": round(float(high52) - diff * 0.382, 2),
                "50":   round(float(high52) - diff * 0.500, 2),
                "61.8": round(float(high52) - diff * 0.618, 2),
                "78.6": round(float(high52) - diff * 0.786, 2),
                "100":  round(float(high52), 2),
            }

        return JSONResponse(content=_jsonify({
            "symbol":          symbol,
            "market_cap":      _v("marketCap"),
            "pe_ratio":        _v("trailingPE"),
            "forward_pe":      _v("forwardPE"),
            "pb_ratio":        _v("priceToBook"),
            "eps":             _v("trailingEps"),
            "forward_eps":     _v("forwardEps"),
            "dividend_yield":  _v("dividendYield"),
            "beta":            _v("beta"),
            "debt_to_equity":  _v("debtToEquity"),
            "roe":             _v("returnOnEquity"),
            "revenue_growth":  _v("revenueGrowth"),
            "profit_margin":   _v("profitMargins"),
            "high_52w":        high52,
            "low_52w":         low52,
            "avg_volume":      _v("averageVolume"),
            "sector":          _v("sector", ""),
            "industry":        _v("industry", ""),
            "vwap_20d":        round(vwap, 2) if vwap else None,
            "fibonacci":       fib,
        }))
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.get("/market/vix")
def market_vix():
    """India VIX + 20-day history."""
    try:
        tk   = yf.Ticker("^INDIAVIX")
        fast = tk.fast_info
        current = float(getattr(fast, "last_price", None) or 0)
        hist = tk.history(period="30d")
        history = []
        if not hist.empty:
            for dt, row in hist.iterrows():
                history.append({"date": str(dt.date()), "value": round(float(row["Close"]), 2)})
            if current == 0 and history:
                current = history[-1]["value"]

        # VIX interpretation
        if current < 15:
            sentiment = "Low Fear"
            note = "Market is calm. Good time to buy options (cheap premiums)."
            color = "green"
        elif current < 20:
            sentiment = "Moderate"
            note = "Normal volatility. Options fairly priced."
            color = "orange"
        elif current < 25:
            sentiment = "Elevated Fear"
            note = "Market is nervous. Consider buying puts for protection."
            color = "red"
        else:
            sentiment = "High Fear"
            note = "Panic zone. Contrarian buy signal for the brave."
            color = "red"

        prev = history[-2]["value"] if len(history) >= 2 else current
        change = round(current - prev, 2)
        change_pct = round((current - prev) / prev * 100, 2) if prev > 0 else 0.0

        return JSONResponse(content=_jsonify({
            "current":    round(current, 2),
            "change":     change,
            "change_pct": change_pct,
            "sentiment":  sentiment,
            "note":       note,
            "color":      color,
            "history":    history[-20:],
        }))
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e))


@app.get("/fno/chain/{symbol}")
def option_chain(symbol: str, expiry: str = Query(default=None)):
    result = None

    # 1. Try live Yahoo Finance options chain
    try:
        raw    = fetch_option_chain(symbol)
        result = parse_option_chain(raw, expiry=expiry)
    except Exception:
        pass  # fall through to synthetic

    # 2. Fallback: Black-Scholes synthetic chain (always works)
    if result is None:
        try:
            ticker_sym = _yf_symbol(symbol.upper())
            import yfinance as yf
            spot_tk = yf.Ticker(ticker_sym)
            spot    = _get_spot(spot_tk)
            if spot <= 0:
                raise RuntimeError(f"Could not fetch spot price for {symbol}.")
            result = build_synthetic_chain(symbol, spot)
        except Exception as e:
            raise HTTPException(status_code=503, detail=f"Options data unavailable: {e}")

    # Trim strikes to ATM ±15 around spot
    spot    = result.get("spot", 0)
    strikes = result.get("strikes", [])
    if spot > 0 and strikes:
        strikes_sorted = sorted(strikes, key=lambda s: abs(s["strike"] - spot))
        atm_strikes    = set(s["strike"] for s in strikes_sorted[:31])
        result["strikes"] = sorted(
            [s for s in strikes if s["strike"] in atm_strikes],
            key=lambda s: s["strike"],
        )

    # Add next-day prediction if not already present
    if "next_day" not in result:
        try:
            from .utils.fno import predict_next_day
            result["next_day"] = predict_next_day(
                {"hist_closes": []}, result
            )
        except Exception:
            pass

    return JSONResponse(content=_jsonify(result))


# ── News ──────────────────────────────────────────────────────────────────────

@app.get("/news/{symbol}")
def get_news(symbol: str):
    """Latest news headlines for a stock via yfinance."""
    try:
        tk = yf.Ticker(symbol)
        news = tk.news or []
        result = []
        for n in news[:10]:
            ct = n.get("content", {})
            pub_date = None
            if ct.get("pubDate"):
                pub_date = ct["pubDate"]
            elif n.get("providerPublishTime"):
                from datetime import datetime, timezone
                pub_date = datetime.fromtimestamp(n["providerPublishTime"], tz=timezone.utc).isoformat()
            result.append({
                "title":        ct.get("title") or n.get("title", ""),
                "publisher":    (ct.get("provider") or {}).get("displayName") or n.get("publisher", ""),
                "link":         (ct.get("canonicalUrl") or {}).get("url") or n.get("link", ""),
                "publish_time": pub_date,
                "summary":      ct.get("summary") or None,
            })
        return JSONResponse(content=_jsonify(result))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"News error: {str(e)}")


# ── Market breadth & 52-week ──────────────────────────────────────────────────

@app.get("/market/breadth")
def market_breadth(index: str = Query(default="Nifty 50")):
    """Advance/decline ratio + % above SMA50 for an index."""
    symbols = get_symbols_for_index(index)

    def _check(symbol):
        try:
            df = _history(symbol, period="3mo")
            if df.empty or len(df) < 2:
                return None
            data = add_indicators(df)
            last  = data.iloc[-1]
            prev  = data.iloc[-2]
            chg   = float((last["Close"] - prev["Close"]) / prev["Close"] * 100)
            sma50 = last.get("SMA_50")
            above = bool(pd.notna(sma50) and last["Close"] > sma50)
            return {"change": chg, "above_sma50": above}
        except Exception:
            return None

    results = []
    with ThreadPoolExecutor(max_workers=8) as ex:
        futures = {ex.submit(_check, s): s for s in symbols}
        for f in as_completed(futures):
            r = f.result()
            if r:
                results.append(r)

    if not results:
        raise HTTPException(status_code=503, detail="Could not fetch breadth data")

    advancing  = sum(1 for r in results if r["change"] > 0.05)
    declining  = sum(1 for r in results if r["change"] < -0.05)
    unchanged  = len(results) - advancing - declining
    adr        = round(advancing / declining, 2) if declining > 0 else float(advancing)
    above_50   = round(sum(1 for r in results if r["above_sma50"]) / len(results) * 100, 1)
    avg_chg    = round(sum(r["change"] for r in results) / len(results), 2)

    return JSONResponse(content=_jsonify({
        "advancing": advancing, "declining": declining, "unchanged": unchanged,
        "total": len(results), "advance_decline_ratio": adr,
        "pct_above_sma50": above_50, "average_change_pct": avg_chg,
    }))


@app.get("/market/52week")
def week52(index: str = Query(default="Nifty 50"), type: str = Query(default="high")):
    """Stocks near 52-week high or low."""
    symbols = get_symbols_for_index(index)

    def _check(symbol):
        try:
            df = _history(symbol, period="1y")
            if df.empty or len(df) < 50:
                return None
            high52 = float(df["High"].max())
            low52  = float(df["Low"].min())
            last   = float(df["Close"].iloc[-1])
            prev   = float(df["Close"].iloc[-2])
            chg    = float((last - prev) / prev * 100)
            pct_from_high = (last - high52) / high52 * 100
            pct_from_low  = (last - low52) / low52 * 100
            return {
                "symbol":     symbol.replace(".NS", ""),
                "full_symbol": symbol,
                "name":       ALL_STOCKS.get(symbol, symbol),
                "price":      last,
                "day_change_pct": chg,
                "high_52w":   high52,
                "low_52w":    low52,
                "pct_from_high": round(pct_from_high, 2),
                "pct_from_low":  round(pct_from_low, 2),
                "composite_score": 50.0,
                "technical_label": "Near High" if type == "high" else "Near Low",
            }
        except Exception:
            return None

    results = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futures = {ex.submit(_check, s): s for s in symbols}
        for f in as_completed(futures):
            r = f.result()
            if r:
                results.append(r)

    if type == "high":
        results.sort(key=lambda x: x["pct_from_high"], reverse=True)  # closest to high first
    else:
        results.sort(key=lambda x: x["pct_from_low"])  # closest to low first

    return JSONResponse(content=_jsonify(results[:20]))


@app.get("/market/trends")
def market_trends(index: str = Query(default="Nifty 50"), period: str = Query(default="1wk")):
    """
    Week or month-wise top gainers/losers + index return.
    period: '1wk' or '1mo'
    """
    symbols = get_symbols_for_index(index)
    yf_period = "1mo" if period == "1mo" else "5d"

    def _check(symbol):
        try:
            df = _history(symbol, period=yf_period)
            if df.empty or len(df) < 2:
                return None
            first = float(df["Close"].iloc[0])
            last  = float(df["Close"].iloc[-1])
            if first == 0:
                return None
            ret  = round((last - first) / first * 100, 2)
            vol  = float(df["Volume"].mean()) if "Volume" in df.columns else 0.0
            high = float(df["High"].max())
            low  = float(df["Low"].min())
            return {
                "symbol":      symbol.replace(".NS", ""),
                "name":        ALL_STOCKS.get(symbol, symbol.replace(".NS", "")),
                "start_price": round(first, 2),
                "end_price":   round(last, 2),
                "return_pct":  ret,
                "period_high": round(high, 2),
                "period_low":  round(low, 2),
                "avg_volume":  round(vol, 0),
            }
        except Exception:
            return None

    # Cap at 30 symbols to stay within Vercel 10s limit
    symbols = symbols[:30]
    results = []
    with ThreadPoolExecutor(max_workers=15) as ex:
        futures = {ex.submit(_check, s): s for s in symbols}
        for f in as_completed(futures, timeout=8):
            try:
                r = f.result()
                if r:
                    results.append(r)
            except Exception:
                pass

    gainers = sorted([r for r in results if r["return_pct"] > 0], key=lambda x: x["return_pct"], reverse=True)
    losers  = sorted([r for r in results if r["return_pct"] < 0], key=lambda x: x["return_pct"])
    avg_ret = round(sum(r["return_pct"] for r in results) / len(results), 2) if results else 0.0

    return JSONResponse(content=_jsonify({
        "index":   index,
        "period":  period,
        "avg_return_pct": avg_ret,
        "total":   len(results),
        "gainers": gainers[:10],
        "losers":  losers[:10],
    }))
