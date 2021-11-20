import json
from http.server import HTTPServer, BaseHTTPRequestHandler
"""
/login for Log in
/route for getting nearest car
/confirm for job confirmation
/pickup for successful pick up
/dropoff for successfu drop of
/cancel for job cancellation
"""


PORT = 8080

tasklist = ['t1', 't2', 't3']


class requestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('content-type', 'text/html')
        self.end_headers()

        output = ''
        output+= '<html><body>'
        output+= '<h1> Task List</h1>'
        for task in tasklist:
            output+= task
            output += '</br>'
        output+= '</body></html>'
        print(output)
        self.wfile.write(output.encode())



def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()

def dictionaryFromJson(data):
    data_dict = json.load(data)
    return data_dict