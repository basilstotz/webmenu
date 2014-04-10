###*
# node.js side of things starts here and its connected with the node-webkit
# "browser" in scripts/start.js.
###

posix = require "posix"
mkdirp = require "mkdirp"
fs = require "fs"
_ = require "underscore"
Q = require "q"
path = require "path"
Handlebars = require "handlebars"
{EventEmitter} = require "events"
Backbone = require "backbone"

FeedCollection = require "./FeedCollection"
launchCommand = require "./launchcommand"
menutools = require "./menutools"
requirefallback = require "./requirefallback"
logStartTime = require "./logStartTime"
dbusRegister = require "./dbusRegister"
forceFocus = require "./forceFocus"
createSpawnSocket = require "./createSpawnSocket"
logger = require "./fluent-logger"
pkg = require "../package.json"

webmenuHome = process.env.HOME + "/.config/webmenu"

spawnSocket = path.join(webmenuHome, "spawn.sock")
spawnSocket = process.env.WM_SOCK if process.env.WM_SOCK

mkdirp.sync(webmenuHome)

process.on 'uncaughtException', (err) ->
    process.stderr.write "!!nodejs uncaughtException!!\n"
    process.stderr.write err.message + "\n"
    process.stderr.write err.stack + "\n"
    logger.emit(
        msg: "unhandled exception"
        capturedFrom: "process.on(uncaughtException)"
        error:
            message: err.message
            stack: err.stack
    )

    process.exit 1

spawnEmitter = createSpawnSocket spawnSocket, (err) ->
    throw err if err
    dbusRegister().then (msg) ->
        logStartTime("dbus registration: #{ msg }")
    , (err) ->
        console.error "dbus registration failed: #{ err.message }"

PUAVO_SESSION = null
if sp = process.env.PUAVO_SESSION_PATH
    try
        PUAVO_SESSION = JSON.parse(fs.readFileSync(sp).toString())
    catch e
        console.error "Failed to read PUAVO_SESSION_PATH: #{ e.message }"

locale = process.env.LANG
locale ||= "fi_FI.UTF-8"
menuJSON = requirefallback(
    webmenuHome + "/menu.json"
    "/etc/webmenu/menu.json"
    __dirname + "/../menu.json"
)

safeRequire = (path) ->
    try
        return require(path)
    catch err
        throw err if err.code isnt "MODULE_NOT_FOUND"
        return {}

# Merge config files. Last one overrides options from previous one
config_data = _.extend({},
    safeRequire(__dirname + "/../config.json"),
    safeRequire("/etc/webmenu/config.json"),
    safeRequire(webmenuHome + "/config.json"),
)

config = new Backbone.Model config_data
config.set("hostType", require "./hosttype")
config.set("feedback", logger.active and process.env.WM_FEEDBACK_ACTIVE)
config.set("guestSession", (process.env.GUEST_SESSION is "true"))

userPhotoPath = "#{ webmenuHome }/user-photo.jpg"


try
    puavoDomain = fs.readFileSync("/etc/puavo/domain").toString().trim()
    expandVariables = (ob, attr) ->
        tmpl = Handlebars.compile(ob[attr])
        ob[attr] = tmpl(puavoDomain: puavoDomain)
catch err
    console.warn "Cannot read Puavo Domain", err
    console.warn "Disabling password and profiles buttons"
    config.set("passwordCMD", null)
    config.set("profileCMD", null)

if puavoDomain
    if config.get("passwordCMD")
        expandVariables(config.get("passwordCMD"), "url")
    if config.get("profileCMD")
        expandVariables(config.get("profileCMD"), "url")


desktopReadStarted = Date.now()
# inject data from .desktop file to menuJSON.
menutools.injectDesktopData(
    menuJSON
    config.get("dotDesktopSearchPaths")
    locale
    config.get("iconSearchPaths")
    config.get("fallbackIcon")
    config.get("hostType")
)

desktopReadTook = (Date.now() - desktopReadStarted) / 1000
console.log(".desktop files read took " + desktopReadTook + " seconds")

