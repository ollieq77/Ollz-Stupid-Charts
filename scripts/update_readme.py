#!/usr/bin/env python3
"""Rebuilds the chart table in README.md between the CHARTS markers."""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if len(sys.argv) > 1:
    ROOT = Path(sys.argv[1]).resolve()
README = ROOT / "README.md"
START, END = "<!-- CHARTS:START -->", "<!-- CHARTS:END -->"

# ---- tweak these to taste -------------------------------------------------
# osu!-style strain model: every note adds strain, strain decays over time,
# we take the hardest moment in each section, then average the sections with
# weights that fade out gradually (so short spikes count, but dont dominate).
STRAIN_DECAY = 0.3      # strain left after 1 second (osu!mania uses ~0.3)
CHORD_EXTRA = 0.25      # strain for each extra note stacked in a chord
SECTION_MS = 400        # length of each section
WEIGHT_FADE = 0.96      # lower = hardest sections matter more, spikes hurt more
STRAIN_PER_STAR = 2.3   # higher = stingier stars (no upper limit). calibrated vs rough osu!mania 4K feel
# ---------------------------------------------------------------------------


def player_strumline(chart):
    """Player = type 1 (boyfriend). Falls back to the last strumline."""
    lines = chart.get("strumLines", [])
    for s in lines:
        if s.get("type") == 1:
            return s
    return lines[-1] if lines else {"notes": []}


def analyse(chart_path):
    chart = json.loads(chart_path.read_text(encoding="utf-8"))
    times = sorted(n["time"] for n in player_strumline(chart)["notes"])
    if len(times) < 2:
        return 0, 0.0, 0.0, 0.0
    dur = max((times[-1] - times[0]) / 1000, 1)
    avg = len(times) / dur
    # peak NPS (info only, busiest 1s window)
    peak, j = 0, 0
    for i, t in enumerate(times):
        while times[j] < t - 1000:
            j += 1
        peak = max(peak, i - j + 1)

    # group chords: [(time, note_count)]
    groups = []
    for t in times:
        if groups and abs(groups[-1][0] - t) < 1:
            groups[-1][1] += 1
        else:
            groups.append([t, 1])

    # strain with decay, highest value per section
    sections, strain, prev_t, sec_end, sec_max = [], 0.0, groups[0][0], groups[0][0] + SECTION_MS, 0.0
    for t, count in groups:
        while t >= sec_end:            # close finished sections (decay through gaps)
            sections.append(sec_max)
            strain *= STRAIN_DECAY ** ((sec_end - prev_t) / 1000)
            prev_t = sec_end
            sec_max = strain
            sec_end += SECTION_MS
        strain = strain * STRAIN_DECAY ** ((t - prev_t) / 1000) + 1 + CHORD_EXTRA * (count - 1)
        prev_t = t
        sec_max = max(sec_max, strain)
    sections.append(sec_max)

    # weighted average, hardest section first, weights fade gradually
    sections.sort(reverse=True)
    weights = [WEIGHT_FADE ** i for i in range(len(sections))]
    difficulty = sum(w * v for w, v in zip(weights, sections)) / sum(weights)
    return len(times), avg, peak, difficulty / STRAIN_PER_STAR


def mmss(sec):
    return f"{int(sec // 60)}:{int(sec % 60):02d}"


def build_cards():
    cards = []
    for song in sorted((ROOT / "songs").iterdir()):
        if not song.is_dir():
            continue
        meta_p = song / "meta.json"
        meta = json.loads(meta_p.read_text(encoding="utf-8")) if meta_p.exists() else {}
        name = meta.get("displayName") or meta.get("name") or song.name
        bpm = meta.get("bpm", "?")
        rows, longest = [], 0
        for chart in sorted((song / "charts").glob("*.json")):
            data = json.loads(chart.read_text(encoding="utf-8"))
            notes, avg, peak, stars = analyse(chart)
            ps = player_strumline(data)["notes"]
            longest = max(longest, max((n["time"] for n in ps), default=0) / 1000)
            rows.append(f"| {chart.stem} | {stars:.2f} ★ | {notes} | {avg:.1f} / {peak} |")
        if not rows:
            continue
        cards.append(
            f"### {name}\n"
            f"**{bpm} BPM** · **{mmss(longest)}**\n\n"
            "| Difficulty | Stars | Notes | NPS (avg / peak) |\n"
            "|---|---|---|---|\n" + "\n".join(rows)
        )
    return "\n\n".join(cards) if cards else "_no charts yet_"


def main():
    text = README.read_text(encoding="utf-8")
    if START not in text or END not in text:
        sys.exit(f"README is missing {START} / {END} markers")
    block = f"{START}\n{build_cards()}\n{END}"
    new = re.sub(re.escape(START) + r".*?" + re.escape(END), lambda _: block, text, flags=re.S)
    if new != text:
        README.write_text(new, encoding="utf-8")
        print("README updated")
    else:
        print("README already up to date")


if __name__ == "__main__":
    main()