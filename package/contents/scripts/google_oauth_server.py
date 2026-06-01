#!/usr/bin/env python3
import http.server
import sys
import webbrowser
from urllib.parse import urlencode, urlparse, parse_qs

PORT = 8400

def main():
    if len(sys.argv) < 3:
        print("Usage: google_oauth_server.py <client_id> <scope>", file=sys.stderr)
        sys.exit(1)

    client_id = sys.argv[1]
    scope = sys.argv[2]
    redirect_uri = f"http://127.0.0.1:{PORT}/"

    auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + urlencode({
        "client_id": client_id,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": scope,
        "access_type": "offline",
        "prompt": "consent",
    })

    auth_code = None

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            nonlocal auth_code
            params = parse_qs(urlparse(self.path).query)
            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(b"<html><body><h2>Success!</h2>"
                                 b"<p>You can close this tab.</p></body></html>")
            else:
                self.send_response(400)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                self.wfile.write(b"<html><body><h2>Error</h2>"
                                 b"<p>No authorization code received.</p></body></html>")

        def log_message(self, format, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    webbrowser.open(auth_url)

    while auth_code is None:
        server.handle_request()

    server.server_close()
    print(auth_code)

if __name__ == "__main__":
    main()
