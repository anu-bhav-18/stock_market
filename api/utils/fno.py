"""
F&O data from NSE India's unofficial JSON API.
Uses cookie-based session with retry logic to work around NSE's bot protection.
"""

import time
import requests

FNO_INDICES = ["NIFTY", "BANKNIFTY", "FINNIFTY", "MIDCPNIFTY"]

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Referer": "https://www.nseindia.com/",
    "X-Requested-With": "XMLHttpRequest",
    "Connection": "keep-alive",
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-origin",
}

_HOME_URLS = [
    "https://www.nseindia.com",
    "https://www.nseindia.com/option-chain",
]


def _nse_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(_HEADERS)
    for url in _HOME_URLS:
        try:
            session.get(url, timeout=10)
            time.sleep(0.5)
        except Exception:
            pass
    return session


def fetch_option_chain(symbol: str, retries: int = 3) -> dict:
    """
    Fetch raw option chain JSON from NSE.
    symbol: 'NIFTY', 'BANKNIFTY', or an equity symbol like 'RELIANCE'.
    """
    is_index = symbol.upper() in FNO_INDICES
    url = (
        f"https://www.nseindia.com/api/option-chain-indices?symbol={symbol.upper()}"
        if is_index
        else f"https://www.nseindia.com/api/option-chain-equities?symbol={symbol.upper()}"
    )

    last_err = None
    for attempt in range(retries):
        try:
            session = _nse_session()
            resp = session.get(url, timeout=15)
            resp.raise_for_status()
            data = resp.json()
            if data and "records" in data:
                return data
            raise ValueError("Empty response from NSE")
        except Exception as e:
            last_err = e
            if attempt < retries - 1:
                time.sleep(1.5 * (attempt + 1))

    raise RuntimeError(
        f"NSE API unavailable after {retries} attempts: {last_err}. "
        "NSE blocks cloud server IPs — try again during market hours or use a VPN."
    )


def parse_option_chain(raw: dict, expiry: str | None = None) -> dict:
    """
    Parse NSE option chain JSON into a clean structure.
    If expiry is None, uses the nearest expiry date.
    """
    records = raw.get("records", {})
    all_expiries = records.get("expiryDates", [])
    data = records.get("data", [])
    spot = float(records.get("underlyingValue", 0))

    selected_expiry = expiry if expiry in all_expiries else (all_expiries[0] if all_expiries else "")

    chain = [d for d in data if d.get("expiryDate") == selected_expiry]

    strikes = []
    total_ce_oi = 0
    total_pe_oi = 0
    total_ce_coi = 0
    total_pe_coi = 0

    for item in chain:
        strike = float(item.get("strikePrice", 0))
        ce = item.get("CE", {})
        pe = item.get("PE", {})

        ce_oi = int(ce.get("openInterest", 0))
        pe_oi = int(pe.get("openInterest", 0))
        ce_coi = int(ce.get("changeinOpenInterest", 0))
        pe_coi = int(pe.get("changeinOpenInterest", 0))
        total_ce_oi += ce_oi
        total_pe_oi += pe_oi
        total_ce_coi += ce_coi
        total_pe_coi += pe_coi

        strikes.append({
            "strike": strike,
            "ce_oi": ce_oi,
            "ce_coi": ce_coi,
            "ce_volume": int(ce.get("totalTradedVolume", 0)),
            "ce_iv": float(ce.get("impliedVolatility", 0)),
            "ce_ltp": float(ce.get("lastPrice", 0)),
            "ce_change_pct": float(ce.get("pChange", 0)),
            "pe_oi": pe_oi,
            "pe_coi": pe_coi,
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

    # OI change direction (smart money flow)
    oi_bias = "CE buildup" if total_ce_coi > total_pe_coi else "PE buildup"

    # Direction signal combining PCR + max pain + OI change
    if pcr_signal == "Bullish" and spot > max_pain:
        direction = "Buy CE"
        reasoning = [
            f"PCR {pcr:.2f} > 1.2 — more PE writers (bullish)",
            f"Spot ({spot:.0f}) above Max Pain ({max_pain:.0f}) — buyers in control",
            f"OI change: {oi_bias}",
        ]
    elif pcr_signal == "Bearish" and spot < max_pain:
        direction = "Buy PE"
        reasoning = [
            f"PCR {pcr:.2f} < 0.8 — more CE writers (bearish)",
            f"Spot ({spot:.0f}) below Max Pain ({max_pain:.0f}) — sellers in control",
            f"OI change: {oi_bias}",
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
            "No clear directional bias from OI data",
        ]

    # ATM strike
    atm = min((s["strike"] for s in strikes), key=lambda x: abs(x - spot), default=0)
    atm_data = next((s for s in strikes if s["strike"] == atm), {})

    return {
        "spot": spot,
        "selected_expiry": selected_expiry,
        "all_expiries": all_expiries,
        "pcr": pcr,
        "pcr_signal": pcr_signal,
        "max_pain": max_pain,
        "direction": direction,
        "reasoning": reasoning,
        "oi_bias": oi_bias,
        "total_ce_oi": total_ce_oi,
        "total_pe_oi": total_pe_oi,
        "atm_strike": atm,
        "atm_ce_ltp": atm_data.get("ce_ltp", 0),
        "atm_pe_ltp": atm_data.get("pe_ltp", 0),
        "atm_ce_iv": atm_data.get("ce_iv", 0),
        "atm_pe_iv": atm_data.get("pe_iv", 0),
        "strikes": strikes,
    }


def _calc_max_pain(strikes: list) -> float:
    """Strike at which total loss for options writers is minimum."""
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
