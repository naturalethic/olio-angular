require! \stylus
require! \nib
require! \jade
require! \regenerator
require! \browserify
require! \inflection
require! \livescript
require! \node-notifier
require! \watchify

concat-files = (list) -> list |> fold ((a, b) -> a + '\n' + fs.read-file-sync(b)), ''

_names = null
read-view-names = ->
  return _names if _names
  _names := glob.sync 'web/**/*.+(jade|ls|styl)'
  |> map -> it.replace(/^web\//, '').replace(/\.(jade|ls|styl)$/, '').replace(/\//g, '-')
  |> unique
  |> map ->
    parts = it.split('-')
    if parts.length > 1 and parts[parts.length - 2] in [(last parts), (inflection.singularize last parts)]
      return (parts.slice(0, parts.length - 2) ++ [ last parts ]).join '-'
    it
  # XXX: Always execute html first, if it exists, for setting up initializations and globals
  if \html in _names
    _names.splice _names.index-of \html
    _names := <[ html ]> ++ _names
  _names

view-file-for-name = (name, ext) ->
  parts = name.split('-')
  fname = take (parts.length - 1), parts
  lname = last parts
  sname = inflection.singularize lname
  paths =
    "web/#{parts.join('/')}.#ext"
    "web/#{fname.join('/')}/#sname/#lname.#ext"
    "web/#{fname.join('/')}/#lname/#lname.#ext"
  first (paths |> filter -> fs.exists-sync it)

read-template = ->
  path = view-file-for-name it, 'jade'
  (path and jade.render-file path) or ''

read-directive = ->
  path = view-file-for-name it, 'ls'
  (path and fs.read-file-sync("#{process.cwd!}/#path").to-string!) or ''

stitch-utilities = ->
  ls-utils =
    clone: 'function(it){\n  function fun(){} fun.prototype = it;\n  return new fun;\n}'
    extend: 'function(sub, sup){\n  function fun(){} fun.prototype = (sub.superclass = sup).prototype;\n  (sub.prototype = new fun).constructor = sub;\n  if (typeof sup.extended == \'function\') sup.extended(sub);\n  return sub;\n}'
    bind: 'function(obj, key, target){\n  return function(){ return (target || obj)[key].apply(obj, arguments) };\n}'
    'import': 'function(obj, src){\n  var own = {}.hasOwnProperty;\n  for (var key in src) if (own.call(src, key)) obj[key] = src[key];\n  return obj;\n}'
    importAll: 'function(obj, src){\n  for (var key in src) obj[key] = src[key];\n  return obj;\n}'
    repeatString: 'function(str, n){\n  for (var r = \'\'; n > 0; (n >>= 1) && (str += str)) if (n & 1) r += str;\n  return r;\n}'
    repeatArray: 'function(arr, n){\n  for (var r = []; n > 0; (n >>= 1) && (arr = arr.concat(arr)))\n    if (n & 1) r.push.apply(r, arr);\n  return r;\n}'
    'in': 'function(x, xs){\n  var i = -1, l = xs.length >>> 0;\n  while (++i < l) if (x === xs[i]) return true;\n  return false;\n}'
    out: 'typeof exports != \'undefined\' && exports || this'
    curry: 'function(f, bound){\n  var context,\n  _curry = function(args) {\n    return f.length > 1 ? function(){\n      var params = args ? args.concat() : [];\n      context = bound ? context || this : this;\n      return params.push.apply(params, arguments) <\n          f.length && arguments.length ?\n        _curry.call(context, params) : f.apply(context, params);\n    } : f;\n  };\n  return _curry();\n}'
    flip: 'function(f){\n  return curry$(function (x, y) { return f(y, x); });\n}'
    partialize: 'function(f, args, where){\n  var context = this;\n  return function(){\n    var params = slice$.call(arguments), i,\n        len = params.length, wlen = where.length,\n        ta = args ? args.concat() : [], tw = where ? where.concat() : [];\n    for(i = 0; i < len; ++i) { ta[tw[0]] = params[i]; tw.shift(); }\n    return len < wlen && len ?\n      partialize$.apply(context, [f, ta, tw]) : f.apply(context, ta);\n  };\n}'
    not: 'function(x){ return !x; }'
    compose: 'function() {\n  var functions = arguments;\n  return function() {\n    var i, result;\n    result = functions[0].apply(this, arguments);\n    for (i = 1; i < functions.length; ++i) {\n      result = functions[i](result);\n    }\n    return result;\n  };\n}'
    deepEq: 'function(x, y, type){\n  var toString = {}.toString, hasOwnProperty = {}.hasOwnProperty,\n      has = function (obj, key) { return hasOwnProperty.call(obj, key); };\n  var first = true;\n  return eq(x, y, []);\n  function eq(a, b, stack) {\n    var className, length, size, result, alength, blength, r, key, ref, sizeB;\n    if (a == null || b == null) { return a === b; }\n    if (a.__placeholder__ || b.__placeholder__) { return true; }\n    if (a === b) { return a !== 0 || 1 / a == 1 / b; }\n    className = toString.call(a);\n    if (toString.call(b) != className) { return false; }\n    switch (className) {\n      case \'[object String]\': return a == String(b);\n      case \'[object Number]\':\n        return a != +a ? b != +b : (a == 0 ? 1 / a == 1 / b : a == +b);\n      case \'[object Date]\':\n      case \'[object Boolean]\':\n        return +a == +b;\n      case \'[object RegExp]\':\n        return a.source == b.source &&\n               a.global == b.global &&\n               a.multiline == b.multiline &&\n               a.ignoreCase == b.ignoreCase;\n    }\n    if (typeof a != \'object\' || typeof b != \'object\') { return false; }\n    length = stack.length;\n    while (length--) { if (stack[length] == a) { return true; } }\n    stack.push(a);\n    size = 0;\n    result = true;\n    if (className == \'[object Array]\') {\n      alength = a.length;\n      blength = b.length;\n      if (first) {\n        switch (type) {\n        case \'===\': result = alength === blength; break;\n        case \'<==\': result = alength <= blength; break;\n        case \'<<=\': result = alength < blength; break;\n        }\n        size = alength;\n        first = false;\n      } else {\n        result = alength === blength;\n        size = alength;\n      }\n      if (result) {\n        while (size--) {\n          if (!(result = size in a == size in b && eq(a[size], b[size], stack))){ break; }\n        }\n      }\n    } else {\n      if (\'constructor\' in a != \'constructor\' in b || a.constructor != b.constructor) {\n        return false;\n      }\n      for (key in a) {\n        if (has(a, key)) {\n          size++;\n          if (!(result = has(b, key) && eq(a[key], b[key], stack))) { break; }\n        }\n      }\n      if (result) {\n        sizeB = 0;\n        for (key in b) {\n          if (has(b, key)) { ++sizeB; }\n        }\n        if (first) {\n          if (type === \'<<=\') {\n            result = size < sizeB;\n          } else if (type === \'<==\') {\n            result = size <= sizeB\n          } else {\n            result = size === sizeB;\n          }\n        } else {\n          first = false;\n          result = size === sizeB;\n        }\n      }\n    }\n    stack.pop();\n    return result;\n  }\n}'
    split: "''.split"
    replace: "''.replace"
    toString: '{}.toString'
    join: '[].join'
    slice: '[].slice'
    splice: '[].splice'
  util-js = []
  for key in keys(ls-utils)
    util-js.push "window.#key\$ = #{ls-utils[key]}"
  info 'Writing    -> tmp/utilities.js'
  fs.write-file-sync \tmp/utilities.js, util-js.join '\n'

olio.config.web ?= {}
olio.config.web.app ?= 'test'
olio.config.web.modules ?= {}

client-api-script = ->
  client-script = [
    """
      angular.module '#{olio.config.web.app}'
      .run ($http) ->
    """
  ]
  apis = require-dir \api
  keys apis
  |> map (module-name) ->
    for api-name in keys apis[module-name]
      api = apis[module-name][api-name]
      if signature = (typeof! api == 'Array' and first(api |> filter -> typeof! it == 'Object'))
        signature = {} <<< signature
        extra-validators = {} <<< (delete signature.validate) or {}
        for key, val of extra-validators
          if /^function\*/.test val.to-string!
            extra-validators[key] = false
          else
            extra-validators[key] = val.to-string!
        for key of signature
          signature[key] = { -optional } <<< signature[key]
        client-script.push "  api._add '#module-name', '#api-name', #{JSON.stringify signature}, #{JSON.stringify extra-validators}"
      else
        client-script.push "  api._add '#module-name', '#api-name'"
  flatten(client-script).join('\n')

stitch-scripts = ->
  script = ["""
    require! './utilities'
    window.$ = require 'jquery'
    window.jQuery = require 'jquery'
    require! 'angular'
    angular.module '#{olio.config.web.app}', [
  """]
  if (keys olio.config.web.modules).length
    script.push """'#{(keys olio.config.web.modules).join("', '")}'"""
  script.push "]"
  script ++= [
    fs.read-file-sync('node_modules/olio-angular/script.ls').to-string!replace(/NG\-APPLICATION/g, olio.config.web.app).replace(/OLIO\-API\-ROOT/g, olio.config.api.root)
    client-api-script!
    ((fs.exists-sync 'web/html.ls') and (fs.read-file-sync 'web/html.ls').to-string!) or ''
    "require './index.css'"
  ]
  script = script.join '\n'
  script = [
    livescript.compile script, { header: false, bare: true }
  ]
  validate = require '../../olio-api/validate'
  f = validate.to-string!replace(/^function\*/, 'function').replace(/yield\sthis._validator/, 'this._validator')
  script.push "window.validate = #f;"
  for name, func of validate
    script.push "validate.#name = #{func.to-string!};\n"
  info 'Writing    -> tmp/index.js'
  fs.write-file-sync \tmp/index.js, regenerator.compile(script.join('\n'), include-runtime: true).code

stitch-styles = ->*
  promisify-all stylus!__proto__
  source = []
  read-view-names! |> each ->
    return if !path = view-file-for-name it, 'styl'
    source.push(fs.read-file-sync(path).to-string!)
  # source.push concat-files glob.sync 'web/**/*.styl'
  css = yield stylus(source.join '\n').use(nib()).import("nib").render-async!
  info 'Writing    -> tmp/index.css'
  fs.write-file-sync \tmp/index.css, css

stitch-templates = ->
  script = [
    "angular.module('#{olio.config.web.app}').run ($template-cache) ->"
  ]
  read-view-names! |> each ->
    return if not template = read-template it
    if it is \html
      info 'Writing    -> public/index.html'
      return fs.write-file-sync \public/index.html, template
    script.push """  $template-cache.put '#{it}', \'\'\'#{template.trim!}\'\'\'"""
  info 'Writing    -> tmp/template.js'
  fs.write-file-sync \tmp/template.js, (livescript.compile script.join('\n'))

stitch-directives = ->
  script = [
  ]
  read-view-names! |> each ->
    return if it in <[ html ]>
    directive = read-directive it
    source = []
    source.push """
      {
        restrict: 'A'
    """
    source.push "  template-url: '#it'" if read-template it
    source.push "} <<< {\n  #{directive.replace(/\n/g, '\n  ').trim!}\n}"
    source = livescript.compile source.join('\n'), { +bare }
    directive = eval source
    source = [
      "angular.module('#{olio.config.web.app}').directive('#{camelize it}', function ($compile, $parse, $timeout) {"
      "  return {"
    ]
    for k in keys directive
      if typeof! directive[k] != \Function
        source.push "    #k: #{JSON.stringify directive[k]},"
        delete directive[k]
    for k, v of directive
      vs = v.to-string!split('\n').join('\n      ').trim!
      if m = vs.match /^function\* \((.*)\){\n([^]*)/
        vs = vs.substring 0, vs.length - 1
        args = m.1.split(',') |> map -> it.trim!
        vs = vs.replace m.1, ''
        source.push """    #k: function (#{args.join(', ')}){\n      co.wrap(#{vs}})();\n    },"""
      else
        source.push "    #k: #{v.to-string!split('\n').join('\n  ')},"
    source.push '  }\n});'
    source = source.join('\n')
    script.push source
  info 'Writing    -> tmp/directive.js'
  fs.write-file-sync \tmp/directive.js, regenerator.compile(script.join('\n'), include-runtime: false).code

bundler = null

setup-bundler = ->
  glob.sync 'web/**/*.!(ls|jade|styl)'
  |> each ->
    path = "tmp/#{/web\/(.*)/.exec(it).1}"
    exec "mkdir -p #{fs.path.dirname path}"
    exec "cp #it #path"
  no-parse = []
  try
    no-parse.push require.resolve("#{process.cwd!}/node_modules/jquery")
  b = browserify <[ ./tmp/index.js ]>, {
    paths: <[ ./node_modules/olio-angular/node_modules ]>
    no-parse: no-parse
    detect-globals: false
    cache: {}
    package-cache: {}
  }
  bundler := watchify b
  bundler.transform (require \debowerify)
  # .transform (require \browserify-ngannotate)
  .transform (require \browserify-css), {
    auto-inject-options: { verbose: false }
    process-relative-url: (url) ->
      path = /([^\#\?]*)/.exec(url).1
      base = fs.path.basename path
      exec "cp #path public/#base"
      "#base"
  }
  bundler.on \update, ->
    bundle!

bundle = ->
  info 'Browserify -> public/index.js'
  bundler.bundle!
  .pipe fs.create-write-stream 'tmp/bundle.js'
  .on 'finish', ->
    exec 'cp tmp/bundle.js public/index.js'
    info "--- Done in #{(Date.now! - time) / 1000} seconds ---"
    node-notifier.notify title: (inflection.capitalize olio.config.web.app), message: "Site Rebuilt: #{(Date.now! - time) / 1000}s"
    process.exit 0 if olio.option.exit

time = null

build = (what) ->*
  try
    time := Date.now!
    switch what
    | \styles   => yield stitch-styles!
    | otherwise =>
      stitch-templates!
      stitch-directives!
      yield stitch-styles!
    stitch-scripts!
  catch e
    info e

export web = ->*
  exec "mkdir -p tmp"
  exec "mkdir -p public"
  setup-bundler!
  stitch-utilities!
  watcher.watch <[ validate.ls olio.ls host.ls web ]>, persistent: true, ignore-initial: true .on 'all', (event, path) ->
    info "Change detected in '#path'..."
    if /styl$/.test path
      co build \styles
    else
      co build
  co build
  .then bundle
