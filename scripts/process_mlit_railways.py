#!/usr/bin/env python3
"""
Download and process MLIT (国土交通省) National Land Numerical Information
railway data (N02 - 鉄道データ) into compact GeoJSON for the Travel app.

Source: https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-v3_1.html

The N02 dataset contains two GeoJSON files:
1. RailroadSection — railway track geometries (LineString)
   Properties:
   - N02_001: 事業者種別コード (two-digit code, 11=JR, 12=third-sector, etc.)
   - N02_002: 事業者種別 (operator type: 1=新幹線, 2=JR在来線, 3=公営, 4=民営, 5=三セク)
   - N02_003: 路線名 (line name, e.g. "東海道新幹線")
   - N02_004: 運営会社 (operator company name)

2. Station — station point geometries (Point)
   Properties:
   - N02_001-N02_004: same as above
   - N02_005: 駅名 (station name)

Output: japan_railways.geojson — compact GeoJSON with Shinkansen + JR lines
"""

import json
import os
import sys
import zipfile
import tempfile
import math
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import URLError

# MLIT N02 data URL (2022 edition — latest available)
MLIT_URL = "https://nlftp.mlit.go.jp/ksj/gml/data/N02/N02-22/N02-22_GML.zip"
MLIT_URL_FALLBACK = "https://nlftp.mlit.go.jp/ksj/gml/data/N02/N02-21/N02-21_GML.zip"

# Douglas-Peucker simplification tolerance (degrees)
# 0.0005 ≈ 55m — good balance of accuracy and size
SIMPLIFY_TOLERANCE = 0.0005


def download_and_extract(url: str, dest_dir: str) -> tuple[str | None, str | None]:
    """Download MLIT zip file and return paths to (sections_geojson, stations_geojson)."""
    zip_path = os.path.join(dest_dir, "n02.zip")
    print(f"Downloading: {url}")

    try:
        req = Request(url, headers={"User-Agent": "Mozilla/5.0 (TravelApp research)"})
        with urlopen(req, timeout=120) as response, open(zip_path, "wb") as f:
            total = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            while chunk := response.read(8192):
                f.write(chunk)
                downloaded += len(chunk)
                if total > 0:
                    print(f"\r  {downloaded * 100 // total}% ({downloaded // 1024}KB)", end="", flush=True)
            print()
    except (URLError, Exception) as e:
        print(f"  Failed: {e}")
        return None, None

    print(f"  Size: {os.path.getsize(zip_path) // 1024}KB")

    sections_path = None
    stations_path = None

    with zipfile.ZipFile(zip_path) as zf:
        for name in zf.namelist():
            # Prefer UTF-8 versions
            if "UTF-8" in name and name.endswith(".geojson"):
                zf.extract(name, dest_dir)
                full_path = os.path.join(dest_dir, name)
                if "RailroadSection" in name:
                    sections_path = full_path
                    print(f"  Sections: {name} ({os.path.getsize(full_path) // 1024}KB)")
                elif "Station" in name:
                    stations_path = full_path
                    print(f"  Stations: {name} ({os.path.getsize(full_path) // 1024}KB)")

    return sections_path, stations_path


