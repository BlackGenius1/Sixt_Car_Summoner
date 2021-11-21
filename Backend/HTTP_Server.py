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

KILOMETERS_PER_PERCENT = 5

GEOFENCE_SIZE_SHOW = .3
GEOFENCE_SIZE_START = .05
GEOFENCE_SIZE_MAX = 0.51
GEOFENCE_STEP = .1

users = [{'uid': '1111111111111111'}]
google_maps_api_key = 'AIzaSyCYqNsvXY_BsymUGlLK2QFRuZvAKsR2YEg'
potential_jobs = []
jobs = []


def getVehicles():
    res = requests.get('https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles')
    return res.json()

def getVehicleWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicle/:{id}')
    return res.json()

def updateBatteryChargeOfVehicle(id,charge):
    if charge < 0:
        print("Error! Charge is too low.")
    if charge > 100:
        print("Error! Charge is too high.")
    else:
        res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}/charge', 
        json={"charge": charge},headers = {'Content-type': 'application/json', 'Accept': 'text/plain'})


def getBookings():
    res = requests.get('https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings')
    return res.json()

def getBookingWithId(id):
    res = requests.get(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings/{id}')
    return res.json()

def cancelBookingById(id):
    res = requests.delete(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings/{id}')

def createBooking(pickupLat,pickupLng,destinationLat,destinationLng):
    
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings', json={
        "pickupLat": pickupLat,
	    "pickupLng": pickupLng,
        "destinationLat": destinationLat,
	    "destinationLng": destinationLng},
        headers = {'Content-type': 'application/json', 'Accept': 'text/plain'})
    return res.json()

def pickupBooking(id):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings/{id}/passengerGotOn')

def dropoffBooking(id):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings/{id}/passengerGotOff')

def updateVehiclePosition(lat, lng, id):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/vehicles/{id}/coordinates', json={
        "lat": lat,
        "lng": lng
    },headers = {'Content-type': 'application/json', 'Accept': 'text/plain'})



def assignVehicleToBooking(bookingId,vehicleId):
    res = requests.post(f'https://us-central1-sixt-hackatum-2021.cloudfunctions.net/api/bookings/{bookingId}/assignVehicle/{vehicleId}')

    print("Status code: ", res.status_code)
    print("Printing Entire Post Request")
    #print(res.json())

def getDictionaryByKeyFromList(list, key, value):
    for entry in list:
        try:
            entry[key] == value
            return entry
        except:
            continue
    return 

"""Sort the vehicles using the googlemaps api"""

def getRouteInfo(start, destination):
    """Get route information from the googlemaps api"""
    #vehicle_coordinates = (vehicle['lat'], vehicle['lng']) #Maybe switch lat and lng
    map_client = googlemaps.Client(google_maps_api_key)
    route = map_client.distance_matrix(start, destination, mode='driving')
    #print(f'Route: {route}')#["rows"][0]["elements"][0]["distance"]["value"]
    return route

def getRouteLength(start, final_destination):
    """Return the length of a given route"""
    route = getRouteInfo(start, final_destination)
    try:
        ret = route['rows'][0]['elements'][0]['distance']['value'] /1000
    except KeyError:
        ret = 999999999999999999
    return ret

def isInGeofence(destination, vehicle, geofence):
    """Retrurn true if the vehicle is inside of a geofence"""
    return (abs(destination[0] - vehicle['lat']) < geofence and abs(destination[1] - vehicle['lng']) < geofence)

def isEnoughCharge(final_destination, destination, vehicle):
    """Return Trrue if the vehicle has enough Battery left to make the ride"""
    start = (vehicle['lat'], vehicle['lng'])
    distance = getRouteLength(start, destination) + getRouteLength(destination, final_destination)
    needed_charge = distance/KILOMETERS_PER_PERCENT +10
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
    #print(f"start: {start},      destination {destination}")
    #print(route)
    try:
        ret = route['rows'][0]['elements'][0]['duration']['value']
    except KeyError:
        ret = 999999999999999999
    return ret

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
    vehicles = prefilterVehicles(vehicles)
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
    #print(f"get best Vehicle: final: {final_destination}, dest: {destination}, vehicles: {vehicles}")
    sorted = SortVehicles(final_destination, destination, vehicles)
    #print(sorted)
    if sorted:
        return sorted[0]
    else:
        return 