username = posix.getpwnam(posix.geteuid()).name
userData = posix.getpwnam(username)
userData.fullName = userData.gecos.split(",")[0]


###*
# Function that connects node.js and node-webkit. We should not share any other
# variables between these two worlds to keep them decoubled.
#
# @param {Object} gui node-webkit gui object
###
module.exports = (gui, Window) ->
    menuVisible = false
    noHide = "--devtools" in gui.App.argv
    shared = new EventEmitter

    hideWindow =  ->
        menuVisible = false
        if noHide
            console.log "Hiding disabled"
            return
        console.info "Hiding menu window"
        Window.hide()

    ###*
    # Make menu visible and bring it to current desktop
    ###
    displayMenu = ->
        if fs.existsSync(userPhotoPath)
          config.set("userPhoto", "file://#{ userPhotoPath }")
        else
          config.set("userPhoto", "styles/theme/default/img/anonymous.png")

        menuVisible = true
        console.log "Displaying menu"
        Window.show()
        Window.focus()
        Window.setAlwaysOnTop(true)
        forceFocus(pkg.window.title, 50, 100, 350, 500)

    ###*
    # Toggle menu visibility with given view name
    #
    # @param {String} viewName
    ###
    toggleMenu = do ->
        currentView = null
        return (viewName) ->
            shared.emit("open-view", viewName)

            if currentView isnt viewName
                currentView = viewName
                if menuVisible
                    # When menu view is changing while the menu itself is still visible
                    # make sure it's hidden before the view is displayed. This ensures
                    # that the menu moves to the current cursor position. Required when
                    # user clicks the logout button from right of the panel while menu is
                    # visible on the left side.
                    Window.hide()
                    setTimeout(displayMenu, 1) # Allow menu to disappear
                else
                    displayMenu()
                return

            # When view is not changing just toggle menu visibility
            if menuVisible
                hideWindow()
            else
                displayMenu()


    ###*
    # Handle menu spawns from panel and keyboard shortcuts
    #
    # @param {Object} options
    #   @param {String} options.logout Display logout view
    #   @param {String} options.webmenu-exit Exit Webmenu gracefully
    ###
    spawnHandler = (options) ->

        if options.logout
            toggleMenu("logout")
        else if options["webmenu-exit"]
            code = parseInt(options["webmenu-exit"], 10) or 0
            console.info "Exiting on user request with code #{ options["webmenu-exit"] }"
            process.exit(code)
        else
            toggleMenu("root")

    # Prevent crazy menu spawning which might cause slow machines to get stuck
    # for long periods of time
    spawnEmitter.on "spawn", _.debounce(spawnHandler, 300, true)

    open = (cmd) ->

        if typeof cmd.toJSON is "function"
            cmd = cmd.toJSON()

        console.log "Opening command", cmd
        logger.emit(
            msg: "open"
            cmd: _.omit(cmd,
                "description",
                "osIconPath",
                "osIcon",
                "keywords"
            )
        )

        Window.setAlwaysOnTop(false)

        # Use node-webkit to open toolbarless web window
        if cmd.type is "webWindow"
            console.info "Opening web window", cmd.url
            gui.Window.open? cmd.url,
                width: cmd.width or 1000
                height: cmd.height or 800
                "always-on-top": false
                toolbar: false
                frame: true
                title: cmd.name
        else
            launchCommand(cmd)

    shared.user = userData
    shared.config = config
    shared.menu = menuJSON
    shared.logger = logger
    shared.feeds = new FeedCollection([], {
        command: config.get("feedCMD")
    })

    shared.executeAction = (action) ->
        if actionCMD = config.get(action + "CMD")
            launchCommand(actionCMD)
        else
            console.error "Unknown action #{ action }"

    shared.hideWindow =  hideWindow
    if config.get("feedback")
        shared.sendFeedback = (feedback) ->

            msg = {
                msg: "feedback",
                feedback: feedback
            }

            if not feedback.anonymous
                msg.session = PUAVO_SESSION

            logger.emit("feedback", msg)
            return Q("feedback sent ok")

    shared.open = open
    shared.logReady = ->
        logStartTime("Webmenu HTML/CSS/JS ready")
    return shared

