# ======= Test Dependencies =======

fs = require 'fs'
async = require 'async'
expect = (require 'chai').expect
daemonPid = require './../dist/daemon-pid'


# ========= Test Constants ========

TEST_PID_FILE_PATH = './test.pid'


# ========== Test Helpers =========

# Simply synchronously tests if the pid file exists.
testPidFileExists = ->
  return fs.existsSync(TEST_PID_FILE_PATH)

# Removes the pid file if it exists.
removeTestPidFile = ->
  if testPidFileExists() then fs.unlinkSync(TEST_PID_FILE_PATH)

# Writes a fake pid file.
writeFakePidFile = (pid, timestamp, data) ->
  if data != undefined
    s = new Buffer(JSON.stringify(data)).toString('base64')
  else
    s = ''
  d = [pid, timestamp, s].join('\n')
  fs.writeFileSync(TEST_PID_FILE_PATH, d, {flag: 'wx'});

# Testing helper for use when the test performs comparisons with the processes'
# actual start time. This method passes the callback a Date() object of the
# start time (to the nearest second) of the process.
actualStartTest = (dp, callback) ->
  actualStart = null
  cb = (err, date) ->
    expect(err).to.not.exist
    actualStart = date
    dp.write((err) ->
      expect(err).to.not.exist
      callback.call null, actualStart)
  dp._started(process.pid, cb)


# ============= Tests =============

describe 'daemon-pid', ->
  dp = null

  before -> removeTestPidFile()
  after -> removeTestPidFile()

  beforeEach ->
    dp = daemonPid(TEST_PID_FILE_PATH)
    fs.exists(TEST_PID_FILE_PATH, (e) ->
      expect(e).not.to.be.ok)

  afterEach -> removeTestPidFile()

  describe '#write', ->

    it 'should write a pid file to the specified path', (done) ->
      cb = (err) ->
        expect(err).not.to.exist
        expect(fs.existsSync(TEST_PID_FILE_PATH)).to.be.ok
        done()
      dp.write(cb)

    it 'should error if the passed data is not json-able', (done) ->
      cb = (err) ->
        expect(err).to.exist
        expect(fs.existsSync(TEST_PID_FILE_PATH)).not.to.be.ok
        done()
      obj = {}
      obj.circular = obj
      dp.write(cb, obj)

    it 'should write json-able data to the pid file', (done) ->
      data = [1234, 'abcd', [1,2,3], {a: 1, b: 2}, true, false, 0, null]
      f = (data, g) ->
        dp.write(((err) ->
          expect(err).not.to.exist
          expect(fs.existsSync(TEST_PID_FILE_PATH)).to.be.ok
          dp.read((err, d) ->
            expect(err).to.not.exist
            expect(d).to.eql(data)
            removeTestPidFile()
            g())
        ), data)
      async.eachSeries(data, f, done)

    it 'should error if the pid file already exists', (done) ->
      cb = (err) ->
        expect(err).not.to.exist
        dp.write((err) ->
          expect(err).to.exist
          done())
      dp.write(cb)

    it 'should write the pid file as read-only for owner and group', (done) ->
      cb = (err) ->
        expect(err).not.to.exist
        stat = fs.statSync(TEST_PID_FILE_PATH)
        expect(stat.mode).to.equal(0o100440)
        done()
      dp.write(cb)


  describe '#read', ->

    it 'should show an error if the pid file has not been written', (done) ->
      cb = (err) ->
        expect(err).to.exist
        done()
      dp.read(cb)


  describe '#running', ->

    it 'should error if the pid file has not been written', (done) ->
      cb = (err, running) ->
        expect(err).to.exist
        expect(running).to.be.false
        done()
      dp.running(cb)

    it 'should be false if the recorded pid does not exist', (done) ->
      writeFakePidFile(90000, Date.now())
      cb = (err, running) ->
        expect(err).not.to.exist
        expect(running).to.be.false
        done()
      dp.running(cb)

    it 'should be false if the start times differ', (done) ->
      writeFakePidFile(process.pid, Date.now())
      cb = (err, running) ->
        expect(err).not.to.exist
        expect(running).to.be.false
        done()
      dp.running(cb)

    it 'should be true if the process is running', (done) ->
      cb = (err, running) ->
        expect(err).not.to.exist
        expect(running).to.be.true
        done()
      dp.write((err) ->
        expect(err).not.to.exist
        dp.running(cb))


  describe '#delete', ->

    it 'should remove the pid file', (done) ->
      dp.write((err) ->
        expect(err).to.not.exist
        dp.delete((err) ->
          expect(err).to.not.exist
          done()))

    it 'should error if the pid file does not exist', (done) ->
      dp.delete((err) ->
        expect(err).to.exist
        done())


  describe '#started', ->

    it 'should return the date/time the process started', (done) ->
      actualStartTest(dp, (actualStart) ->
        dp.started((err, date) ->
          expect(err).not.to.exist
          expect(date).to.be.an.instanceof(Date)
          expect(date.getTime()).to.equal(actualStart.getTime())
          done()))

    it 'should error if the process is not running', (done) ->
      writeFakePidFile(90000, 0)
      dp.started((err) ->
        expect(err).to.exist
        done())


  describe '#uptime', ->

    it 'should be the number of seconds the process has been running', (done) ->
      actualStartTest(dp, (actualStart) ->
        dp.uptime((err, seconds) ->
          t = parseInt (Date.now() - actualStart.getTime()) / 1000
          expect(seconds).to.be.closeTo(t, 1)
          done()))

    it 'should error if the process is not running', (done) ->
      writeFakePidFile(90000, 0)
      dp.uptime((err) ->
        expect(err).to.exist
        done())


  describe '#monitor', ->

    it 'should call the callback if the pid file is removed', (done) ->
      dp.write((err) ->
        expect(err).to.not.exist
        dp.monitor((err) ->
          expect(err).to.exist
          dp.stop()
          done()
        , 50)
        setTimeout(->
          dp.delete()
        , 500))

    it 'should error if the process isn\'t running', (done) ->
      dp.monitor((err) ->
        expect(err).to.exist
        done()
      , 10)