def createJob(start, destination, uid, vehicleID, duration, booking_id):############
    """Return job dictionary"""
    job = {'lat1': start[0], 'lng1': start[1], 'lat2': destination[0], 'lng2': destination[1], 'uid': uid, 'vehicleID': vehicleID, 'duration': duration, 'bookingID': booking_id}############
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
        try:
            data = json.loads(post_data)
        except:
            print(f'invalid Data: {post_data}')
            self.send_error(400,"Error!")
            

        if self.path[:6]=='/login':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            vehicles = getVehicles()
            #self.wfile.write(json.dumps(vehicles).encode())
            print(f'Successful login')
            self.wfile.write(json.dumps(prefilterVehicles((data['lat'], data['lng']), vehicles,1)).encode())

        elif self.path[:6]=='/route':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            #print(data)
            out = getBestVehicle((data['lat2'], data['lng2']), (data['lat1'], data['lng1']), getVehicles())
            #print(f'out= {out}')
            if out:
                print(type(data), data)
                booking_id = createBooking(data['lat1'], data['lng1'], data['lat2'], data['lng2'])
                potential_jobs.append(createJob((data['lat1'], data['lng1']),(data['lat2'], data['lng2']), data['uid'], out['vehicleID'], out['duration'], booking_id))
                print(f'Successful created Route for best vehicle')
                self.wfile.write(json.dumps(out).encode())
                
            else:
                msg = 'No suited car found'
                self.wfile.write(msg.encode())
        
        elif self.path[:8]=='/confirm':
            job_data = getDictionaryByKeyFromList(potential_jobs, 'uid', data['uid'])
            if job_data:
                jobs.append(job_data)
                potential_jobs.remove(job_data)
                assignVehicleToBooking(job_data['bookingID'], job_data['vehicleID'])
                print(f'Successfully confirmed ride')
                self.send_response(200)
                self.send_header('content-type', 'text/html')
                self.end_headers()
                self.wfile.write(json.dumps({'duration': job_data['duration']}).encode())
            else:
                self.send_error(404,"Error! Internal job error.")
            
            #self.wfile.write() 
            #TODO: confirm to api
        
        elif self.path[:7]=='/pickup':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            print(f'Successful pickup')
            
            self.end_headers()
            job = getDictionaryByKeyFromList(jobs, 'uid', data['uid'])
            pickupBooking(job['bookingID'])
            updateVehiclePosition(job['lat1'], job['lng1'], job['vehicleID'])
            if job:
                jobs.remove(job)
            else:
                print(f"Error deleting job: {job}")
            #self.wfile.write()
            #TODO: confirm pickup
        
        elif self.path[:8]=='/dropoff':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            job = getDictionaryByKeyFromList(jobs, 'uid', data['uid'])
            dropoffBooking(job['bookingID'])
            print(f'Successful dropoff')
            updateVehiclePosition(job['lat2'], job['lng2'], job['vehicleID'])
            expected_charge = round(getRouteInfo((job['lat1'], job['lng1']), (job['lat2'], job['lng2']))/KILOMETERS_PER_PERCENT)
            updateBatteryChargeOfVehicle(job['vehicleID'], expected_charge)
            self.end_headers()
            #self.wfile.write()
            #TODO: confirm dropoff/end job

        elif self.path[:7]=='/cancel':
            self.send_response(200)
            self.send_header('content-type', 'text/html')
            self.end_headers()
            uid = data['uid']
            pot_job = getDictionaryByKeyFromList(potential_jobs, 'uid', uid)
            cancelBookingById(pot_job['bookingID'])
            if pot_job:
                try:
                    potential_jobs.remove(pot_job)
                    print(f'Successful cancellation')
                except:
                    print(f'Error at cancellation!')
                    pass
            #self.wfile.write()
            #TODO: cancel job

        else:
            self.send_error(404,"Error! Invalid URL.")

def testBookings():
    temp = 3
    #print(getBookings())
    print(getBookings()[temp])
    #cancelBookingById(getBookings()[2]["bookingID"])
    assignVehicleToBooking(getBookings()[temp]["bookingID"],getVehicles()[2]["vehicleID"])
    print(getBookings()[temp])
    createBooking(40,40,30,30)
    #print(getBookings())

def main():
    server = HTTPServer(('', PORT), requestHandler)
    print(f"Server running on port {PORT}")
    server.serve_forever()

if __name__ == "__main__":
    main()
    #testBookings()
    #print(dictionaryFromJson(getVehicles()))
    #vehicles = getVehicles()
    #print(SortVehicles((48.156, 11.57),(48.144634,11.565320), vehicles))