var express = require('express');
var router = express.Router();
var request = require('request');
var config = require('../config');

// Predefiniowana lista miast
const cities = [
    { name: "Warsaw", query: "Warsaw,PL" },
    { name: "Berlin", query: "Berlin,DE" },
    { name: "London", query: "London,GB" },
    { name: "Helsinki", query: "Helsinki,FI" }
];

router.get('/', function(req, res) {
  res.render('index', { weather: null, error: null, cities: cities });
});

router.post('/', function(req, res) {
  let cityQuery = req.body.city; 
  let url = config.url + `&q=${cityQuery}`;
  
  request(url, function(err, response, body) {
    if(err) {
      res.render('index', { weather: null, error: 'API Connection Error', cities: cities });
    } else {
      let weather = JSON.parse(body);
      
      if(weather.main == undefined) {
        res.render('index', { weather: null, error: 'City not found', cities: cities });
      } else {
        let weatherText = `In ${weather.name} it is currently ${weather.main.temp}°C.`;
        res.render('index', { weather: weatherText, error: null, cities: cities });
      }
    }
  });
});

module.exports = router;