def perpendicular_distance(point, line_start, line_end):
    x0, y0 = point
    x1, y1 = line_start
    x2, y2 = line_end
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x0 - x1, y0 - y1)
    t = max(0, min(1, ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x0 - (x1 + t * dx), y0 - (y1 + t * dy))


def douglas_peucker(coords, tolerance):
    if len(coords) <= 2:
        return coords
    max_dist = 0
    max_idx = 0
    for i in range(1, len(coords) - 1):
        d = perpendicular_distance(coords[i], coords[0], coords[-1])
        if d > max_dist:
            max_dist = d
            max_idx = i
    if max_dist > tolerance:
        left = douglas_peucker(coords[:max_idx + 1], tolerance)
        right = douglas_peucker(coords[max_idx:], tolerance)
        return left[:-1] + right
    return [coords[0], coords[-1]]


def simplify_geometry(geom, tolerance):
    def simplify_line(coords):
        simplified = douglas_peucker(coords, tolerance)
        return [[round(c[0], 5), round(c[1], 5)] for c in simplified]

    if geom["type"] == "LineString":
        return {"type": "LineString", "coordinates": simplify_line(geom["coordinates"])}
    elif geom["type"] == "MultiLineString":
        lines = [simplify_line(l) for l in geom["coordinates"] if len(l) >= 2]
        lines = [l for l in lines if len(l) >= 2]
        return {"type": "MultiLineString", "coordinates": lines}
    return geom


def count_points(geom):
    if geom["type"] == "LineString":
        return len(geom["coordinates"])
    elif geom["type"] == "MultiLineString":
        return sum(len(l) for l in geom["coordinates"])
    return 0


def process(sections_path: str, stations_path: str, output_dir: str):
    """Process MLIT GeoJSON into compact app-ready format."""
    print("\n═══ Processing Railway Sections ═══")
    with open(sections_path, "r", encoding="utf-8") as f:
        sections_data = json.load(f)

    print(f"Total section features: {len(sections_data['features'])}")

    # Group by type: N02_002 = "1" is Shinkansen, "2" is JR conventional
    shinkansen_sections = []
    jr_sections = []

    for feat in sections_data["features"]:
        props = feat.get("properties", {})
        geom = feat.get("geometry", {})
        if geom.get("type") not in ("LineString", "MultiLineString"):
            continue

        operator_type = str(props.get("N02_002", ""))
        line_name = props.get("N02_003", "")

        if operator_type == "1" or "新幹線" in line_name:
            shinkansen_sections.append(feat)
        elif operator_type == "2":
            jr_sections.append(feat)

    print(f"  Shinkansen: {len(shinkansen_sections)} segments")
    print(f"  JR conventional: {len(jr_sections)} segments")

    # Print Shinkansen line summary
    shinkansen_lines = {}
    for f in shinkansen_sections:
        name = f["properties"]["N02_003"]
        shinkansen_lines[name] = shinkansen_lines.get(name, 0) + 1
    for name, count in sorted(shinkansen_lines.items()):
        print(f"    🚅 {name}: {count} segments")

    # Process stations
    print("\n═══ Processing Stations ═══")
    with open(stations_path, "r", encoding="utf-8") as f:
        stations_data = json.load(f)

    print(f"Total station features: {len(stations_data['features'])}")

    shinkansen_stations = []
    jr_stations = []
    for feat in stations_data["features"]:
        props = feat.get("properties", {})
        geom = feat.get("geometry", {})
        if geom.get("type") != "Point":
            continue

        operator_type = str(props.get("N02_002", ""))
        line_name = props.get("N02_003", "")

        if operator_type == "1" or "新幹線" in line_name:
            shinkansen_stations.append(feat)
        elif operator_type == "2":
            jr_stations.append(feat)

    print(f"  Shinkansen stations: {len(shinkansen_stations)}")
    print(f"  JR stations: {len(jr_stations)}")

    # === Build Shinkansen-only output ===
    print("\n═══ Building Shinkansen GeoJSON ═══")
    shinkansen_features = []
    pts_before = pts_after = 0

    for feat in shinkansen_sections:
        geom = feat["geometry"]
        props = feat["properties"]
        pts_before += count_points(geom)
        simplified = simplify_geometry(geom, SIMPLIFY_TOLERANCE)
        pts_after += count_points(simplified)

        shinkansen_features.append({
            "type": "Feature",
            "properties": {
                "n": props.get("N02_003", ""),  # line name
                "o": props.get("N02_004", ""),  # operator company
                "t": "s",  # type: shinkansen
            },
            "geometry": simplified,
        })

    for feat in shinkansen_stations:
        props = feat["properties"]
        shinkansen_features.append({
            "type": "Feature",
            "properties": {
                "n": props.get("N02_005", props.get("N02_004", "")),  # station name
                "l": props.get("N02_003", ""),  # line name
                "t": "st",  # type: station
            },
            "geometry": {
                "type": "Point",
                "coordinates": [
                    round(feat["geometry"]["coordinates"][0], 5),
                    round(feat["geometry"]["coordinates"][1], 5),
                ],
            },
        })

    shinkansen_output = {
        "type": "FeatureCollection",
        "features": shinkansen_features,
    }

    shinkansen_path = os.path.join(output_dir, "japan_shinkansen.geojson")
    with open(shinkansen_path, "w", encoding="utf-8") as f:
        json.dump(shinkansen_output, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(shinkansen_path) // 1024
    print(f"  Points: {pts_before} → {pts_after} ({pts_after * 100 // max(pts_before, 1)}% of original)")
    print(f"  Features: {len(shinkansen_features)} (tracks + stations)")
    print(f"  File: {shinkansen_path} ({size_kb}KB)")

    # === Build full JR output (Shinkansen + conventional) ===
    print("\n═══ Building Full JR GeoJSON ═══")
    all_features = list(shinkansen_features)  # copy
    jr_pts_before = jr_pts_after = 0

    for feat in jr_sections:
        geom = feat["geometry"]
        props = feat["properties"]
        jr_pts_before += count_points(geom)
        simplified = simplify_geometry(geom, SIMPLIFY_TOLERANCE)
        jr_pts_after += count_points(simplified)

        all_features.append({
            "type": "Feature",
            "properties": {
                "n": props.get("N02_003", ""),
                "o": props.get("N02_004", ""),
                "t": "jr",
            },
            "geometry": simplified,
        })

    for feat in jr_stations:
        props = feat["properties"]
        all_features.append({
            "type": "Feature",
            "properties": {
                "n": props.get("N02_005", props.get("N02_004", "")),
                "l": props.get("N02_003", ""),
                "t": "st",
            },
            "geometry": {
                "type": "Point",
                "coordinates": [
                    round(feat["geometry"]["coordinates"][0], 5),
                    round(feat["geometry"]["coordinates"][1], 5),
                ],
            },
        })

    full_output = {
        "type": "FeatureCollection",
        "features": all_features,
    }

    full_path = os.path.join(output_dir, "japan_railways.geojson")
    with open(full_path, "w", encoding="utf-8") as f:
        json.dump(full_output, f, ensure_ascii=False, separators=(",", ":"))

    full_size = os.path.getsize(full_path) // 1024
    total_pts_before = pts_before + jr_pts_before
    total_pts_after = pts_after + jr_pts_after
    print(f"  JR points: {jr_pts_before} → {jr_pts_after}")
    print(f"  Total points: {total_pts_before} → {total_pts_after} ({total_pts_after * 100 // max(total_pts_before, 1)}%)")
    print(f"  Features: {len(all_features)}")
    print(f"  File: {full_path} ({full_size}KB)")

    return shinkansen_path, full_path


def main():
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent
    output_dir = project_dir / "Travel app" / "Resources"
    output_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmpdir:
        sections_path, stations_path = download_and_extract(MLIT_URL, tmpdir)

        if not sections_path:
            print("\nTrying fallback...")
            sections_path, stations_path = download_and_extract(MLIT_URL_FALLBACK, tmpdir)

        if not sections_path or not stations_path:
            print("\n❌ Failed to download MLIT data.")
            sys.exit(1)

        shinkansen_path, full_path = process(sections_path, stations_path, str(output_dir))

    print(f"\n{'=' * 60}")
    print(f"✅ Done!")
    print(f"  Shinkansen only: {shinkansen_path}")
    print(f"  Full JR:         {full_path}")
    print(f"\nAdd the Shinkansen file to Xcode project bundle.")
    print(f"The app will use it via JapanRailwayGeoService.")


if __name__ == "__main__":
    main()
