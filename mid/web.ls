require! \mime

cache = {}

module.exports = (next) ->*
  if @headers.accept and !/json/.test @headers.accept
    path = @url.split(\?).0
    if /\./.test "public#path" and fs.exists-sync "public#path"
      @log path, \FETCHWEB, \green if @log
    else
      if not fs.exists-sync "public/index.html"
        @log path, \NOTFOUND, \green
        @response.body = 'Not Found'
        @response.code = 404
        return
      @log "#path not found, sending index", \FETCHWEB, \green if @log
      path = "/index.html"
    cache[path] ?= fs.read-file-sync "public#path" .to-string!
    @response.type = mime.lookup path
    @response.body = cache[path]
    @response.code = 200
    return
  yield next
