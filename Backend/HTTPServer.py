from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8000

tasklist = ["t1", "t2", "t3"]


class requestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("content", "text/html")
        self.end_headers()
        self.wfile.write(self.path[1:].encode())

        output = ""


def main():
    server = HTTPServer(("", PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()
