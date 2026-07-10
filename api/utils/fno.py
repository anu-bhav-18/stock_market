"""
F&O data via yfinance options chain.
Works from cloud deployments (no NSE IP block).
"""

import yfinance as yf
import pandas as pd
from datetime import datetime

FNO_INDICES = ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"]

# yfinance ticker symbols for NSE indices
_INDEX_TICKER = {
    "NIFTY":      "^NSEI",
    "BANKNIFTY":  "^NSEBANK",
    "FINNIFTY":   "^CNXFIN",
    "MIDCPNIFTY": "^NSEMDCP50",
}


def _yf_symbol(symbol: str) -> str:
    s = symbol.upper()
    if s in _INDEX_TICKER:
        return _INDEX_TICKER[s]
    # Stock: add .NS if missing
    return s if s.endswith(".NS") else f"{s}.NS"


def fetch_option_chain(symbol: str) -> dict:
    """
    Fetch option chain via yfinance.
    Returns a normalised dict compatible with parse_option_chain.
    """
    ticker_sym = _yf_symbol(symbol)
    tk = yf.Ticker(ticker_sym)

    # Spot price
    try:
        fast = tk.fast_info
        spot = float(fast.get("lastPrice") or fast.get("last_price") or 0)
        if spot == 0:
            hist = tk.history(period="2d")
            spot = float(hist["Close"].iloc[-1]) if not hist.empty else 0.0
    except Exception:
        spot = 0.0

    # Expiry dates
    try:
        expiries = list(tk.options)
    except Exception:
        raise RuntimeError(
            f"No options data available for {symbol} via Yahoo Finance. "
            "This symbol may not have listed options."
        )

    if not expiries:
        raise RuntimeError(f"No expiry dates found for {symbol}.")

    # Fetch nearest 4 expiries
    rows = []
    fetched_expiries = []
    for exp in expiries[:4]:
        try:
            chain = tk.option_chain(exp)
            calls = chain.calls.copy()
            puts = chain.puts.copy()
            calls["expiry"] = exp
            puts["expiry"] = exp
            calls["option_type"] = "CE"
            puts["option_type"] = "PE"
            rows.append((exp, calls, puts))
            fetched_expiries.append(exp)
        except Exception:
            continue

    if not rows:
        raise RuntimeError(f"Could not fetch option chain data for {symbol}.")

    return {
        "spot": spot,
        "expiries": expiries,
        "fetched_expiries": fetched_expiries,
        "rows": rows,         # list of (expiry, calls_df, puts_df)
        "symbol": symbol.upper(),
    }


