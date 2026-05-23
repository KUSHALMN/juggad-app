import httpx
from .logging import log
from .firestore import db
from .geo import encode as get_geohash
from datetime import datetime, timezone


async def reverse_geocode(lat: float, lng: float) -> str:
    """
    Nominatim reverse geocoding with Fix 5: Firestore Caching.
    Prevents being blocked by Nominatim by caching address at geohash-6 level.
    """
    g_hash = get_geohash(lat, lng, precision=6)
    
    # 1. Check Firestore cache first
    try:
        cache_ref = db.collection("geocache").document(g_hash)
        cache_doc = cache_ref.get()
        if cache_doc.exists:
            address = cache_doc.to_dict().get("address")
            log("shared", "geocoding", "cache_hit", lat=lat, lng=lng, geohash=g_hash, address=address)
            return address
    except Exception as e:
        log("shared", "geocoding", "cache_check_failed", severity="WARNING", error=str(e))

    # 2. Call Nominatim if not cached
    url = "https://nominatim.openstreetmap.org/reverse"
    params = {
        "lat": lat,
        "lon": lng,
        "format": "json"
    }
    headers = {
        "User-Agent": "Jugaad/1.0 (jugaad@mysuru.in)"
    }
    
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(url, params=params, headers=headers)
            if response.status_code == 200:
                data = response.json()
                address = data.get("display_name", f"{lat},{lng}")
                
                # 3. Store result in cache (Fire and forget)
                cache_ref.set({
                    "address": address,
                    "geohash": g_hash,
                    "updated_at": datetime.now(timezone.utc).timestamp()
                })
                
                log("shared", "geocoding", "reverse_geocode_success", lat=lat, lng=lng, address=address)
                return address
            else:
                log("shared", "geocoding", "nominatim_api_error", severity="WARNING", status=response.status_code)
    except Exception as e:
        log("shared", "geocoding", "reverse_geocode_timeout_or_error", severity="WARNING", error=str(e))
    
    # 4. Fallback: Never fail enrollment
    return f"{lat},{lng}"
