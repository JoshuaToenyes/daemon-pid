/*
 * The canonical NodeJS web server example. 
 */

// Requiring daemon-pid, passing the same pid file path.
var pid = require('../../dist/daemon-pid')('./pid');

var http = require('http');

pid.write(function(err) {
  if (err) {
    console.error('There was a problem writing the pid file!', err);
    process.exit(-1);
    
  } else {

    var connections = [];
    
    // Now that the server is up and running, we can write-out the pid file.
    var server = http.createServer(function (req, res) {
      res.writeHead(200, {'Content-Type': 'text/plain'});
      res.end('Hello World\n');
    }).listen(1337, '127.0.0.1');
    
    server.on('connection', function(s) {
      connections.push(s);
    });
    
    server.on('close', function(s) {
      connections.splice(connections.indexOf(s), 1);
    });

    console.log('Server running at http://127.0.0.1:1337/');
    
    // When we get the signal to terminate, stop the server and delete the 
    // PID file.
    process.on('SIGTERM', function() {

      // Disconnect everyone right now.
      connections.forEach(function(s) {
        s.destroy();
      });
      
      server.close(function() {
        pid.delete(function(err) {
          if (err) console.error('Something we wrong deleting the pid file!');
          console.log('Server stopped.');
        });
      });
    });
  }
});