def parse_option_chain(raw: dict, expiry: str | None = None) -> dict:
    """
    Parse yfinance option chain data into the same structure the app expects.
    """
    spot = raw["spot"]
    all_expiries = raw["expiries"]
    rows = raw["rows"]       # [(expiry, calls_df, puts_df), ...]

    # Pick expiry
    fetched = [r[0] for r in rows]
    if expiry and expiry in fetched:
        selected_expiry = expiry
    else:
        selected_expiry = fetched[0] if fetched else ""

    calls_df, puts_df = None, None
    for (exp, c, p) in rows:
        if exp == selected_expiry:
            calls_df, puts_df = c, p
            break

    if calls_df is None or puts_df is None:
        raise RuntimeError("Selected expiry data not available.")

    # Build strikes list
    all_strikes = sorted(set(calls_df["strike"].tolist() + puts_df["strike"].tolist()))

    # Filter to ±15% around spot to reduce payload
    if spot > 0:
        lo, hi = spot * 0.85, spot * 1.15
        all_strikes = [s for s in all_strikes if lo <= s <= hi]

    def _row(df, strike):
        r = df[df["strike"] == strike]
        if r.empty:
            return {}
        r = r.iloc[0]
        return {
            "oi":        int(r.get("openInterest", 0) or 0),
            "coi":       0,   # yfinance doesn't provide daily OI change
            "volume":    int(r.get("volume", 0) or 0),
            "iv":        float(round((r.get("impliedVolatility", 0) or 0) * 100, 2)),
            "ltp":       float(r.get("lastPrice", 0) or 0),
            "change_pct": float(r.get("percentChange", 0) or 0),
        }

    strikes = []
    total_ce_oi = 0
    total_pe_oi = 0

    for strike in all_strikes:
        ce = _row(calls_df, strike)
        pe = _row(puts_df, strike)
        total_ce_oi += ce.get("oi", 0)
        total_pe_oi += pe.get("oi", 0)
        strikes.append({
            "strike":       strike,
            "ce_oi":        ce.get("oi", 0),
            "ce_coi":       0,
            "ce_volume":    ce.get("volume", 0),
            "ce_iv":        ce.get("iv", 0),
            "ce_ltp":       ce.get("ltp", 0),
            "ce_change_pct": ce.get("change_pct", 0),
            "pe_oi":        pe.get("oi", 0),
            "pe_coi":       0,
            "pe_volume":    pe.get("volume", 0),
            "pe_iv":        pe.get("iv", 0),
            "pe_ltp":       pe.get("ltp", 0),
            "pe_change_pct": pe.get("change_pct", 0),
        })

    pcr = round(total_pe_oi / total_ce_oi, 2) if total_ce_oi > 0 else 0.0
    max_pain = _calc_max_pain(strikes)

    if pcr > 1.2:
        pcr_signal = "Bullish"
    elif pcr < 0.8:
        pcr_signal = "Bearish"
    else:
        pcr_signal = "Neutral"

    if pcr_signal == "Bullish" and spot > max_pain:
        direction = "Buy CE"
        reasoning = [
            f"PCR {pcr:.2f} > 1.2 — more PE writers (bullish)",
            f"Spot ({spot:.0f}) above Max Pain ({max_pain:.0f}) — buyers in control",
        ]
    elif pcr_signal == "Bearish" and spot < max_pain:
        direction = "Buy PE"
        reasoning = [
            f"PCR {pcr:.2f} < 0.8 — more CE writers (bearish)",
            f"Spot ({spot:.0f}) below Max Pain ({max_pain:.0f}) — sellers in control",
        ]
    elif pcr_signal == "Bullish" and spot < max_pain:
        direction = "Buy CE (near Max Pain — wait for breakout)"
        reasoning = [
            f"PCR {pcr:.2f} bullish but spot ({spot:.0f}) below Max Pain ({max_pain:.0f})",
            "Wait for spot to move above max pain for stronger signal",
        ]
    elif pcr_signal == "Bearish" and spot > max_pain:
        direction = "Buy PE (near Max Pain — wait for breakdown)"
        reasoning = [
            f"PCR {pcr:.2f} bearish but spot ({spot:.0f}) above Max Pain ({max_pain:.0f})",
            "Wait for spot to break below max pain for confirmation",
        ]
    else:
        direction = "Neutral — wait for clarity"
        reasoning = [
            f"PCR {pcr:.2f} in neutral zone (0.8–1.2)",
            f"Spot ({spot:.0f}) near Max Pain ({max_pain:.0f})",
        ]

    atm = min((s["strike"] for s in strikes), key=lambda x: abs(x - spot), default=0)
    atm_data = next((s for s in strikes if s["strike"] == atm), {})

    return {
        "spot":            spot,
        "selected_expiry": selected_expiry,
        "all_expiries":    all_expiries,
        "pcr":             pcr,
        "pcr_signal":      pcr_signal,
        "max_pain":        max_pain,
        "direction":       direction,
        "reasoning":       reasoning,
        "oi_bias":         "PE buildup" if total_pe_oi > total_ce_oi else "CE buildup",
        "total_ce_oi":     total_ce_oi,
        "total_pe_oi":     total_pe_oi,
        "atm_strike":      atm,
        "atm_ce_ltp":      atm_data.get("ce_ltp", 0),
        "atm_pe_ltp":      atm_data.get("pe_ltp", 0),
        "atm_ce_iv":       atm_data.get("ce_iv", 0),
        "atm_pe_iv":       atm_data.get("pe_iv", 0),
        "strikes":         strikes,
        "data_source":     "Yahoo Finance",
    }


def _calc_max_pain(strikes: list) -> float:
    if not strikes:
        return 0.0
    ce_oi = {s["strike"]: s["ce_oi"] for s in strikes}
    pe_oi = {s["strike"]: s["pe_oi"] for s in strikes}
    strike_prices = sorted(ce_oi.keys())
    min_pain = float("inf")
    max_pain_strike = strike_prices[0]
    for test in strike_prices:
        pain = sum((test - sp) * oi for sp, oi in ce_oi.items() if test > sp)
        pain += sum((sp - test) * oi for sp, oi in pe_oi.items() if test < sp)
        if pain < min_pain:
            min_pain = pain
            max_pain_strike = test
    return max_pain_strike
