DaemonPID
==========

DaemonPID is a utility module which provides straight-forward and robust PID file management; perfect for writing and reading PID files for daemonized services. It provides the ability to check or monitor the status of previously launched child processes, store additional data along with the process id, and provides process start-time verification to ensure the recorded process-id was not recycled by the OS.

- [Basic Usage](#basic-usage)
- [Advance Usage](#advanced-usage)
- [API](#api)


## What is a PID file?

A PID file is essentially a text file in a well-defined location in the 
file-system which contains at-least the process ID of a running application. 
Writing PID files is a convention used in many software systems as a simple 
way to check the status of services or daemonized processes without requiring 
separate supervisory or monitoring processes.


## PID File Pitfalls 

Process IDs are not required to be unique and can potentially be recycled. To solve this issue, DaemonPID also records and checks the start-time of the process for future comparison and status checks.


## Basic Usage

Here's a basic use-case of DaemonPID in a daemonized process.

### Inside Child Process

    pid = require('daemon-pid')(PID_FILE_PATH);
    
    // writes-out the pid file
    pid.write(function(err) {
        // err indicates error writing pid file
    });

### Inside Launch Script or CLI

    pid = require('daemon-pid')(PID_FILE_PATH);
    spawn = require('child_process').spawn;
    
    child = spawn('node', [SERVICE_FILE], {
        detached: true,
        stdio ['ignore']
    };
    
    // remove the pid file on exit
    child.on('close', function(code) {
        pid.delete(function(err) {
            // err indicates error deleting pid file
        });
    });

### Status Checking Script or CLI

    pid = require('daemon-pid')(PID_FILE_PATH);
    
    pid.running(function(err, running) {
        if (running) {
            console.log('service is running as expected');
        } else {
            console.error('service is down!');
        }
    });
    
## Advanced Usage
    
### Storing Data

Additional information can be stored in the PID file for use later. Any data convertible to JSON can be stored.

    pid = require('daemon-pid')(PID_FILE_PATH);
    
    // writes-out the pid file with additional data
    pid.write(function(err) {
        // err indicates error writing pid file
    }, SERVICE_PORT_NUMBER);

In another script that data can later be retreived:

    pid = require('daemon-pid')(PID_FILE_PATH);
    
    // writes-out the pid file with additional data
    pid.read(function(err, port) {
        if (err) {
            console.error('unable to read pid file');
        } else {
            console.log('service running on port ' + port);
        }
    });

### Simple Status Monitor

It's easy to implement a simple status-monitor as a separate process.

    pid = require('daemon-pid')(PID_FILE_PATH);
    
    pid.monitor(function(err) {
        if (err) {
            console.error('unable to read pid file');
        } else {
            console.error('service went down!');
        }
    });

## API

TODO
