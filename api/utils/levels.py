"""
Support / Resistance levels and Pivot Points from daily OHLC data.
"""

import pandas as pd


def pivot_points(df: pd.DataFrame) -> dict:
    """
    Standard pivot points from previous session's OHLC.
    Returns PP, R1, R2, R3, S1, S2, S3 and current price.
    """
    if len(df) < 2:
        return {}

    prev = df.iloc[-2]
    H = float(prev["High"])
    L = float(prev["Low"])
    C = float(prev["Close"])
    curr = float(df["Close"].iloc[-1])

    PP = (H + L + C) / 3
    R1 = 2 * PP - L
    R2 = PP + (H - L)
    R3 = H + 2 * (PP - L)
    S1 = 2 * PP - H
    S2 = PP - (H - L)
    S3 = L - 2 * (H - PP)

    def r(v):
        return round(v, 2)

    # Nearest level context
    levels_sorted = sorted([
        ("R3", r(R3)), ("R2", r(R2)), ("R1", r(R1)),
        ("PP", r(PP)),
        ("S1", r(S1)), ("S2", r(S2)), ("S3", r(S3)),
    ], key=lambda x: x[1])

    nearest_above = next(
        ((n, v) for n, v in reversed(levels_sorted) if v > curr), None
    )
    nearest_below = next(
        ((n, v) for n, v in levels_sorted if v < curr), None
    )

    context = ""
    if nearest_above and nearest_below:
        dist_above = (nearest_above[1] - curr) / curr * 100
        dist_below = (curr - nearest_below[1]) / curr * 100
        context = (
            f"Next resistance {nearest_above[0]} at {nearest_above[1]:.1f} "
            f"(+{dist_above:.1f}%), "
            f"support {nearest_below[0]} at {nearest_below[1]:.1f} "
            f"(-{dist_below:.1f}%)"
        )

    return {
        "current": r(curr),
        "PP": r(PP),
        "R1": r(R1), "R2": r(R2), "R3": r(R3),
        "S1": r(S1), "S2": r(S2), "S3": r(S3),
        "context": context,
    }


def support_resistance(df: pd.DataFrame, lookback: int = 90) -> dict:
    """
    Find swing-high resistance and swing-low support levels
    from recent price history using local extrema detection.
    """
    if len(df) < 10:
        return {"resistance": [], "support": []}

    recent = df.tail(lookback)
    closes = recent["Close"].values
    n = len(closes)

    highs, lows = [], []
    window = 3
    for i in range(window, n - window):
        if all(closes[i] >= closes[i - j] for j in range(1, window + 1)) and \
           all(closes[i] >= closes[i + j] for j in range(1, window + 1)):
            highs.append(float(closes[i]))
        if all(closes[i] <= closes[i - j] for j in range(1, window + 1)) and \
           all(closes[i] <= closes[i + j] for j in range(1, window + 1)):
            lows.append(float(closes[i]))

    def cluster(vals, threshold=0.008):
        if not vals:
            return []
        vals = sorted(vals)
        groups = [[vals[0]]]
        for v in vals[1:]:
            if (v - groups[-1][-1]) / groups[-1][-1] < threshold:
                groups[-1].append(v)
            else:
                groups.append([v])
        return [round(sum(g) / len(g), 2) for g in groups]

    curr = float(df["Close"].iloc[-1])
    resistance = [v for v in cluster(highs) if v > curr][-4:]
    support = [v for v in cluster(lows) if v < curr][:4]

    return {"resistance": resistance, "support": support}
