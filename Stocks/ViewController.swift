//
//  ViewController.swift
//  Stocks
//
//  Created by Семен Кривоносов on 11.09.2018.
//  Copyright © 2018 Семен Кривоносов. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.companies.keys.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(self.companies.keys)[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.requestQuoteUpdate()
    }
    
    private var companies: [String:String] = [:]
    private func zeroing() {
        DispatchQueue.main.async {
            self.companyNameLabel.text = "-"
            self.priceLabel.text = "-"
            self.priceChangeLabel.text = "-"
            self.priceChangeLabel.textColor = UIColor.black
        }
    }
    private func requestQuoteUpdate() {
        self.activityIndicator.startAnimating()
        self.zeroing()
        
        let selectedRow = self.companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(self.companies.values)[selectedRow]
        self.requestQuote(for: selectedSymbol)
    }
    private func parseQuote(data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double
                
                else {
                    self.zeroing()
                    alertMessage(errorMessage: "Unexpected internal error")
                    return
            }
            DispatchQueue.main.async {
                self.displayStockInfo(companyName: companyName, symbol: companySymbol, price: price, priceChange: priceChange)
            }
        } catch {
            self.zeroing()
            alertMessage(errorMessage: "Unexpected internal error")
        }
    }
    
    private func alertMessage(errorMessage: String) {
        let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func displayStockInfo(companyName: String, symbol: String, price: Double, priceChange: Double) {
        self.activityIndicator.stopAnimating()
        self.companyNameLabel.text = companyName + " (\(symbol))"
        self.priceLabel.text = "\(price)" + " \u{0024}"
        var arrow = String()
        if priceChange > 0 {
            self.priceChangeLabel.textColor = UIColor.green
            arrow = " \u{2197}"
        }
        else if priceChange < 0 {
            self.priceChangeLabel.textColor = UIColor.red
            arrow = " \u{2198}"
        }
        else {
            self.priceChangeLabel.textColor = UIColor.black
        }
        self.priceChangeLabel.text = "\(priceChange)" + " \u{0024}" + arrow
    }
    private func requestQuote(for symbol: String) {
        let infoUrl = URL(string: "https://api.iextrading.com/1.0/stock/\(symbol)/quote")!
        let imageUrl = URL(string: "https://storage.googleapis.com/iex/api/logos/\(symbol).png")!
        let dataInfoTask = URLSession.shared.dataTask(with: infoUrl){ data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.zeroing()
                    self.alertMessage(errorMessage: "Network error")
                    return
            }
            
            self.parseQuote(data: data)
        }
        let dataImageTask = URLSession.shared.dataTask(with: imageUrl){ data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.zeroing()
                    self.alertMessage(errorMessage: "Network error")
                    return
            }
            
            DispatchQueue.main.async {
                self.logoLabel.image = UIImage(data: data)
            }
        }
        dataImageTask.resume()
        dataInfoTask.resume()
    }
    private func getCompaniesList() {
        let url = URL(string: "https://api.iextrading.com/1.0/stock/market/list/infocus")!
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: url){ data, response, error in
            guard
                error == nil,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let data = data
                else {
                    self.zeroing()
                    self.alertMessage(errorMessage: "Unexpected internal error")
                    return
            }
            do {
                let companiesArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String:Any]]
                for object in companiesArray! {
                    self.companies[object["companyName"] as! String] = object["symbol"] as? String
                }
            } catch {
                self.zeroing()
                self.alertMessage(errorMessage: "Unexpected internal error")
            }
            semaphore.signal()
        }
        
        task.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
    }
    @IBOutlet weak var logoLabel: UIImageView!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if InternetConnectionChecker.isConnectedToNetwork() == false {
            alertMessage(errorMessage: "No Internet connection")
        }
        
        self.companyPickerView.dataSource = self
        self.companyPickerView.delegate = self
        self.activityIndicator.hidesWhenStopped = true
        self.getCompaniesList()
        self.requestQuoteUpdate()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

