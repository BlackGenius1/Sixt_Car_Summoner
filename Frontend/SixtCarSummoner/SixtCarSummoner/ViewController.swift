//
//  ViewController.swift
//  SixtCarSummoner
//
//  Created by Julian Waluschyk on 19.11.21.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {

    //instances
    @IBOutlet var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 1000
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkLocationServices()
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        
    }
    
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
    
    

}
