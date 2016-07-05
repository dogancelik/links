gulp = require 'gulp'
connect = require 'gulp-connect'
concat = require 'gulp-concat'
coffee = require 'gulp-coffee'
jade = require 'gulp-jade'
stylus = require 'gulp-stylus'
autoprefixer = require 'gulp-autoprefixer'
rename = require 'gulp-rename'
cleanCSS = require 'gulp-clean-css'
sourcemaps = require 'gulp-sourcemaps'
uglify = require 'gulp-uglify'
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

gulp.task 'html', ->
  gulp
    .src pathJade
    .pipe jade()
    .pipe gulp.dest(dirDist)

gulp.task 'copy', ->
  gulp
    .src 'src/copy/**'
    .pipe gulp.dest(dirDist)

gulp.task 'rm-css', ->
  gulp
    .src "#{dirDist}/*.css*"
    .pipe rimraf()

gulp.task 'css', ->
  gulp
    .src pathStylus
    .pipe sourcemaps.init()
    .pipe stylus()
    .pipe autoprefixer(browsers: ['last 5 versions'])
    .pipe cleanCSS()
    .pipe rename(suffix: '.min')
    .pipe sourcemaps.write('.')
    .pipe gulp.dest(dirDist)

gulp.task 'js', ->
  gulp
    .src appJs
    .pipe sourcemaps.init()
    .pipe coffee(bare: true)
    .pipe ngAnnotate()
    .pipe uglify()
    .pipe concat('index.min.js')
    .pipe sourcemaps.write('.')
    .pipe gulp.dest(dirDist)
    .pipe connect.reload()

gulp.task 'vendor', ->
  gulp
    .src vendorJs
    .pipe concat('vendor.min.js')
    .pipe gulp.dest(dirDist)

gulp.task 'watch', ['default'], -> gulp.watch dirWatch, ['default']

gulp.task 'default', ['html', 'css', 'copy', 'js', 'vendor']

gulp.task 'serve', -> connect.server root: 'build', livereload: true
