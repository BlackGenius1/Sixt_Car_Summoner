import json
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler

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
idx  = getVehicles()[0]["vehicleID"]

def getVehicleWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}')
    return res
print(getVehicleWithId(idx))

def updateCoordinatesOfVehicle(id,lat,lng):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/:{id}/coordinates')

def updateBatteryChargeOfVehicle(id,charge):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/:{id}/{charge}')

def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    #main()
    #print(getVehicles())
    pass



def dictionaryFromJson(data):
    data_dict = json.load(data)
    return data_dict
