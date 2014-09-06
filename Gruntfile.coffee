module.exports = (grunt) ->

  config =
    pkg: (grunt.file.readJSON('package.json'))

    coffeelint:
      options:
        configFile: 'coffeelint.json'
      daemonpid: ['src/**/*.coffee', 'test/**/*.coffee']

    coffee:
      daemonpid:
        expand: true,
        flatten: false,
        cwd: 'src',
        src: ['.//**/*.coffee'],
        dest: 'dist',
        ext: '.js'
      test:
        expand: true,
        flatten: false,
        cwd: 'test',
        src: ['./**/*.coffee'],
        dest: 'test',
        ext: '.js'
        
    watch:
      files: ['src/**/*.coffee', 'test/**/*.coffee'],
      tasks: ['test']
      configFiles:
        files: ['Gruntfile.coffee']
        options:
          reload: true
          
    mochaTest:
      options:
        reporter: 'spec'
      src: ['test/**/*.js']

    clean:
      all: ['dist', 'test/**/*.js']
  
  grunt.initConfig(config)
  
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-mocha-test')
  grunt.loadNpmTasks('grunt-contrib-clean')

  grunt.registerTask('compile', ['coffeelint', 'clean', 'coffee']);
  grunt.registerTask('test', ['compile', 'mochaTest']);
