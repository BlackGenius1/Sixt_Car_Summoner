//
//  ViewController.swift
//  SixtCarSummoner
//
//  Created by Julian Waluschyk on 19.11.21.
//

import UIKit
import MapKit
import CoreLocation
import Hero
import SPAlert
import SwiftyJSON

class ViewController: UIViewController, CLLocationManagerDelegate {

    //instances
    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var locationButton: UIButton!
    @IBOutlet weak var mapTypeButton: UIButton!
    @IBOutlet weak var orderButton: UIButton!
    @IBOutlet weak var cancelOrderButton: UIButton!
    @IBOutlet weak var timeView: UIView!
    @IBOutlet weak var timeLable: UILabel!
    @IBOutlet weak var timeDescriptionLable: UILabel!
    
    //TODO coordinate errors abfangen
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 1000
    var isSatellite = false
    
    //jsontags
    let userUID = "1111111111111111"
    struct Car{
        var lat: String
        var lon: String
        var charge: String
    }
    var carArray = [Car]()
    
    //for Route Calculation
    var from: String = ""
    var to: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkLocationServices()
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        
        //Button
        searchButton.layer.cornerRadius = 32.0
        settingsButton.layer.isHidden = true
        settingsButton.layer.cornerRadius = 32.0
        orderButton.layer.cornerRadius = 32.0
        locationButton.layer.cornerRadius = 20.0
        mapTypeButton.layer.cornerRadius = 20.0
        cancelOrderButton.layer.cornerRadius = 20.0
        timeView.layer.cornerRadius = 25.0
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
     
