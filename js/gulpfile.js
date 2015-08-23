var exec = require('child_process').execSync;
var fs = require('fs');
var gulp = require('gulp');
var replace = require('gulp-replace');
var rename = require('gulp-rename');

gulp.task('build', function () {
  exec('haxe js/build.hxml', { cwd: '../' });
});

gulp.task('inject', ['build'], function () {
  var file = fs.readFileSync('leveled-parser.js');

  gulp.src('template.js')
    .pipe(replace('/** MODULE **/', file))
    // HACK: Override haxe module export
    .pipe(replace('typeof window != "undefined" ? window : exports', 'exportObject'))
    .pipe(rename('main.js'))
    .pipe(gulp.dest('./'));
});
