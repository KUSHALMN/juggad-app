# shared/geo.py
import os
import pygeohash as geohash
from math import radians, sin, cos, sqrt, atan2

VALID_SKILLS = [
    "laptop_repair", "phone_repair", "electrician",
    "plumber", "carpenter", "ac_service", "construction_worker",
]
VALID_AREAS = [
    "vijayanagar_mysuru", "kuvempunagar_mysuru", "jayalakshmipuram_mysuru",
    "saraswathipuram_mysuru", "gokulam_mysuru", "hebbal_mysuru",
    "bannimantap_mysuru", "nazarbad_mysuru", "lakshmipuram_mysuru",
    "jayanagar_mysuru", "ramakrishnanagar_mysuru", "siddarthanagar_mysuru",
    "yadavagiri_mysuru", "hootagalli_mysuru", "bogadi_mysuru",
    "alanahalli_mysuru", "chamundi_hill_mysuru", "metagalli_mysuru",
    "kc_layout_mysuru", "udayagiri_mysuru", "srirampura_mysuru",
    "niveditha_nagar_mysuru", "dattagalli_mysuru", "jp_nagar_mysuru",
    "kesare_mysuru", "belavadi_mysuru", "other_mysuru"
]

# Read from env — never hardcode coordinates in source (FIX 5)
PILOT_LAT_CENTER = float(os.getenv("PILOT_LAT_CENTER", "12.3052"))
PILOT_LNG_CENTER = float(os.getenv("PILOT_LNG_CENTER", "76.6552"))


def encode(lat: float, lng: float, precision: int = 6) -> str:
    """Encode lat/lng to geohash string."""
    return geohash.encode(lat, lng, precision=precision)


def decode(gh: str) -> tuple[float, float]:
    """Decode geohash to (lat, lng) tuple."""
    return geohash.decode(gh)


def neighbors_for_radius(lat: float, lng: float, precision: int = 5) -> list[str]:
    """
    Get center + 8 neighbor geohash prefixes for proximity queries.
    Used by matching service to find workers in surrounding cells.
    pygeohash lacks neighbors(), so we compute them from lat/lng offsets.
    """
    center = geohash.encode(lat, lng, precision=precision)
    # Decode center to get lat/lng, then offset to get 8 neighbors
    clat, clng = geohash.decode(center)
    # Approximate cell size at each precision level (degrees)
    lat_err = {1: 23, 2: 2.8, 3: 0.7, 4: 0.087, 5: 0.022, 6: 0.0027}
    lng_err = {1: 23, 2: 5.6, 3: 0.7, 4: 0.18, 5: 0.022, 6: 0.0055}
    dlat = lat_err.get(precision, 0.022) * 2
    dlng = lng_err.get(precision, 0.022) * 2

    offsets = [
        (dlat, 0), (-dlat, 0), (0, dlng), (0, -dlng),        # N S E W
        (dlat, dlng), (dlat, -dlng), (-dlat, dlng), (-dlat, -dlng),  # corners
    ]
    result = [center]
    for olat, olng in offsets:
        result.append(geohash.encode(clat + olat, clng + olng, precision=precision))
    # Deduplicate (edge cases at poles/antimeridian)
    return list(dict.fromkeys(result))


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Haversine formula — returns distance in km."""
    R = 6371
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
