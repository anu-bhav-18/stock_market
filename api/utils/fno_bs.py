"""
Black-Scholes synthetic option chain for NSE indices.
Used as fallback when Yahoo Finance doesn't have live options data.
Provides theoretically accurate pricing based on historical volatility.
"""

import math
from datetime import date, timedelta
import yfinance as yf

# RBI repo rate (risk-free rate)
RISK_FREE_RATE = 0.065

# Standard NSE strike intervals per index
_STRIKE_INTERVAL = {
    "NIFTY":      50,
    "BANKNIFTY":  100,
    "FINNIFTY":   50,
    "MIDCPNIFTY": 25,
}

_INDEX_TICKER = {
    "NIFTY":      "^NSEI",
    "BANKNIFTY":  "^NSEBANK",
    "FINNIFTY":   "^CNXFIN",
    "MIDCPNIFTY": "^NSEMDCP50",
}


def _norm_cdf(x: float) -> float:
    """Standard normal CDF via Horner's method."""
    if x < -6: return 0.0
    if x > 6:  return 1.0
    k = 1.0 / (1.0 + 0.2316419 * abs(x))
    k2 = k * k
    k3 = k2 * k
    k4 = k3 * k
    k5 = k4 * k
    poly = (0.319381530 * k - 0.356563782 * k2 + 1.781477937 * k3
            - 1.821255978 * k4 + 1.330274429 * k5)
    result = 1.0 - math.exp(-x * x / 2) / math.sqrt(2 * math.pi) * poly
    return result if x >= 0 else 1.0 - result


def _bs(S, K, T, r, sigma, opt):
    """Black-Scholes price + Greeks for a call ('C') or put ('P')."""
    if T <= 0 or sigma <= 0 or S <= 0 or K <= 0:
        intrinsic = max(S - K, 0) if opt == "C" else max(K - S, 0)
        return {"ltp": round(intrinsic, 2), "iv": 0.0, "delta": 0.0,
                "gamma": 0.0, "theta": 0.0, "vega": 0.0}

    sqrtT = math.sqrt(T)
    d1 = (math.log(S / K) + (r + 0.5 * sigma ** 2) * T) / (sigma * sqrtT)
    d2 = d1 - sigma * sqrtT

    Nd1  = _norm_cdf(d1)
    Nd2  = _norm_cdf(d2)
    nNd1 = _norm_cdf(-d1)
    nNd2 = _norm_cdf(-d2)
    phi_d1 = math.exp(-d1 * d1 / 2) / math.sqrt(2 * math.pi)

    disc = math.exp(-r * T)

    if opt == "C":
        price = S * Nd1 - K * disc * Nd2
        delta = Nd1
    else:
        price = K * disc * nNd2 - S * nNd1
        delta = Nd1 - 1.0

    gamma = phi_d1 / (S * sigma * sqrtT)
    vega  = S * phi_d1 * sqrtT / 100          # per 1% IV change
    theta_c = (-(S * phi_d1 * sigma) / (2 * sqrtT)
               - r * K * disc * Nd2) / 365
    theta_p = (-(S * phi_d1 * sigma) / (2 * sqrtT)
               + r * K * disc * nNd2) / 365
    theta = theta_c if opt == "C" else theta_p

    return {
        "ltp":   round(max(price, 0.05), 2),
        "iv":    round(sigma * 100, 2),
        "delta": round(delta, 4),
        "gamma": round(gamma, 6),
        "theta": round(theta, 4),
        "vega":  round(vega, 4),
    }


def _hist_volatility(ticker_sym: str, days: int = 20) -> float:
    """Annualised historical volatility from last N trading days."""
    try:
        tk = yf.Ticker(ticker_sym)
        hist = tk.history(period="60d")
        if hist.empty or len(hist) < 5:
            return 0.18   # default 18%
        closes = hist["Close"].tolist()[-days:]
        if len(closes) < 2:
            return 0.18
        import math as _m
        log_rets = [_m.log(closes[i] / closes[i-1]) for i in range(1, len(closes))]
        mean = sum(log_rets) / len(log_rets)
        variance = sum((r - mean) ** 2 for r in log_rets) / (len(log_rets) - 1)
        return _m.sqrt(variance * 252)   # annualised
    except Exception:
        return 0.18


def _nse_expiries(n: int = 4) -> list[str]:
    """
    Generate next N NSE expiry dates.
    NSE weekly options expire every Thursday;
    monthly on the last Thursday of the month.
    Returns date strings YYYY-MM-DD.
    """
    expiries = []
    today = date.today()
    # Walk forward day by day up to 90 days to find Thursdays
    d = today
    for _ in range(120):
        d += timedelta(days=1)
        if d.weekday() == 3:   # Thursday
            expiries.append(str(d))
            if len(expiries) >= n:
                break
    return expiries


