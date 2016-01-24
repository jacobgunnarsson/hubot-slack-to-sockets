# Description
#   A hubot script that relays messages to and from a Slack channel through
#   WebSockets, originally built as a 'backend' for a web-to-Slack chat.
#
# Dependencies:
#  "socket.io": "^1.4.4"
#
# Configuration:
#   HUBOT_SLOCKETS_SOCKET_PORT - Overrides the default WebSockets port (7070)
#
# Commands:
#   <hubot name> slockets connected - list connected user across namespaces
#
# Author:
#   Jacob Gunnarsson <jacob.gunnarsson@hyperisland.se>

# Default settings
defaults =
  socketPort: process.env.HUBOT_SLOCKETS_SOCKET_PORT || 7070
  commandNamespace: 'slocket'
  namespaces: [{
    moniker: 'ᴅᴏʙᴇʀᴍᴀɴ.ɪᴏ'
    name: '/doberman.io'
    room: 'hubot-test'
    sockets: []
  }]

# Setup sockets.io
io = require('socket.io')()
io.listen defaults.socketPort

# Setup Slockets object
Slockets = {}

Slockets.setup = (robot) ->
  @robot = robot
  @namespaces = defaults.namespaces

  # Setup namespace io:s
  for namespace in @namespaces
    namespace.Slockets = @
    namespace.robot = @robot
    namespace.io = io.of namespace.name, () =>
      namespace.io.on 'connection', (socket) =>
        return if socket._initialized
        @_log 'Socket connected'
        socket.on 'message',      @socketRecieveMessage
        socket.on 'connectUser',  @socketConnectUser
        socket.on 'disconnect',   @socketDisconnect
        socket.namespace = namespace
        namespace.sockets.push socket

  # Hook up hubot listener
  robot.listen @robotListenMatcher.bind(@), @robotListenCallback.bind(@)
  robot.respond /slockets connected/gi, @robotRespondConnected.bind(@)

Slockets.robotListenMatcher = (message) ->
  matchedNamespaces = (namespace for namespace in @namespaces when namespace.room is message.room)

Slockets.robotListenCallback = (response) ->
  @sendMessage namespace, response.message for namespace in response.match

Slockets.robotRespondConnected = (response) ->
  connectedUsers = @.namespaces.reduce ((sum, namespace) -> sum + namespace.sockets.length), 0
  response.send connectedUsers + ' connected users'

Slockets.sendMessage = (namespace, message) ->
  namespace.io.emit 'message', message

Slockets.socketConnectUser = (message) ->
  @.namespace.Slockets._log message.name + ' joined'
  @.name = message.name
  @.namespace.robot.messageRoom @.namespace.room, @.namespace.Slockets._formatMessage message.name, 'connected! @here', @.namespace

Slockets.socketDisconnect = () ->
  @.namespace.Slockets._log 'Socket disconnected'
  @.namespace.sockets.splice @namespace.sockets.indexOf @, 1

Slockets.socketRecieveMessage = (message) ->
  @.namespace.robot.messageRoom @.namespace.room, @.Slockets._formatMessage message.name, 'says: ' + message.text, @.namespace

Slockets._formatMessage = (name = 'Anonymous', message, namespace) ->
  namespace.moniker + ' - *' + name + '* ' + message

Slockets._log = (message) ->
  @robot.logger.debug('Slocket - ' + message);

# Finally export
module.exports = Slockets.setup.bind Slockets
