"""
F&O data from NSE India's unofficial JSON API.
Requires a live session/cookie — works by hitting the homepage first.
"""

import requests

# Indices supported by NSE option-chain-indices endpoint
FNO_INDICES = ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY", "SENSEX"]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://www.nseindia.com/",
    "Connection": "keep-alive",
}


def _nse_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(_HEADERS)
    session.get("https://www.nseindia.com", timeout=8)
    return session


def fetch_option_chain(symbol: str) -> dict:
    """
    Fetch raw option chain JSON from NSE.
    symbol: 'NIFTY', 'BANKNIFTY', or an equity symbol like 'RELIANCE'.
    """
    session = _nse_session()
    is_index = symbol.upper() in FNO_INDICES
    if is_index:
        url = f"https://www.nseindia.com/api/option-chain-indices?symbol={symbol.upper()}"
    else:
        url = f"https://www.nseindia.com/api/option-chain-equities?symbol={symbol.upper()}"
    resp = session.get(url, timeout=12)
    resp.raise_for_status()
    return resp.json()


def parse_option_chain(raw: dict, expiry: str | None = None) -> dict:
    """
    Parse NSE option chain JSON into a clean structure.
    If expiry is None, uses the nearest expiry date.
    Returns: spot, expiry, pcr, max_pain, strikes list, all_expiries.
    """
    records = raw.get("records", {})
    all_expiries = records.get("expiryDates", [])
    data = records.get("data", [])
    spot = float(records.get("underlyingValue", 0))

    selected_expiry = expiry if expiry in all_expiries else (all_expiries[0] if all_expiries else "")

    # Filter by expiry
    chain = [d for d in data if d.get("expiryDate") == selected_expiry]

    strikes = []
    total_ce_oi = 0
    total_pe_oi = 0

    for item in chain:
        strike = float(item.get("strikePrice", 0))
        ce = item.get("CE", {})
        pe = item.get("PE", {})

        ce_oi = int(ce.get("openInterest", 0))
        pe_oi = int(pe.get("openInterest", 0))
        total_ce_oi += ce_oi
        total_pe_oi += pe_oi

        strikes.append({
            "strike": strike,
            "ce_oi": ce_oi,
            "ce_coi": int(ce.get("changeinOpenInterest", 0)),
            "ce_volume": int(ce.get("totalTradedVolume", 0)),
            "ce_iv": float(ce.get("impliedVolatility", 0)),
            "ce_ltp": float(ce.get("lastPrice", 0)),
            "ce_change_pct": float(ce.get("pChange", 0)),
            "pe_oi": pe_oi,
            "pe_coi": int(pe.get("changeinOpenInterest", 0)),
            "pe_volume": int(pe.get("totalTradedVolume", 0)),
            "pe_iv": float(pe.get("impliedVolatility", 0)),
            "pe_ltp": float(pe.get("lastPrice", 0)),
            "pe_change_pct": float(pe.get("pChange", 0)),
        })

    pcr = round(total_pe_oi / total_ce_oi, 2) if total_ce_oi > 0 else 0.0
    max_pain = _calc_max_pain(strikes)

    if pcr > 1.2:
        pcr_signal = "Bullish"
    elif pcr < 0.8:
        pcr_signal = "Bearish"
    else:
        pcr_signal = "Neutral"

    # F&O signal
    if pcr_signal == "Bullish" and spot > max_pain:
        direction = "Buy CE"
    elif pcr_signal == "Bearish" and spot < max_pain:
        direction = "Buy PE"
    else:
        direction = "Neutral — wait for clarity"

    return {
        "spot": spot,
        "selected_expiry": selected_expiry,
        "all_expiries": all_expiries,
        "pcr": pcr,
        "pcr_signal": pcr_signal,
        "max_pain": max_pain,
        "direction": direction,
        "total_ce_oi": total_ce_oi,
        "total_pe_oi": total_pe_oi,
        "strikes": strikes,
    }


def _calc_max_pain(strikes: list[dict]) -> float:
    """Strike at which total loss for options writers is minimum."""
    if not strikes:
        return 0.0
    strike_prices = [s["strike"] for s in strikes]
    ce_oi = {s["strike"]: s["ce_oi"] for s in strikes}
    pe_oi = {s["strike"]: s["pe_oi"] for s in strikes}

    min_pain = float("inf")
    max_pain_strike = strike_prices[0]

    for test in strike_prices:
        pain = 0.0
        for sp, oi in ce_oi.items():
            if test > sp:
                pain += (test - sp) * oi
        for sp, oi in pe_oi.items():
            if test < sp:
                pain += (sp - test) * oi
        if pain < min_pain:
            min_pain = pain
            max_pain_strike = test

    return max_pain_strike
