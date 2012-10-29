
http = require "http"
{exec, spawn, fork} = require "child_process"
app = require "appjs"
express = require "express"
stylus = require "stylus"
{argv} = require "optimist"
posix = require "posix"
mkdirp = require "mkdirp"

launchCommand = require "./lib/launchcommand"
menutools = require "./lib/menutools"
powermanager = require "./lib/powermanager"

handler = express()

server = http.createServer(handler).listen 1337
bridge = require("./lib/siobridge")(server)

handler.configure "development", ->
  handler.use stylus.middleware __dirname + "/content"
handler.use express.static __dirname + "/content"

cachePath = process.env.HOME + "/.webmenu/cache"
mkdirp.sync cachePath
app.init CachePath: cachePath

config = require "./config.json"
locale = process.env.LANG
locale = "fi_FI.UTF-8"
menuJSON = require "./menu.json"

menutools.injectDesktopData(
  menuJSON,
  config.dotDesktopSearchPaths,
  locale
)

username = posix.getpwnam(posix.geteuid()).name
userData = posix.getpwnam(username)
userData.fullName = userData.gecos.split(",")[0]
handler.get "/user.json", (req, res) -> res.json(userData)

handler.get "/menu.json", (req, res) ->
  res.json menuJSON

handler.get "/osicon/:icon.png", require("./routes/osicon")(
  config.iconSearchPaths,
  config.fallbackIcon
)

window = app.createWindow
  width: 1000
  height: 550
  top: 200
  showChrome: false
  disableSecurity: true
  showOnTaskbar: false
  icons: __dirname + '/content/icons'
  disableBrowserRequire: true
  url: "http://localhost:1337"

displayMenu = ->
  title = "Opinsys Web Menu"
  bridge.emit "show"
  window.frame.title = title
  window.frame.show()
  window.frame.focus()

  # gtk_window_present does not always give focus to us. Hack around with
  # wmctrl for now.
  # https://github.com/appjs/appjs/blob/f585f7ccfa7d2b54d910dd21d280ae4ad40f8f06/src/native_window/native_window_linux.cpp#L411
  setTimeout ->
    wmctrl = spawn("wmctrl", ["-a", title])
    wmctrl.on 'exit', (code) ->
      if code isnt 0
        console.log('wmctrl exited with code ' + code)
  , 200


window.on 'create', ->
  console.log("Window Created")
  displayMenu()
  window.frame.center()
  if argv["dev-tools"]
    console.log "Opening devtools"
    window.frame.openDevTools()


handler.get "/show", (req, res) ->
  res.send "ok"
  displayMenu()

bridge.on "open", (msg) ->
  launchCommand(msg)
  window.frame.hide()

bridge.on "openSettings", ->
  launchCommand(config.settingsCMD)
  window.frame.hide()

bridge.on "hideWindow", ->
  console.log "Hiding window"
  window.frame.hide() if not argv["dev-tools"]

bridge.on "showMyProfileWindow", ->
  fork __dirname + "/profile.js", [], (detached: true)

bridge.on "shutdown", -> powermanager.shutdown()
bridge.on "reboot", -> powermanager.reboot()
bridge.on "logout", -> powermanager.logout()

