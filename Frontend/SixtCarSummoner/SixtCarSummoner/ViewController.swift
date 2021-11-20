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
    
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 1000
    var isSatellite = false
    
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
        showDirection(from: from, to: to)
        orderButton.layer.isHidden = false
        cancelOrderButton.layer.isHidden = false
    }
    
    func showDirection(from: String, to: String){
        //get coordinates for string
        var geocoder = CLGeocoder()
        var fromCoordinate = CLLocationCoordinate2D()
        var toCoordinate = CLLocationCoordinate2D()
    
        if from == "MyLocation" || from == "My Location"{
            fromCoordinate = CLLocationCoordinate2D(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
            geocoder.geocodeAddressString(to) {
                placemarks, error in
                let placemark = placemarks?.first
                let latTo = placemark?.location?.coordinate.latitude
                let lonTo = placemark?.location?.coordinate.longitude
                toCoordinate = CLLocationCoordinate2D(latitude: latTo!, longitude: lonTo!)
                self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                //self.mapView(self.mapView, rendererFor: <#T##MKOverlay#>)
            }
        }else if to == "MyLocation" || to == "My Location"{
            toCoordinate = CLLocationCoordinate2D(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
            geocoder.geocodeAddressString(to) {
                placemarks, error in
                let placemark = placemarks?.first
                let lat = placemark?.location?.coordinate.latitude
                let lon = placemark?.location?.coordinate.longitude
                fromCoordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                //self.mapView(self.mapView, rendererFor: <#T##MKOverlay#>)
            }
            
        }else{
            geocoder.geocodeAddressString(from) {
                placemarks, error in
                let placemark = placemarks?.first
                let lat = placemark?.location?.coordinate.latitude
                let lon = placemark?.location?.coordinate.longitude
                fromCoordinate = CLLocationCoordinate2D(latitude: lat!, longitude: lon!)
                
                geocoder.geocodeAddressString(to) {
                    placemarks, error in
                    let placemark = placemarks?.first
                    let latTo = placemark?.location?.coordinate.latitude
                    let lonTo = placemark?.location?.coordinate.longitude
                    toCoordinate = CLLocationCoordinate2D(latitude: latTo!, longitude: lonTo!)
                    self.showRouteOnMap(pickupCoordinate: fromCoordinate, destinationCoordinate: toCoordinate)
                    //self.mapView(self.mapView, rendererFor: MKOverl)
                }
            }
        }
        
        
        print(fromCoordinate)
        print(toCoordinate)

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
        
    }
    
    @IBAction func cancelOrderButtonClicked(_ sender: Any) {
        
        removeAllAnnotations()
        orderButton.layer.isHidden = true
        cancelOrderButton.layer.isHidden = true
        
    }
    
    
    
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
