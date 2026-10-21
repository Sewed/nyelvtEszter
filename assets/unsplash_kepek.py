import json, os, re, sys, time
import urllib.parse, urllib.request, urllib.error

KEY = os.environ.get("UNSPLASH_ACCESS_KEY")
APP = os.environ.get("APP_NAME")
if not KEY or not APP:
    sys.exit("Állítsd be: UNSPLASH_ACCESS_KEY és APP_NAME (az app neve, kisbetűvel, szóköz nélkül, pl. nemet_kartyak)")

BE = sys.argv[1] if len(sys.argv) > 1 else "szavak.json"
KI = sys.argv[2] if len(sys.argv) > 2 else "szavak_kepekkel.json"
UTM = f"?utm_source={urllib.parse.quote(APP)}&utm_medium=referral"
HEAD = {"Authorization": f"Client-ID {KEY}", "Accept-Version": "v1"}
NEVELO = re.compile(r"^(der|die|das|sich)\s+", re.I)

class Limit(Exception):
    pass

def get(url):
    req = urllib.request.Request(url, headers=HEAD)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 403 and e.headers.get("X-Ratelimit-Remaining") == "0":
            raise Limit()
        if e.code == 401:
            sys.exit("Érvénytelen Access Key (401).")
        raise

def keres(szo):
    q = NEVELO.sub("", szo).strip()
    url = "https://api.unsplash.com/search/photos?" + urllib.parse.urlencode(
        {"query": q, "per_page": 1, "lang": "de", "content_filter": "high",
         "orientation": "landscape"})
    d = get(url)
    if not d.get("results"):
        return None
    p = d["results"][0]
    try:
        get(p["links"]["download_location"])
    except Exception:
        pass
    return {
        "kepUrl": p["urls"]["small"],
        "kepSzerzo": p["user"]["name"],
        "kepSzerzoUrl": p["user"]["links"]["html"] + UTM,
    }

def ment(szavak):
    with open(KI, "w", encoding="utf-8") as f:
        json.dump(szavak, f, ensure_ascii=False, indent=2)

forras = KI if os.path.exists(KI) else BE
with open(forras, encoding="utf-8") as f:
    szavak = json.load(f)

n = 0
for i, w in enumerate(szavak, 1):
    if w.get("kepUrl"):
        continue
    while True:
        try:
            r = keres(w["nemet"])
            break
        except Limit:
            print("Óránkénti limit elérve, 10 perc várakozás...")
            ment(szavak)
            time.sleep(600)
        except Exception as e:
            print(f"Hiba: {w['nemet']} - {e}")
            r = None
            break
    if r:
        w.update(r)
    n += 1
    print(f"[{i}/{len(szavak)}] {w['nemet']} -> {'OK' if r else 'nincs találat'}")
    if n % 10 == 0:
        ment(szavak)
    time.sleep(1)

ment(szavak)
ures = sum(1 for w in szavak if not w.get("kepUrl"))
print(f"Kész. Kép nélkül: {ures} szó. Kimenet: {KI}")
print("Az appban minden képnél jelenítsd meg: Fotó: <kepSzerzo> (link: kepSzerzoUrl) / Unsplash (link: https://unsplash.com/" + UTM + ")")
