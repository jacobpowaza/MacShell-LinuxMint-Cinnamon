"""Per-widget weather and IANA time zones; bounded, shared weather cache."""
import json, time, threading
from datetime import datetime
from zoneinfo import ZoneInfo, available_timezones
from urllib.parse import urlencode
from urllib.request import urlopen, Request

_cache = {}
_lock = threading.Lock()

def fetch(url):
    with urlopen(Request(url, headers={'User-Agent': 'MacShell-Cinnamon/1.0'}), timeout=12) as r:
        return json.load(r)

def request(arg):
    zone = str(arg.get('timezone') or '')
    now = datetime.now(ZoneInfo(zone)) if zone else datetime.now().astimezone()
    result = {'offset': now.utcoffset().total_seconds(), 'city': zone.split('/')[-1].replace('_', ' ') if zone else 'Local', 'error': ''}
    if arg.get('type') != 'weather':
        return result
    city = str(arg.get('city') or '').strip()
    if not city:
        return result
    unit = 'fahrenheit' if arg.get('unit') == 'F' else 'celsius'
    key = (city.casefold(), unit)
    with _lock:
        old = _cache.get(key)
    if old and time.monotonic()-old[0] < 900:
        return dict(result, weather=old[1])
    try:
        geo = fetch('https://geocoding-api.open-meteo.com/v1/search?' + urlencode({'name': city, 'count': 1, 'language': 'en', 'format': 'json'}))
        places = geo.get('results', [])
        if not places:
            raise ValueError('City not found. Try a nearby city.')
        place = places[0]
        data = fetch('https://api.open-meteo.com/v1/forecast?' + urlencode({'latitude': place['latitude'], 'longitude': place['longitude'], 'current': 'temperature_2m,is_day,weather_code', 'hourly': 'temperature_2m,weather_code,is_day', 'daily': 'weather_code,temperature_2m_max,temperature_2m_min', 'temperature_unit': unit, 'timezone': 'auto', 'forecast_days': 5}))
        data['city'] = place['name']
        with _lock:
            _cache[key] = (time.monotonic(), data)
            if len(_cache)>64:
                _cache.pop(next(iter(_cache)))
        result['weather'] = data
    except Exception as e:
        result['error'] = str(e) if isinstance(e, ValueError) else 'Weather unavailable. Check your connection and retry.'
        if old:
            result['weather'] = old[1]
    return result
