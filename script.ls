require 'core-js'
window.inflection = require \inflection
window.co = require \co
window <<< require 'prelude-ls'
if console.log.apply
  <[ log info warn error ]> |> each (key) -> window[key] = -> console[key] ...&
else
  <[ log info warn error ]> |> each (key) -> window[key] = console[key]
# require  './utils'
# require! 'angular'
# angular.module 'NG-APPLICATION', [
#   #{(olio.config.angular.modules |> map -> "'#it'").join ', '}
# ]
require './template'
require './directive'

window.cache =
  set: (...args) -> local-storage.set-item ...args
  get: (...args) -> local-storage.get-item ...args
  del: (...args) -> local-storage.remove-item ...args

re-uuid = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
re-date = /^\d{4}\-\d{2}\-\d{2}T/
re-duration = /^P((([0-9]*\.?[0-9]*)Y)?(([0-9]*\.?[0-9]*)M)?(([0-9]*\.?[0-9]*)W)?(([0-9]*\.?[0-9]*)D)?)?(T(([0-9]*\.?[0-9]*)H)?(([0-9]*\.?[0-9]*)M)?(([0-9]*\.?[0-9]*)S)?)?$/
transform-dates = (obj) ->
  switch typeof! obj
  | 'Array'   => (obj |> each transform-dates); obj
  | 'Object'  => ((keys obj) |> each -> obj[it] = transform-dates obj[it]); obj
  | 'String'  =>
    if re-date.test obj
      moment(obj)
    else if re-duration.test obj
      moment.duration(obj)
    else
      obj
  | otherwise => obj

angular.module 'NG-APPLICATION'
.run ($root-scope) ->
  $root-scope.on = (e, l) ->
    l = co.wrap(l) if /^function callee/.test l.to-string!
    ll = (...args) -> l ...args
    @$on e, ll
  $root-scope.watch = (e, l, f) ->
    l = co.wrap(l) if /^function callee/.test l.to-string!
    ll = (n, o) ->
      return if n == undefined
      l n, o
    @$watch (camelize e), ll, f
  $root-scope.watch-group = (e, l) ->
    l = co.wrap(l) if /^function callee/.test l.to-string!
    ll = (n, o) ->
      return if (n |> filter -> it != undefined).length != n.length
      l n, o
    @$watch-group (e |> map -> camelize it), ll
  $root-scope.watch-collection = (e, l, f) ->
    l = co.wrap(l) if /^function callee/.test l.to-string!
    ll = (n, o) ->
      return if n == undefined
      l n, o
    @$watch-collection (camelize e), ll, f

angular.module 'NG-APPLICATION'
.run ($http) ->
  invoke = (module, name) ->
    (data, extra-validators) ->
      invoke.count += 1
      count = invoke.count
      if typeof! data == 'Array'
        data = data |> map -> {} <<<< it
      else
        data = {} <<<< data
      request                         = { data: data, headers: {} }
      # --- APPLICATION SPECIFIC ABSTRACT THIS ---
      request.headers['X-Token']      = cache.get 'token'  if (cache.get 'token') and re-uuid.test(cache.get 'token')
      request.headers['X-Person']     = cache.get 'person' if (cache.get 'person') and re-uuid.test(cache.get 'person')
      request.headers['X-Route']      = state.route
      # ------------------------------------------
      request.headers['Content-Type'] = 'application/json'
      request.headers['Accept']       = 'application/json'
      request.method                  = 'put'
      request.url                     = 'OLIO-API-ROOT/' + module
      request.url                    += '/' + name if name
      data = pairs-to-obj(obj-to-pairs(data) |> (filter -> it.1 != undefined))
      log-data = {} <<<< data
      log-data.secret = '********' if log-data.secret
      log-data.secret-repeat = '********' if log-data.secret-repeat
      info "API[#count] > " + request.url.substr('OLIO-API-ROOT'.length + 1), '', log-data
      if (signature = if name then api[module][name].signature else api[module].signature)
        invalid = validate data, signature, null, extra-validators
      if (keys invalid).length
        info "API[#count*] < #{request.url.substr('OLIO-API-ROOT'.length + 1)}", 403, invalid
        obj =
          success: -> obj
          error: -> obj
          invalid: -> it invalid; obj
        return obj
      request.transform-response = (data) ->
        try
          data = JSON.parse data
          data = transform-dates data
        data
      for key, val of data
        if val._d
          data[key] = val.format!
      api.loading += 1
      r = $http request
      .success (data, status, headers, config) ->
        # --- APPLICATION SPECIFIC ABSTRACT THIS ---
        cache.set 'token', headers('X-Token') if headers('X-Token')
        # ------------------------------------------
        r._data = data
        r._data = null if status == 204
        r._status = status
        api.loading -= 1
        info "API[#count] < #{request.url.substr('OLIO-API-ROOT'.length + 1)}", status, data
      .error (data, status, headers, config) ->
        r._data = data
        r._data = null if status == 204
        r._status = status
        api.loading -= 1
        info "API[#count] < #{request.url.substr('OLIO-API-ROOT'.length + 1)}", status, data
        r._invalid data if r._invalid and status == 403
      .then -> r._data
      r.success = (f) -> (r.then -> f r._data); r
      r.error   = (f) ->
        r.then (->), ->
          f r._data, r._status
        r
      r.invalid = -> r._invalid = it; r
      r
  invoke.count = 0
  window.api =
    root: \OLIO-API-ROOT
    loading: 0
    _ready: false
    _add: (module, name, signature, extra-validators) ->
      if not api[module]
        api[module] = {}
      if name in [ module, inflection.pluralize(module) ]
        api[name] = invoke name
        api[name].signature = signature
        api[name].extra-validators = extra-validators
      else
        api[module][name] = invoke module, name
        api[module][name].signature = signature
        api[module][name].extra-validators = extra-validators
