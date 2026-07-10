"""
Candlestick pattern detection on daily OHLC data.
Checks the last 1-3 candles for common reversal and continuation patterns.
"""

import pandas as pd


def detect_patterns(df: pd.DataFrame) -> list:
    """
    Detect candlestick patterns in the most recent candles.
    Returns a list of dicts: {name, type ('bullish'|'bearish'|'neutral'), description}.
    """
    patterns = []
    if df is None or len(df) < 3:
        return patterns

    o = df["Open"].values.astype(float)
    h = df["High"].values.astype(float)
    l = df["Low"].values.astype(float)
    c = df["Close"].values.astype(float)
    n = len(df)
    i = n - 1  # last candle index

    body = abs(c[i] - o[i])
    rng = h[i] - l[i]
    upper_wick = h[i] - max(c[i], o[i])
    lower_wick = min(c[i], o[i]) - l[i]
    is_bull = c[i] > o[i]

    # ── Single candle patterns ──────────────────────────────────────────────────

    if rng > 0:
        body_ratio = body / rng

        # Doji — body < 10% of range
        if body_ratio < 0.10:
            patterns.append({
                "name": "Doji",
                "type": "neutral",
                "description": "Market indecision — watch for direction confirmation next candle",
            })

        # Hammer — small body at top, lower wick 2× body, tiny upper wick
        elif lower_wick >= 2 * body and upper_wick <= 0.3 * body and is_bull:
            patterns.append({
                "name": "Hammer",
                "type": "bullish",
                "description": "Bullish reversal signal — buyers defended lower levels",
            })

        # Inverted Hammer (bullish variant after downtrend)
        elif upper_wick >= 2 * body and lower_wick <= 0.3 * body and is_bull:
            patterns.append({
                "name": "Inverted Hammer",
                "type": "bullish",
                "description": "Potential bullish reversal — watch for follow-through",
            })

        # Shooting Star — small body at bottom, upper wick 2× body
        elif upper_wick >= 2 * body and lower_wick <= 0.3 * body and not is_bull:
            patterns.append({
                "name": "Shooting Star",
                "type": "bearish",
                "description": "Bearish reversal signal — sellers rejected higher prices",
            })

        # Hanging Man (bearish variant after uptrend)
        elif lower_wick >= 2 * body and upper_wick <= 0.3 * body and not is_bull:
            patterns.append({
                "name": "Hanging Man",
                "type": "bearish",
                "description": "Bearish warning at resistance — confirm with next candle",
            })

        # Strong bullish / bearish marubozu
        elif body_ratio > 0.85 and is_bull:
            patterns.append({
                "name": "Bullish Marubozu",
                "type": "bullish",
                "description": "Strong buying pressure — bulls in full control",
            })
        elif body_ratio > 0.85 and not is_bull:
            patterns.append({
                "name": "Bearish Marubozu",
                "type": "bearish",
                "description": "Strong selling pressure — bears in full control",
            })

    # ── Two candle patterns ─────────────────────────────────────────────────────

    if i >= 1:
        pb = abs(c[i - 1] - o[i - 1])  # prev body
        prev_bull = c[i - 1] > o[i - 1]

        # Bullish Engulfing
        if not prev_bull and is_bull and o[i] <= c[i - 1] and c[i] >= o[i - 1] and pb > 0:
            patterns.append({
                "name": "Bullish Engulfing",
                "type": "bullish",
                "description": "Strong bullish reversal — current candle fully engulfs previous bearish candle",
            })

        # Bearish Engulfing
        elif prev_bull and not is_bull and o[i] >= c[i - 1] and c[i] <= o[i - 1] and pb > 0:
            patterns.append({
                "name": "Bearish Engulfing",
                "type": "bearish",
                "description": "Strong bearish reversal — current candle fully engulfs previous bullish candle",
            })

        # Piercing Line (bullish — close above midpoint of previous red candle)
        elif not prev_bull and is_bull and o[i] < l[i - 1] and c[i] > (o[i - 1] + c[i - 1]) / 2:
            patterns.append({
                "name": "Piercing Line",
                "type": "bullish",
                "description": "Bullish reversal — opens below previous low, closes above midpoint",
            })

        # Dark Cloud Cover (bearish)
        elif prev_bull and not is_bull and o[i] > h[i - 1] and c[i] < (o[i - 1] + c[i - 1]) / 2:
            patterns.append({
                "name": "Dark Cloud Cover",
                "type": "bearish",
                "description": "Bearish reversal — opens above previous high, closes below midpoint",
            })

    # ── Three candle patterns ───────────────────────────────────────────────────

    if i >= 2:
        star_rng = h[i - 1] - l[i - 1]
        star_body = abs(c[i - 1] - o[i - 1])
        first_bull = c[i - 2] > o[i - 2]

        # Morning Star
        if (not first_bull and
                star_rng > 0 and star_body / star_rng < 0.35 and
                is_bull and
                c[i] > (o[i - 2] + c[i - 2]) / 2):
            patterns.append({
                "name": "Morning Star",
                "type": "bullish",
                "description": "3-candle bullish reversal — strong signal at support",
            })

        # Evening Star
        elif (first_bull and
              star_rng > 0 and star_body / star_rng < 0.35 and
              not is_bull and
              c[i] < (o[i - 2] + c[i - 2]) / 2):
            patterns.append({
                "name": "Evening Star",
                "type": "bearish",
                "description": "3-candle bearish reversal — strong signal at resistance",
            })

        # Three White Soldiers (bullish continuation)
        if (c[i] > o[i] and c[i - 1] > o[i - 1] and c[i - 2] > o[i - 2] and
                c[i] > c[i - 1] > c[i - 2] and
                o[i] > o[i - 1] > o[i - 2]):
            patterns.append({
                "name": "Three White Soldiers",
                "type": "bullish",
                "description": "Three consecutive strong bullish candles — strong uptrend",
            })

        # Three Black Crows (bearish continuation)
        if (c[i] < o[i] and c[i - 1] < o[i - 1] and c[i - 2] < o[i - 2] and
                c[i] < c[i - 1] < c[i - 2] and
                o[i] < o[i - 1] < o[i - 2]):
            patterns.append({
                "name": "Three Black Crows",
                "type": "bearish",
                "description": "Three consecutive bearish candles — strong downtrend",
            })

    return patterns
