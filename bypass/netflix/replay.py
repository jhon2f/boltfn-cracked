 
from mitmproxy import http
AUTH = open(r"C:\Users\Vblak\OneDrive\Desktop\bfn\bypass\netflix\auth.json","rb").read()
DATA = open(r"C:\Users\Vblak\OneDrive\Desktop\bfn\bypass\netflix\data.json","rb").read()
def request(flow):
    if flow.request.host != "api.loschichos.lat": return
    if flow.request.path == "/auth":
        flow.response = http.Response.make(200, AUTH, {"Content-Type":"application/json"})
    elif flow.request.path == "/data":
        flow.response = http.Response.make(200, DATA, {"Content-Type":"application/json"})