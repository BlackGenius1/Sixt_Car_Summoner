import json
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 8000

tasklist = ['t1', 't2', 't3']

headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}


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
idx  = getVehicles()[0]["vehicleID"]

def getVehicleWithId(id):
    getVehicles
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}')
    return res
print(getVehicleWithId(idx))

def updateCoordinatesOfVehicle(id,lat,lng):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}/coordinates', json={"lat": lat, "lng": lng},headers = {'Content-type': 'application/json', 'Accept': 'text/plain'})

    print("Status code: ", res.status_code)
    print("Printing Entire Post Request")
    print(res.json())

def updateBatteryChargeOfVehicle(id,charge):
    if charge < 0:
        print("Error! Charge is too low.")
    if charge > 100:
        print("Error! Charge is too high.")
    else:
        res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}/charge', json={"charge": charge},headers = {'Content-type': 'application/json', 'Accept': 'text/plain'})

def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    #main()
    print(getVehicles())
    print(getVehicles()[2])
    updateCoordinatesOfVehicle(getVehicles()[2]["vehicleID"],3,4)
    updateBatteryChargeOfVehicle(getVehicles()[2]["vehicleID"],100)
    print(getVehicles()[2])
    pass
