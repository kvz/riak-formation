# Todo:
#  - Can we use recursive maps/arrays to store assemblies?
#  - Enable search

util          = require "util"
async         = require "async"
async         = require "async"
debug         = require("debug")("tla:assemriak")
RiakPBC       = require "riakpbc"
Environmental = require "environmental"
env           = new Environmental
exec          = require("child_process").exec

client  = null

async.waterfall [
  (callback) ->
    debug "Going to load config"
    env.capture "#{__dirname}/../clusters/production/config.sh", (err, flat) ->
      if err
        return callback err

      config = Environmental.config flat, "RIFOR"
      callback null, config
  (config, callback) ->
    debug "Going to get active state and set options"
    exec "./terraform/terraform output -state=./clusters/production/terraform.tfstate public_addresses", (err, stdout, stderr) ->
      if err
        return callback new Error "Error while executing terraform output. #{err}. #{stderr}"

      options =
        nodes: []
        auth:
          user: config.user
          password: config.pass

      hosts = stdout.split "\n"
      for host in hosts when host
        options.nodes.push
          host: host
          port: 8087

      callback null, options
  (options, callback) ->
    debug "Going to set up client"
    client = RiakPBC.createClient options
    callback null
  (callback) ->
    debug "Going to ping"
    client.ping (err, response) ->
      if err
        return callback "Failed to ping. #{err}"

      debug util.inspect
        response:response

      callback null, response
  (response, callback) ->
    debug "Going to put"
    params =
      bucket     : "assemblies"
      return_body: true
      key        : "abcd"
      content    :
        value: JSON.stringify(
          id    : "abcd"
          status: "ASSEMBLY_COMPLETED"
        )
        content_type: "application/json"

    client.put params, (err, response) ->
      if err
        return callback "Failed to put. #{err}"

      debug util.inspect
        response:response.content

      callback null
  (callback) ->
    debug "Going to getKeys"
    params =
      bucket: "assemblies"

    client.getKeys params, (err, response) ->
      if err
        return callback "Failed to put. #{err}"

      keys = response.keys

      debug util.inspect
        keys:keys

      callback null, keys
  (keys, callback) ->
    debug "Going to get"
    params =
      bucket: "assemblies"
      key   : "abcd"

    client.get params, (err, response) ->
      if err
        return callback "Failed to put. #{err}"

      content = response.content
      value = content[0].value
      debug util.inspect
        content:content
        value:value

      callback null, value
], (err, result) ->
  if err
    throw "Aborting on error. #{err}"

  debug util.inspect
    result:result

  process.exit 0


