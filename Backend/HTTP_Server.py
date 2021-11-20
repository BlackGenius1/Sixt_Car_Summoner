import json
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler

"""
    /login for Log in
    /route for getting nearest car
    /confirm for job confirmation
    /pickup for successful pick up
    /dropoff for successfu drop of
    /cancel for job cancellation
"""

PORT = 8000

tasklist = ['t1', 't2', 't3']


class requestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('content-type', 'text/html')
        self.end_headers()
        #self.wfile.write(self.path[1:].encode())

        output = ''
        output+= '<html><body>'
        output+= '<h1> Task List</h1>'
        for task in tasklist:
            output+= task
            output += '</br>'
        output+= '</body></html>'
        print(output)
        self.wfile.write(output.encode())

def getVehicles():
    res = requests.get('https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles')
    return res.json()

def getVehicleWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicle/:{id}')
    
def geoCarDrivingDifference(destination, vehicle):
    lon_1, lat_1, lon_2, lat_2 = vehicle[0], vehicle[1], destination[0], destination[1]
    r = requests.get(f"http://router.project-osrm.org/route/v1/car/{lon_1},{lat_1};{lon_2},{lat_2}?overview=false""")
    route = r.json()
    print(route)
    return route["routes"]

def filterVehicles(destination, vehicles):
    vehicles = filter(lambda x: x['status'] == 'Free', vehicles)
    vehicles.sort(reverse=False, key = geoCarDrivingDifference(destination))



def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    #main()
    #print(dictionaryFromJson(getVehicles()))
    geoCarDrivingDifference((48.144634,11.565120),(48.149759,11.578488))