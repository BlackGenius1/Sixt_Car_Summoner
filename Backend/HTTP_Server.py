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




def getVehicles():
    res = requests.get('https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles')
    return res.json()

def getVehicleWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicle/:{id}')



"""Sort the vehicles using the googlemaps api"""


def getRouteInfo(start, destination):
    """Get route information from the googlemaps api"""
    #vehicle_coordinates = (vehicle['lat'], vehicle['lng']) #Maybe switch lat and lng
    map_client = googlemaps.Client(google_maps_api_key)
    route = map_client.distance_matrix(start, destination, mode='driving')#["rows"][0]["elements"][0]["distance"]["value"]
    return route

def getRouteLength(start, final_destination):
    route = getRouteInfo(start, final_destination)
    return route['rows'][0]['elements'][0]['distance']['value'] /1000

def isInGeofence(destination, vehicle, geofence):
    return abs(destination[0] - vehicle['lat']) < geofence and abs(destination[1] - vehicle['lng']) < geofence

def isEnoughCharge(final_destination, destination, vehicle):
    start = (vehicle['lat'], vehicle['lng'])
    distance = getRouteLength(start, destination) + getRouteLength(destination, final_destination)
    needed_charge = distance/KILOMETERS_PER_PERCENT * 1.1
    return vehicle['charge'] >= needed_charge

def filterFREEVehicles(vehicles):
    return list(filter(lambda x: x['status'] == 'FREE', vehicles))

def prefilterVehicles(destination, vehicles, geofence):
    vehicles = list(filter(lambda x: x['status'] == 'FREE', vehicles))
    vehicles = list(filter(lambda x: isInGeofence(destination, x, geofence), vehicles))
    return vehicles

def postfilterVehicles(final_destination, destination, vehicles):
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
    sorted = SortVehicles(final_destination, destination, vehicles)
    if sorted:
        return sorted[0]
    else:
        return 'No fitting car found'

class requestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path[:6] == '/login':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            self.wfile.write(json.dumps(list(filterFREEVehicles(getVehicles()))).encode())
        #elif self.path[:6]('/route'):
        #    pass
        #elif self.path[:9]('/confirm'):
        #    pass
        #elif self.path[:7]('/pickup'):
        #    pass
        #elif self.path[:8]('/dropoff'):
        #    pass
        #elif self.path[:7]('/cancel'):
        #    pass
        else:
            pass

def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()
    #print(dictionaryFromJson(getVehicles()))
    #vehicles = getVehicles()
    #print(SortVehicles((48.156, 11.57),(48.144634,11.565320), vehicles))