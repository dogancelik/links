gulp = require 'gulp'
connect = require 'gulp-connect'
concat = require 'gulp-concat'
coffee = require 'gulp-coffee'
jade = require 'gulp-pug'
stylus = require 'gulp-stylus'
autoprefixer = require 'gulp-autoprefixer'
rename = require 'gulp-rename'
cleanCSS = require 'gulp-clean-css'
sourcemaps = require 'gulp-sourcemaps'
uglify = require 'gulp-uglify-es'
ngAnnotate = require 'gulp-ng-annotate'
# ignore = require 'gulp-ignore'
# rimraf = require 'gulp-rimraf'

pathJade = 'src/**/*.jade'
pathStylus = 'src/**/*.styl'
pathCoffee = 'src/*.coffee'
dirWatch = 'src/**/**'
dirDist = process.env.BUILD ? 'build'

appJs = [
  'src/js/utils.coffee'
  'src/js/typeahead.coffee'
  'src/js/app.coffee'
]

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

html = ->
  gulp
    .src pathJade
    .pipe jade()
    .pipe gulp.dest(dirDist)

copy = ->
  gulp
    .src 'src/copy/**'
    .pipe gulp.dest(dirDist)

rm_css = ->
  gulp
    .src "#{dirDist}/*.css*"
    .pipe rimraf()

css = ->
  gulp
    .src pathStylus
    .pipe sourcemaps.init()
    .pipe stylus()
    .pipe autoprefixer()
    .pipe gulp.dest(dirDist)
    .pipe cleanCSS()
    .pipe rename(suffix: '.min')
    .pipe sourcemaps.write('.')
    .pipe gulp.dest(dirDist)

js = ->
  gulp
    .src appJs
    .pipe sourcemaps.init()
    .pipe coffee(bare: true)
    .pipe ngAnnotate()
    .pipe concat('index.js')
    .pipe gulp.dest(dirDist)
    .pipe uglify.default()
    .pipe concat('index.min.js')
    .pipe sourcemaps.write('.')
    .pipe gulp.dest(dirDist)
    .pipe connect.reload()

vendor_min = ->
  gulp
    .src vendorJs
    .pipe concat('vendor.min.js')
    .pipe gulp.dest(dirDist)

vendor = ->
  gulp
    .src vendorJs.map((i) -> i.replace('.min', ''))
    .pipe concat('vendor.js')
    .pipe gulp.dest(dirDist)

exports.default = gulp.series(html, css, copy, js, vendor, vendor_min)

watch = ->
  gulp.watch dirWatch, exports.default

serve = ->
  connect.server root: 'build', livereload: true

exports.watch = gulp.parallel(watch, serve)