def build_synthetic_chain(symbol: str, spot: float) -> dict:
    """
    Build a full synthetic option chain using Black-Scholes.
    Returns the same dict structure as parse_option_chain().
    """
    sym = symbol.upper()
    ticker_sym = _INDEX_TICKER.get(sym, f"{sym}.NS")
    interval = _STRIKE_INTERVAL.get(sym, 50)

    # Historical volatility
    hv = _hist_volatility(ticker_sym)
    r  = RISK_FREE_RATE

    # Expiries
    expiries = _nse_expiries(4)
    if not expiries:
        raise RuntimeError("Could not generate expiry dates.")
    selected_expiry = expiries[0]

    # Time to expiry in years
    today = date.today()
    exp_date = date.fromisoformat(selected_expiry)
    T = max((exp_date - today).days / 365.0, 1/365)

    # Generate strikes: ATM ± 15 strikes
    atm = round(spot / interval) * interval
    strikes_range = range(-15, 16)
    strikes = [atm + i * interval for i in strikes_range if atm + i * interval > 0]

    chain_rows = []
    total_ce_oi = 0
    total_pe_oi = 0

    for K in strikes:
        ce = _bs(spot, K, T, r, hv, "C")
        pe = _bs(spot, K, T, r, hv, "P")

        # Synthetic OI: higher OI near ATM, lower far OTM/ITM (bell curve shape)
        dist = abs(K - atm) / interval
        oi_factor = max(0, int(50000 * math.exp(-0.15 * dist * dist)))
        ce_oi = oi_factor + (10000 if K > atm else 5000)
        pe_oi = oi_factor + (10000 if K < atm else 5000)

        total_ce_oi += ce_oi
        total_pe_oi += pe_oi

        chain_rows.append({
            "strike":       float(K),
            "ce_oi":        ce_oi,
            "ce_coi":       0,
            "ce_volume":    0,
            "ce_iv":        ce["iv"],
            "ce_ltp":       ce["ltp"],
            "ce_change_pct": 0.0,
            "ce_delta":     ce["delta"],
            "ce_gamma":     ce["gamma"],
            "ce_theta":     ce["theta"],
            "ce_vega":      ce["vega"],
            "pe_oi":        pe_oi,
            "pe_coi":       0,
            "pe_volume":    0,
            "pe_iv":        pe["iv"],
            "pe_ltp":       pe["ltp"],
            "pe_change_pct": 0.0,
            "pe_delta":     pe["delta"],
            "pe_gamma":     pe["gamma"],
            "pe_theta":     pe["theta"],
            "pe_vega":      pe["vega"],
        })

    pcr = round(total_pe_oi / total_ce_oi, 2) if total_ce_oi > 0 else 1.0

    # ATM data
    atm_row = next((r for r in chain_rows if r["strike"] == float(atm)), chain_rows[len(chain_rows)//2])

    # Max pain (simplified: strike where total option loss is minimised)
    def _max_pain(rows):
        min_pain = float("inf")
        mp = rows[0]["strike"]
        for test_row in rows:
            test = test_row["strike"]
            pain = sum((test - r["strike"]) * r["ce_oi"] for r in rows if test > r["strike"])
            pain += sum((r["strike"] - test) * r["pe_oi"] for r in rows if test < r["strike"])
            if pain < min_pain:
                min_pain = pain
                mp = test
        return mp

    max_pain = _max_pain(chain_rows)

    # Direction signal
    if pcr > 1.2:
        pcr_signal = "Bullish"
        direction  = "Buy CE"
        reasoning  = [f"PCR {pcr:.2f} > 1.2 — more PE writers (bullish bias)",
                      f"Theoretical IV: {hv*100:.1f}% (HV-based)"]
    elif pcr < 0.8:
        pcr_signal = "Bearish"
        direction  = "Buy PE"
        reasoning  = [f"PCR {pcr:.2f} < 0.8 — more CE writers (bearish bias)",
                      f"Theoretical IV: {hv*100:.1f}% (HV-based)"]
    else:
        pcr_signal = "Neutral"
        direction  = "Neutral — wait for clarity"
        reasoning  = [f"PCR {pcr:.2f} in neutral zone",
                      f"Theoretical IV: {hv*100:.1f}% (HV-based)"]

    from .fno import _market_status
    return {
        "spot":            spot,
        "selected_expiry": selected_expiry,
        "all_expiries":    expiries,
        "pcr":             pcr,
        "pcr_signal":      pcr_signal,
        "max_pain":        float(max_pain),
        "direction":       direction,
        "reasoning":       reasoning,
        "oi_bias":         "PE buildup" if total_pe_oi > total_ce_oi else "CE buildup",
        "total_ce_oi":     total_ce_oi,
        "total_pe_oi":     total_pe_oi,
        "atm_strike":      float(atm),
        "atm_ce_ltp":      atm_row["ce_ltp"],
        "atm_pe_ltp":      atm_row["pe_ltp"],
        "atm_ce_iv":       atm_row["ce_iv"],
        "atm_pe_iv":       atm_row["pe_iv"],
        "strikes":         chain_rows,
        "data_source":     "Black-Scholes (HV-based theoretical prices)",
        "is_synthetic":    True,
        "hist_volatility": round(hv * 100, 2),
        "market_status":   _market_status(),
        "last_data_date":  str(date.today()),
    }
