//
//  SearchViewController.swift
//  SixtCarSummoner
//
//  Created by Julian Waluschyk on 20.11.21.
//

import Foundation
import UIKit
import Hero
import MapKit
import CoreAudio

class SearchViewController: UIViewController{
    
    @IBOutlet weak var fromSearchBar: UISearchBar!
    @IBOutlet weak var destinationSearchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var resultsButton: UIButton!

    var isfromEditing = true
    
    lazy var searchCompleter: MKLocalSearchCompleter = {
            let sC = MKLocalSearchCompleter()
            sC.delegate = self
            return sC
        }()

    var searchSource: [MKLocalSearchCompletion]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Design
        fromSearchBar.backgroundImage = UIImage()
        destinationSearchBar.backgroundImage = UIImage()
        resultsButton.layer.cornerRadius = 20.0
        
        self.hideKeyboardWhenTappedAround()
        
    }
    
    @IBAction func resultsButtonClicked(_ sender: Any) {
        
        //handle Input
        let from = fromSearchBar.text!
        let destination = destinationSearchBar.text!
        
        //go to map
        let dateS:[String: String] = ["from": from, "to": destination]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "CALCULATEROUTE"), object: nil, userInfo: dateS)
        self.dismiss(animated: true)
    }
    
    
    @IBAction func backButtonClicked(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        //change searchCompleter depends on searchBar's text
        if !searchText.isEmpty {
            searchCompleter.queryFragment = searchText
        }
        if searchBar == fromSearchBar{
            self.isfromEditing = true
        }else{
            self.isfromEditing = false
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchSource?.removeAll()
        tableView.reloadData()
    }
    
}

extension SearchViewController: UITableViewDelegate, UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchSource?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = self.tableView.dequeueReusableCell(withIdentifier: "searchCell", for: indexPath) as! SearchCell
        cell.label.text = self.searchSource?[indexPath.row].title
            return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isfromEditing{
            fromSearchBar.text = searchSource?[indexPath.row].title
        }else{
            destinationSearchBar.text = searchSource?[indexPath.row].title
        }
        dismissKeyboard()
        
    }
    
}

extension SearchViewController: MKLocalSearchCompleterDelegate{
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        //get result, transform it to our needs and fill our dataSource
        self.searchSource = completer.results.map { $0 }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        //handle the error
        print(error.localizedDescription)
    }
    
}

extension SearchViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(SearchViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
