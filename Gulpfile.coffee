gulp = require 'gulp'
concat = require 'gulp-concat'

dirDist = '../links-js.github.io'

vendorJs = [
  'bower_components/jquery/dist/jquery.min.js'
  'bower_components/angular/angular.min.js'
  'bower_components/ngstorage/ngStorage.min.js'
  'bower_components/angular-cache/dist/angular-cache.min.js'
  'bower_components/typeahead.js/dist/typeahead.bundle.min.js'
  'bower_components/bootstrap/dist/js/bootstrap.min.js'
  'bower_components/js-yaml/dist/js-yaml.min.js'
]

gulp.task 'main', ->
  gulp
    .src('src/**/*.*')
    .pipe(gulp.dest(dirDist))

gulp.task 'vendor', ->
  gulp
    .src(vendorJs)
    .pipe(concat('vendor.min.js'))
    .pipe(gulp.dest(dirDist))

gulp.task 'default', ['main', 'vendor']