        //NOTIFICATIONS
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.calculateRoute(_:)),
                                               name:Notification.Name(rawValue: "CALCULATEROUTE"),
                                               object: nil)//register for notification
        
        //-------------------------
        
        //send login request to server -------
        
        let jsonObject: NSMutableDictionary = NSMutableDictionary()

        jsonObject.setValue(userUID, forKey: "uid")
        jsonObject.setValue(locationManager.location?.coordinate.latitude, forKey: "lat")
        jsonObject.setValue(locationManager.location?.coordinate.longitude, forKey: "lng")

        let jsonData: NSData

        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as NSData
            
            //post data
            guard let url = URL(string: "http://85.214.129.142:8000/login") else {
                print("error")
                return
            }
            
            var request = URLRequest(url: url)
            
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let httpBody = jsonData

            request.httpBody = httpBody as Data
            let jsonString = NSString(data: httpBody as Data, encoding: String.Encoding.utf8.rawValue)! as String
            print(jsonString)
            
            let session = URLSession.shared
            session.dataTask(with: request) { (data, response, error) in
                if error != nil {
                    DispatchQueue.main.async {
                        let alertView = SPAlertView(title: "Verbindung fehlgeschlagen!", message: "Überprüfe deine Internetverbindung und versuche es erneut.", preset: SPAlertPreset.error)
                        alertView.present()
                    }
                    return
                }
                
                                
                if let data = data{
                    let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
                    print(jsonString)
                    
                    
                    do {
                        
                        let json = try JSON(data: data)
                        print(json)

                        
                        for (index, object) in json {
                            let lat = object["lat"].stringValue
                            let lon = object["lng"].stringValue
                            let charge = object["charge"].stringValue
                            
                            let car = Car(lat: lat, lon: lon, charge: charge)
                            self.carArray.append(car)
                        }
                        
                        //add Cars
                        DispatchQueue.main.async {
                            var carAnnotations = [MKPointAnnotation]()
                            for car in self.carArray{
                                let carDestination = MKPointAnnotation()
                                let destinationPlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: Double(car.lat)!, longitude: Double(car.lon)!), addressDictionary: nil)
                                let carAnnotation = MKPointAnnotation()
                                carAnnotation.title = "Car"
                                if let location = destinationPlacemark.location {
                                    carAnnotation.coordinate = location.coordinate
                                }
                                
                                carAnnotations.append(carAnnotation)
                                
                            }
                        self.mapView.showAnnotations(carAnnotations, animated: true )
                    }
                        
                    } catch let error {
                        print(error)
                    }
                }
                
            }.resume()
            
        } catch _ {
            print ("JSON Failure")
            print("error")
        }
        
        //---------------
    
    }
    
    //MAPFUNCTIONS-------------------------------------------------------
    func setupLocationManager(){
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func centerViewOnUserLocation(){
        if let location = locationManager.location?.coordinate{
            let region = MKCoordinateRegion.init(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func checkLocationServices(){
        
        if CLLocationManager.locationServicesEnabled(){
            setupLocationManager()
            locationManager.requestWhenInUseAuthorization()
        }else{
            //Show alert
            UIAlertController.init(title: "Error", message: "You need to enable location services in your settings", preferredStyle: UIAlertController.Style.alert)
        }
        
    }
    
    @IBAction func locationButtonTapped(_ sender: Any) {
        centerViewOnUserLocation()
    }
    
    @IBAction func mapTypeButtonClicked(_ sender: Any) {
        if isSatellite{
            isSatellite = false
            mapView.mapType = .standard
            mapTypeButton.setImage(UIImage(systemName: "globe"), for: .normal)
        }else{
            isSatellite = true
            mapView.mapType = .hybrid
            mapTypeButton.setImage(UIImage(systemName: "map"), for: .normal)
        }
    }
    
    @objc public func calculateRoute(_ notification: NSNotification){
        if let from = notification.userInfo?["from"] as? String {
            self.from = from
        }
        if let to = notification.userInfo?["to"] as? String {
            self.to = to
        }
        if showDirectionSuccess(from: from, to: to){
            orderButton.layer.isHidden = false
            cancelOrderButton.layer.isHidden = false
            searchButton.isEnabled = false
        }
        
    }
    
    func showDirectionSuccess(from: String, to: String) ->Bool{
        
        //get coordinates for string
        var geocoder = CLGeocoder()
        var fromCoordinate = CLLocationCoordinate2D()
        var toCoordinate = CLLocationCoordinate2D()
        var success = true
    
        if from == "MyLocation" || from == "My Location"{
            fromCoordinate = CLLocationCoordinate2D(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
            geocoder.geocodeAddressString(to) {
                placemarks, error in
                let placemark = placemarks?.first
                let latTo = placemark?.location?.coordinate.latitude
                let lonTo = placemark?.location?.coordinate.longitude
  
                if latTo == nil || lonTo == nil{
                    SPAlert.present(title: "Error", message: "Sorry, we couldn't find any route", preset: .error)
                    success = false
                    self.orderButton.layer.isHidden = true
                    self.cancelOrderButton.layer.isHidden = true
                    self.searchButton.isEnabled = true
                }else{
                    toCoordinate = CLLocationCoordinate2D(latitude: latTo!, longitude: lonTo!)
                    self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                    self.requestCar(lat1: (self.locationManager.location?.coordinate.latitude)!, lng1: (self.locationManager.location?.coordinate.longitude)!, lat2: latTo!, lng2: lonTo!)
                }

            }
        }else if to == "MyLocation" || to == "My Location"{
            toCoordinate = CLLocationCoordinate2D(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
            geocoder.geocodeAddressString(to) {
                placemarks, error in
                let placemark = placemarks?.first
                let lat = placemark?.location?.coordinate.latitude
                let lon = placemark?.location?.coordinate.longitude
                
                if lat == nil || lon == nil{
                    SPAlert.present(title: "Error", message: "Sorry, we couldn't find any route", preset: .error)
                    success = false
                    self.orderButton.layer.isHidden = true
                    self.cancelOrderButton.layer.isHidden = true
                    self.searchButton.isEnabled = true
                }else{
                    fromCoordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                    self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                    self.requestCar(lat1: lat!, lng1: lon!, lat2: (self.locationManager.location?.coordinate.latitude)!, lng2: (self.locationManager.location?.coordinate.longitude)!)
                }
                
            }
            
        }else{
            geocoder.geocodeAddressString(from) {
                placemarks, error in
                let placemark = placemarks?.first
                let lat = placemark?.location?.coordinate.latitude
                let lon = placemark?.location?.coordinate.longitude
                
                if lat == nil || lon == nil{
                    SPAlert.present(title: "Error", message: "Sorry, we couldn't find any route", preset: .error)
                    success = false
                    self.orderButton.layer.isHidden = true
                    self.cancelOrderButton.layer.isHidden = true
                    self.searchButton.isEnabled = true
                }else{
                    fromCoordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                    self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                }
                
                fromCoordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                
                geocoder.geocodeAddressString(to) {
                    placemarks, error in
                    let placemark = placemarks?.first
                    let latTo = placemark?.location?.coordinate.latitude
                    let lonTo = placemark?.location?.coordinate.longitude
                    
                    if latTo == nil || lonTo == nil{
                        SPAlert.present(title: "Error", message: "Sorry, we couldn't find any route", preset: .error)
                        success = false
                        self.orderButton.layer.isHidden = true
                        self.cancelOrderButton.layer.isHidden = true
                        self.searchButton.isEnabled = true
                    }else{
                        toCoordinate = CLLocationCoordinate2D(latitude: latTo!, longitude: lonTo!)
                        self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                        self.requestCar(lat1: lat!, lng1: lon!, lat2: latTo!, lng2: lonTo!)
                    }
                }
            }
        }

        return success

    }
    
    func requestCar(lat1: Double, lng1: Double, lat2: Double, lng2: Double){
        let jsonObject: NSMutableDictionary = NSMutableDictionary()
        
        jsonObject.setValue(lat1, forKey: "lat1")
        jsonObject.setValue(lng1, forKey: "lng1")
        jsonObject.setValue(lat2, forKey: "lat2")
        jsonObject.setValue(lng2, forKey: "lng2")
        jsonObject.setValue(userUID, forKey: "uid")
        
        let jsonData: NSData

        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as NSData
            
            //post data
            guard let url = URL(string: "http://85.214.129.142:8000/route") else {
                print("error")
                return
            }
            
            var request = URLRequest(url: url)
            
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let httpBody = jsonData

            request.httpBody = httpBody as Data
            let jsonString = NSString(data: httpBody as Data, encoding: String.Encoding.utf8.rawValue)! as String
            print(jsonString)
            
            let session = URLSession.shared
            session.dataTask(with: request) { (data, response, error) in
                if error != nil {
                    DispatchQueue.main.async {
                        let alertView = SPAlertView(title: "Verbindung fehlgeschlagen!", message: "Überprüfe deine Internetverbindung und versuche es erneut.", preset: SPAlertPreset.error)
                        alertView.present()
                    }
                    return
                }
                
                                
                if let data = data{
                    let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
                    print(jsonString)
                    
                    
                    do {
                        
                        let json = try JSON(data: data)
                        print(json)

                        
                        for (index, object) in json {
                            let lat = object["lat"].stringValue
                            let lon = object["lng"].stringValue
                            let charge = object["charge"].stringValue
                            
                            let car = Car(lat: lat, lon: lon, charge: charge)
                            self.carArray.append(car)
                        }
                        
                        //add Cars
                        DispatchQueue.main.async {
                            var carAnnotations = [MKPointAnnotation]()
                            for car in self.carArray{
                                let carDestination = MKPointAnnotation()
                                let destinationPlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: Double(car.lat)!, longitude: Double(car.lon)!), addressDictionary: nil)
                                let carAnnotation = MKPointAnnotation()
                                if let location = destinationPlacemark.location {
                                    carAnnotation.coordinate = location.coordinate
                                }
                                
                                carAnnotations.append(carAnnotation)
                                
                            }
                        self.mapView.showAnnotations(carAnnotations, animated: true )
                    }
                        
                    } catch let error {
                        print(error)
                    }
                }
                
            }.resume()
            
        } catch _ {
            print ("JSON Failure")
            print("error")
        }
    }
    
    func removeAllAnnotations() {
        let annotations = mapView.annotations.filter {
            $0 !== self.mapView.userLocation
        }
        mapView.removeAnnotations(annotations)
    }
    
    //---------------------------------------------------------------

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSearch"{
           // let dest = segue.destination as! SearchViewController
            //dest.hero.modalAnimationType = .selectBy(presenting: .fade, dismissing:.fade)
        }
    }
    
    @IBAction func confirmOrderButtonClicked(_ sender: Any) {
        timeView.layer.isHidden = false
        searchButton.layer.isHidden = true
        cancelOrderButton.layer.isHidden = true
        orderButton.layer.isHidden = true
        
        //show alert
        SPAlert.present(title: "Success", message: "", preset: .done)
        
        //send requests
        let jsonObject: NSMutableDictionary = NSMutableDictionary()

        jsonObject.setValue(userUID, forKey: "uid")
        jsonObject.setValue(locationManager.location?.coordinate.latitude, forKey: "lat")
        jsonObject.setValue(locationManager.location?.coordinate.longitude, forKey: "lng")

        let jsonData: NSData

        do {
            jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: JSONSerialization.WritingOptions()) as NSData
            
            //post data
            guard let url = URL(string: "http://85.214.129.142:8000/login") else {
                print("error")
                return
            }
            
            var request = URLRequest(url: url)
            
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let httpBody = jsonData

            request.httpBody = httpBody as Data
            let jsonString = NSString(data: httpBody as Data, encoding: String.Encoding.utf8.rawValue)! as String
            print(jsonString)
            
            let session = URLSession.shared
            session.dataTask(with: request) { (data, response, error) in
                if error != nil {
                    DispatchQueue.main.async {
                        let alertView = SPAlertView(title: "Verbindung fehlgeschlagen!", message: "Überprüfe deine Internetverbindung und versuche es erneut.", preset: SPAlertPreset.error)
                        alertView.present()
                    }
                    return
                }
                
                                
                if let data = data{
                    let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
                    print(jsonString)
                    
                    
                    do {
                        
                        let json = try JSON(data: data)
                        print(json)

                        
                        for (index, object) in json {
                            let lat = object["lat"].stringValue
                            let lon = object["lng"].stringValue
                            let charge = object["charge"].stringValue
                            
                            let car = Car(lat: lat, lon: lon, charge: charge)
                            self.carArray.append(car)
                        }
                        
                        //add Cars
                        DispatchQueue.main.async {
                            var carAnnotations = [MKPointAnnotation]()
                            for car in self.carArray{
                                let carDestination = MKPointAnnotation()
                                let destinationPlacemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: Double(car.lat)!, longitude: Double(car.lon)!), addressDictionary: nil)
                                let carAnnotation = MKPointAnnotation()
                                if let location = destinationPlacemark.location {
                                    carAnnotation.coordinate = location.coordinate
                                }
                                
                                carAnnotations.append(carAnnotation)
                                
                            }
                        self.mapView.showAnnotations(carAnnotations, animated: true )
                    }
                        
                    } catch let error {
                        print(error)
                    }
                }
                
            }.resume()
            
        } catch _ {
            print ("JSON Failure")
            print("error")
        }
        
    }
    
    @IBAction func cancelOrderButtonClicked(_ sender: Any) {
        
        removeAllAnnotations()
        orderButton.layer.isHidden = true
        cancelOrderButton.layer.isHidden = true
        searchButton.isEnabled = true
        //remove overlays
        let overlays = mapView.overlays
        mapView.removeOverlays(overlays)
        
    }
    
    //HTTP stuff-------------------------------------------------
    
    
    
    
}


