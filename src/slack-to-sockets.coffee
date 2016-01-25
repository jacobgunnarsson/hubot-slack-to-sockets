# Description
#   A hubot script that relays messages to and from a Slack channel through
#   WebSockets, originally built as a 'backend' for a web-to-Slack chat.
#
# Dependencies:
#  "socket.io": "^1.4.4"
#
# Configuration:
#   HUBOT_S2S_SOCKET_PORT - Overrides the default WebSockets port (7070)
#
# Commands:
#   <hubot name> s2s connected - list connected user across namespaces
#
# Author:
#   Jacob Gunnarsson <jacob.gunnarsson@hyperisland.se>

# Default settings
settings =
  socketPort: process.env.HUBOT_S2S_SOCKET_PORT || 7070
  commandPrefix: 's2s'
  namespaces: [{
    name: '/doberman.io'
    room: 'hubot-test'
    moniker: 'ᴅᴏʙᴇʀᴍᴀɴ.ɪᴏ'
    sockets: []
  }]

# Setup sockets.io
io = require('socket.io')()
io.listen settings.socketPort


# Namespace class
class Namespace

  @constructor: (defaults) ->
    { @name, @room, @moniker } = defaults

# Setup S2S object
S2S = {}

S2S.setup = (robot) ->
  @robot = robot
  @namespaces = []

  # Setup namespaces
  for namespace in @namespaces
    namespace.S2S = @
    namespace.robot = @robot
    namespace.io = io.of namespace.name, () =>
      namespace.io.on 'connection', (socket) =>
        return if socket in namespace.sockets
        @_log 'Socket connected'
        socket.on 'message',      @socketRecieveMessage
        socket.on 'connectUser',  @socketConnectUser
        socket.on 'disconnect',   @socketDisconnect
        socket.namespace = namespace
        namespace.sockets.push socket

  # Hook up hubot listener
  robot.listen @robotListenMatcher.bind(@), @robotListenCallback.bind(@)
  robot.respond /s2s connected/gi, @robotRespondConnected.bind(@)

S2S.robotListenMatcher = (message) ->
  matchedNamespaces = (namespace for namespace in @namespaces when namespace.room is message.room)

S2S.robotListenCallback = (response) ->
  @sendMessage namespace, response.message for namespace in response.match

S2S.robotRespondConnected = (response) ->
  connectedUsers = @.namespaces.reduce ((sum, namespace) -> sum + namespace.sockets.length), 0
  response.send connectedUsers + ' connected users'

S2S.sendMessage = (namespace, message) ->
  namespace.io.emit 'message', message

S2S.socketConnectUser = (message) ->
  @.namespace.S2S._log message.name + ' joined'
  @.name = message.name
  @.namespace.robot.messageRoom @.namespace.room, @.namespace.S2S._formatMessage message.name, 'connected! @here', @.namespace

S2S.socketDisconnect = () ->
  @.namespace.S2S._log 'Socket disconnected'
  @.namespace.sockets.splice @namespace.sockets.indexOf @, 1

S2S.socketRecieveMessage = (message) ->
  @.namespace.robot.messageRoom @.namespace.room, @.S2S._formatMessage message.name, 'says: ' + message.text, @.namespace

S2S._formatMessage = (name = 'Anonymous', message, namespace) ->
  namespace.moniker + ' - *' + name + '* ' + message

S2S._log = (message) ->
  @robot.logger.debug('Slack to Sockets - ' + message);

# Finally export
module.exports = S2S.setup.bind S2S
