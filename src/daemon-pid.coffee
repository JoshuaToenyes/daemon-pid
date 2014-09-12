# ======= Module Dependencies =======

async = require 'async'
fs    = require 'fs'
exec  = (require 'child_process').exec



# ========= Module Exports ==========

# Exposes simple function to instantiate DaemonPid instance.
module.exports = (pidFilePath) ->
  return new DaemonPid(pidFilePath)



# ======== Module Constants =========

# The default interval to check on monitored processes.
DEFAULT_MONITOR_INTERVAL = 5000



# ========= Module Classes ==========

# Implements a pid file management class capable of monitoring processes using
# pid files stored at known locations. Designed for use in daemonized processes.
class DaemonPid

  # Constructor takes the pid file path.
  constructor: (@_pidFilePath) ->
    @_pid = process.pid
    @_monitor = null


  # Writes out the PID file with the optional JSON-able data attached. Calls the
  # callback function with (err).
  write: (cb, data) ->
    @_started(@_pid, (err, started) =>
      if (err)
        cb?.call err
        return
      try
        if data != undefined
          s = new Buffer(JSON.stringify(data)).toString('base64')
        else
          s = ''
        d = [@_pid, started.getTime(), s].join('\n')
        f =
          mode: 0o440
          flag: 'wx'
        fs.writeFile @_pidFilePath, d, f, ((err) ->
          cb?.call null, err)
      catch e
        cb?.call null, e)


  # Reads the PID file. Calls the passed callback passing (err, data).
  read: (cb) ->
    @_read((err, [pid, start, data]) ->
      cb?.call null, err, data)


  # Returns the time in seconds this process has been running. Calls the
  # passed callback with (err, seconds). Indicates an error if the process
  # referenced by the pid file is not running.
  uptime: (cb) ->
    @started (err, date) ->
      if err?
        cb?.call null, err
      else
        t = parseInt (Date.now() - date.getTime()) / 1000
        cb?.call null, undefined, t


  # Returns the Date the process referenced by this PID file was started to the
  # nearest second. Calls the passed callback with (err, date). Indicates an
  # error if the process referenced by the pid file is not running.
  started: (cb) ->
    @_running((err, running, actualStart) ->
      if not running
        cb?.call null, new Error('Process not running.')
      else
        cb?.call null, err, actualStart)


  # Deletes the associated pid file. Calls the passed callback with (err).
  delete: (cb) ->
    fs.unlink(@_pidFilePath, (err) -> cb?.call null, err)


  # Determines if the process referenced by the associated pid file is currently
  # running. Additionally, it will parse the data in the pid file and calling
  # the passed callback with (err, running, data). The callback parameter `err`
  # will only be present if the pid file exists, and there was an error reading
  # it, i.e. err will not be present if the pid file does not exists, which
  # implies the process is not running.
  running: (cb) ->
    @_running (err, running, actualStart, data) ->
      if err and err.code is 'ENOENT'
        cb?.call null, undefined, false, undefined
      else
        cb?.call null, err, running, data


  # Monitors the process referenced by the associated pid file. Calls the passed
  # callback (err). An error will be shown if the pid file is deleted or is not
  # accessible; if the process suddenly quits without removing the pid for, the
  # callback will be called and err will be undefined. Optionally, the a custom
  # monitoring interval may be defined as the second argument. This method
  # should only be called once as subsequent calls clear the previous monitor
  # for performance reasons.
  monitor: (cb, interval = DEFAULT_MONITOR_INTERVAL) ->
    if @_monitor then clearInterval(@_monitor)
    check = =>
      @running (err, running) ->
        if err or not running
          clearInterval @_monitor
          cb?.call null, err
    @_monitor = setInterval(check, interval)
    return


  # Stops monitoring the referenced process.
  unmonitor: ->
    clearInterval(@_monitor)


  # Sends the given signal to the process referenced by the associated pid file.
  # Calls the given callback with (err).
  kill: (signal, cb) ->
    @_errorIfNotRunning cb, =>
      @_read (err, [pid]) ->
        try
          process.kill pid, signal
          cb.call null, undefined
        catch e
          cb.call null, e

  # Calls the given callback with a possible error and the pid of the process
  # referenced by the associated pid file.
  pid: (cb) ->
    @_errorIfNotRunning cb, =>
      @_read (err, [pid]) ->
        cb.call null, err, pid


  # Internal-use method for testing if the process is running. If not, the given
  # client-provided callback function is called with the appropriate error.
  _errorIfNotRunning: (cb, cont) ->
    @_running (err, running) ->
      if err
        cb.call null, err
        return
      if not running
        cb.call null, new Error('Process not running.')
        return
      cont()


  # Internal-use method for testing if the process referenced by the associated
  # pid file is running. Calls the passed callback with
  # (err, running, actualStart, data).
  _running: (cb) ->
    async.waterfall([
      (callback) =>
        @_read((err, [pid, recordedStart, data]) =>
          if not @_pidRunning(pid)
            cb?.call null, undefined, false
          else
            callback.call null, err, pid, recordedStart, data )
    , (pid, recordedStart, data, callback) =>
        @_started(pid, (err, actualStart) ->
          callback.call null, err, recordedStart, actualStart, data)
    , (recordedStart, actualStart, data, callback) ->
        running = Math.abs(actualStart.getTime() - recordedStart) < 1000
        callback.call null, undefined, running, actualStart, data
    ], (err, running, actualStart, data) ->
      running = if err != undefined then false else running
      cb?.call null, err, running, actualStart, data)


  # Internal-use method for checking if a process with the passed pid is
  # running.
  _pidRunning: (pid) ->
    try
      process.kill pid, 0
      return true
    catch
      return false


  # Internal-use method. Uses `ps` to determine when the passed process-id was
  # started. Calls the passed callback with (err, date).
  _started: (pid, cb) ->
    exec "ps -o \"lstart=\" #{pid}", (err, stdout) ->
      if err
        cb?.call null, err
      else
        cb?.call null, undefined, new Date(stdout)


  # Internal function for reading and parsing the pid file. Calls the passed
  # callback with (err, [pid, start, data]).
  _read: (cb) ->
    fs.readFile @_pidFilePath, (err, contents) ->
      if err
        cb?.call null, err, []
        return
      try
        [pid, start, data64] = contents.toString().split('\n')
        if data64.length > 0
          data = JSON.parse((new Buffer(data64, 'base64')).toString())
        else
          data = undefined
        cb?.call null, undefined, [+pid, +start, data]
      catch e
        cb?.call null, e, []
