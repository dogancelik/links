gulp = require 'gulp'
connect = require 'gulp-connect'
concat = require 'gulp-concat'
jade = require 'gulp-jade'

pathJade = 'src/**/*.jade'
dirSrc = 'src/**/**'
dirDist = process.env.BUILD ? 'build'

vendorJs = [
  'bower_components/jquery/dist/jquery.min.js'
  'bower_components/angular/angular.min.js'
  'bower_components/angular-route/angular-route.min.js'
  'bower_components/ngstorage/ngStorage.min.js'
  'bower_components/angular-cache/dist/angular-cache.min.js'
  'bower_components/typeahead.js/dist/typeahead.bundle.min.js'
  'bower_components/bootstrap/dist/js/bootstrap.min.js'
  'bower_components/js-yaml/dist/js-yaml.min.js'
]

gulp.task 'main', ->
  gulp
    .src pathJade
    .pipe jade(pretty: true)
    .pipe gulp.dest(dirDist)
    .pipe(connect.reload())

  gulp
    .src [dirSrc, '!' + pathJade]
    .pipe gulp.dest(dirDist)
    .pipe(connect.reload())

gulp.task 'vendor', ->
  gulp
    .src(vendorJs)
    .pipe(concat('vendor.min.js'))
    .pipe(gulp.dest(dirDist))
    .pipe(connect.reload())

gulp.task 'watch', ['default'], -> gulp.watch dirSrc, ['default']

gulp.task 'default', ['main', 'vendor']

gulp.task 'serve', -> connect.server root: 'build', livereload: true
