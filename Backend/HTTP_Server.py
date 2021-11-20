import json
import requests
import googlemaps
from http.server import HTTPServer, BaseHTTPRequestHandler

"""
    /login uid=... for Log in
    /route uid=...lat1=...lon1=...lat2=...lon2=... for getting nearest car
    /confirm uid=... for job confirmation
    /pickup uid=... for successful pick up
    /dropoff uid=... for successfu drop of
    /cancel uid=...lat=...lon=... for job cancellation
"""

PORT = 8000

KILOMETERS_PER_PERCENT = 4

GEOFENCE_SIZE_SHOW = .3
GEOFENCE_SIZE_START = .01
GEOFENCE_SIZE_MAX = .03
GEOFENCE_STEP = .01

users = [{'uid': '1111111111111111'}]
google_maps_api_key = 'AIzaSyCYqNsvXY_BsymUGlLK2QFRuZvAKsR2YEg'
potential_jobs = []
jobs = []


def getVehicles():
    res = requests.get('https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles')
    return res.json()

def getVehicleWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicle/:{id}')

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


"""Sort the vehicles using the googlemaps api"""

def getRouteInfo(start, destination):
    """Get route information from the googlemaps api"""
    #vehicle_coordinates = (vehicle['lat'], vehicle['lng']) #Maybe switch lat and lng
    map_client = googlemaps.Client(google_maps_api_key)
    route = map_client.distance_matrix(start, destination, mode='driving')#["rows"][0]["elements"][0]["distance"]["value"]
    return route

def getRouteLength(start, final_destination):
    """Return the length of a given route"""
    route = getRouteInfo(start, final_destination)
    return route['rows'][0]['elements'][0]['distance']['value'] /1000

def isInGeofence(destination, vehicle, geofence):
    """Retrurn true if the vehicle is inside of a geofence"""
    return abs(destination[0] - vehicle['lat']) < geofence and abs(destination[1] - vehicle['lng']) < geofence

def isEnoughCharge(final_destination, destination, vehicle):
    """Return Trrue if the vehicle has enough Battery left to make the ride"""
    start = (vehicle['lat'], vehicle['lng'])
    distance = getRouteLength(start, destination) + getRouteLength(destination, final_destination)
    needed_charge = distance/KILOMETERS_PER_PERCENT * 1.1
    return vehicle['charge'] >= needed_charge

def filterFREEVehicles(vehicles):
    """Retrun all vehicles with status FREE"""
    return list(filter(lambda x: x['status'] == 'FREE', vehicles))

def prefilterVehicles(destination, vehicles, geofence):
    """Return all vehicles wich have status FREE and are in a geofence"""
    vehicles = list(filter(lambda x: x['status'] == 'FREE', vehicles))
    vehicles = list(filter(lambda x: isInGeofence(destination, x, geofence), vehicles))
    return vehicles

def postfilterVehicles(final_destination, destination, vehicles):
    """Returens all vehicles with enough charge to make the ride"""
    vehicles = list(filter(lambda x: isEnoughCharge(final_destination, destination, x), vehicles))
    return vehicles

    
def getRouteDuration(start, destination):
    """Return the duration a vehicle is expected to need to get from its position to the required destination"""
    route = getRouteInfo(start, destination)
    #print(route)
    return route['rows'][0]['elements'][0]['duration']['value']

def getRouteDurationFromModifiedVehicle(modified_vehicle):
    """Return the duration of the modified vehicle. Mainly for sorting purposes"""
    return modified_vehicle['duration']

def appendDuration(destination, vehicles):
    """Return modified vehicle list. Modification: Added a duration entry"""
    for vehicle in vehicles:
        start = (vehicle['lat'], vehicle['lng'])
        vehicle['duration'] = getRouteDuration(start, destination)
    return vehicles

def SortVehicles(final_destination, destination, vehicles):
    """Returns the modified vehicle list sorted by the expected traveling duration and dynamically apply a search area."""
    geofence = GEOFENCE_SIZE_START
    vehicles = prefilterVehicles(destination, vehicles, geofence)
    vehicles_duration = appendDuration(destination, vehicles)
    vehicles_duration.sort(reverse=False, key = getRouteDurationFromModifiedVehicle)
    vehicles = postfilterVehicles(final_destination, destination, vehicles)
    while vehicles == [] and geofence < GEOFENCE_SIZE_MAX:
        geofence += GEOFENCE_STEP
        vehicles = prefilterVehicles(destination, vehicles, geofence)
        vehicles_duration = appendDuration(destination, vehicles)
        vehicles_duration.sort(reverse=False, key = getRouteDurationFromModifiedVehicle)
        vehicles = postfilterVehicles(final_destination, destination, vehicles)
    return vehicles

def getBestVehicle(final_destination, destination, vehicles):
    """Return most suited vehicle"""
    sorted = SortVehicles(final_destination, destination, vehicles)
    if sorted:
        return sorted[0]
    else:
        return 

def createJob(start, destination, uid, vehicleID):
    """Return job dictionary"""
    job = {'lat1': start[0], 'lng1': start[1], 'lat2': destination[0], 'lng2': destination[1], 'uid': uid, 'vehicleID': vehicleID}
    return job

class requestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests"""
        if self.path[:6]=='/test':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            self.wfile.write(json.dumps(filterFREEVehicles(getVehicles())).encode())

    def do_POST(self):
        """Handle POST requests"""
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        data = post_data

        if self.path[:6]=='/login':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            self.wfile.write(json.dumps(prefilterVehicles(getVehicles()), .5).encode())

        elif self.path[:6]=='/route':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            data = post_data
            out = getBestVehicle((data['lat2'], data['lng2']), (data['lat1'], data['lat2']), getVehicles())
            if out:
                potential_jobs.append(createJob((data['lat1'], data['lng1']),(data['lat2'], data['lng2']), data['uid'], data['vehicleID']))
                self.wfile.write(out.encode())
            else:
                msg = 'No fitting car found'
                self.wfile.write(msg.encode())
        
        elif self.path[:9]=='/confirm':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            
            #self.wfile.write() 
            #TODO: confirm to api
        
        elif self.path[:7]=='/pickup':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            #self.wfile.write()
            #TODO: confirm pickup
        
        elif self.path[:8]=='/dropoff':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            #self.wfile.write()
            #TODO: confirm dropoff/end job

        elif self.path[:7]=='/cancel':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            #self.wfile.write()
            #TODO: cancel job

        else:
            self.send_error(404,"Error! Invalid URL.")


def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()
    #print(dictionaryFromJson(getVehicles()))
    #vehicles = getVehicles()
    #print(SortVehicles((48.156, 11.57),(48.144634,11.565320), vehicles))
