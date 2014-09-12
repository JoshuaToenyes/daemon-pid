/*
 * Simple example command-line utility for starting a long-running child process
 * using daemon-pid. This is a super-simple CLI... I'd recommend using a tool
 * like Commander for more advance CLIs.
 * 
 * Commander CLI
 * https://www.npmjs.org/package/commander
 */

// We pass the PID file path the daemon-pid so it knows where to look for the
// pid file.
var pid = require('../../dist/daemon-pid')('./pid');

// We'll use spawn to start the server.
var spawn = require('child_process').spawn;

// Let's grab the command from the command-line.
var command = process.argv[2];

// Switch on this 
switch (command) {
  
  
  case 'start':
    
    // Let's quickly check if the server is already running.
    pid.running(function(err, running) {
      
      // err will indicate if it can't read the pid file... which we'd expect
      // if the pid file doesn't exist. So here, we can just check `running`.
      if (running) {
        console.log('Server is already running.');
        process.exit(-1);
        
      } else {
        
        // Here, we're starting the webserver as it's own "group leader", 
        // meaning it can continue to run after the CLI exits. 
        // Checkout http://nodejs.org/api/child_process.html#child_process_child_process_spawn_command_args_options
        // for more info.
        var child = spawn('node', ['./server.js'], {
          detached: true,
          stdio: 'inherit'
        });

        // Now we're done with the child, so we can detach it.
        child.unref();
      }
    });
    break;
  
  
  case 'stop':
    
    // Let's quickly check if the server is already running.
    pid.running(function(err, running) {

      if (!running) {
        console.log('Server is not running.');
        process.exit(-1);
        
      } else {
        pid.kill('SIGTERM', function(err) {
          if (err) {
            console.error('Failed to kill the server process.');
          }
        });
      }
    });
    break;
  
  
  case 'status':
    
    // Let's quickly check if the server is already running.
    pid.running(function(err, running) {
      if (!running) {
        console.log('The server is NOT running.');
      } else {
        console.log('The server is running.');
      }
    });
    break;
  
  
  default:
    console.error('Usage: node cli.js [start] [stop] [status]');
}
