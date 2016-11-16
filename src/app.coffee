express = require 'express'
bodyParser = require 'body-parser'

connman = require './connman'
hotspot = require './hotspot'
networkManager = require './networkManager'
systemd = require './systemd'
wifiScan = require './wifi-scan'

app = express()

app.use(bodyParser.json())
app.use(bodyParser.urlencoded(extended: true))
app.use(express.static(__dirname + '/public'))

ssids = []

error = (e) ->
	console.log(e)
	if retry
		console.log('Retrying')
		console.log('Clearing credentials')
		manager.clearCredentials()
		.then ->
			run()
		.catch (e) ->
			error(e)
	else
		console.log('Not retrying')
		console.log('Exiting')
		process.exit()

app.get '/ssids', (req, res) ->
	res.json(ssids)

app.post '/connect', (req, res) ->
	if not (req.body.ssid? and req.body.passphrase?)
		return res.sendStatus(400)

	res.send('OK')

	hotspot.stop(manager)
	.then ->
		manager.setCredentials(req.body.ssid, req.body.passphrase)
	.then ->
		run()
	.catch (e) ->
		error(e)

app.use (req, res) ->
	res.redirect('/')

run = ->
	manager.isSetup()
	.then (setup) ->
		if setup
			console.log('Credentials found')
			hotspot.stop(manager)
			.then ->
				console.log('Connecting')
				manager.connect(15000) # Delay needed to allow manager to connect
			.then ->
				console.log('Connected')
				console.log('Exiting')
				process.exit()
			.catch (e) ->
				error(e)
		else
			console.log('Credentials not found')
			hotspot.stop(manager)
			.then ->
				wifiScan.scanAsync()
			.then (results) ->
				ssids = results
				hotspot.start(manager)
			.catch (e) ->
				error(e)

app.listen(80)

retry = true
clear = true
manager = null

if process.argv[2] == '--clear=true'
	console.log('Clear enabled')
	clear = true
else if process.argv[2] == '--clear=false'
	console.log('Clear disabled')
	clear = false
else if not process.argv[2]?
	console.log('No clear flag passed')
	console.log('Clear enabled')
else
	console.log('Invalid clear flag passed')
	console.log('Exiting')
	process.exit()

systemd.exists('NetworkManager.service')
.then (result) ->
	if result
		console.log('Using NetworkManager.service')
		manager = networkManager
	else
		console.log('Using connman.service')
		manager = connman
.then ->
	if clear
		console.log('Clearing credentials')
		manager.clearCredentials()
.then ->
	manager.isSetup()
	.then (setup) ->
		if setup
			retry = false
.then ->
	run()
.catch (e) ->
	console.log(e)
	console.log('Exiting')
	process.exit()