extension ViewController: MKMapViewDelegate {

// MARK: - showRouteOnMap

func showRouteOnMap(pickupCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D) {

    let sourcePlacemark = MKPlacemark(coordinate: pickupCoordinate, addressDictionary: nil)
    let destinationPlacemark = MKPlacemark(coordinate: destinationCoordinate, addressDictionary: nil)

    let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
    let destinationMapItem = MKMapItem(placemark: destinationPlacemark)

    let sourceAnnotation = MKPointAnnotation()

    if let location = sourcePlacemark.location {
        sourceAnnotation.coordinate = location.coordinate
    }

    let destinationAnnotation = MKPointAnnotation()

    if let location = destinationPlacemark.location {
        destinationAnnotation.coordinate = location.coordinate
    }

    self.mapView.showAnnotations([sourceAnnotation,destinationAnnotation], animated: true )

    let directionRequest = MKDirections.Request()
    directionRequest.source = sourceMapItem
    directionRequest.destination = destinationMapItem
    directionRequest.transportType = .automobile

    // Calculate the direction
    let directions = MKDirections(request: directionRequest)

    directions.calculate {
        (response, error) -> Void in

        guard let response = response else {
            if let error = error {
                print("Error: \(error)")
            }

            return
        }

        let route = response.routes[0]

        self.mapView.addOverlay((route.polyline), level: MKOverlayLevel.aboveRoads)

        let rect = route.polyline.boundingMapRect
        self.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
    }
}

// MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        let renderer = MKPolylineRenderer(overlay: overlay)

        renderer.strokeColor = UIColor(red: 216/255, green: 71/255, blue: 30/255, alpha: 1)

        renderer.lineWidth = 5.0

        return renderer
    }
    
    
    
}
