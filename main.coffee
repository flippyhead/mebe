# main
http_get = require 'http-get'
googleImages = require 'google-images'
request = require 'request'
url = require 'url'
qs = require 'querystring'
fs = require 'fs'
AWS = require 'aws-sdk'
mime = require 'mime'
connect = require 'connect'
settings = require './settings'
failed = true

mime.define 'image/jpg': ['jpeg']

s3 = new AWS.S3(params: {Bucket: settings.amazon.bucket})
AWS.config.region = 'us-east-1'

handleRequest = (req, res)->
  uri = url.parse req.url
  search = uri.pathname.replace(/^\//, '').split('.')
  keyword = search[0]
  extension = search[search.length-1]
  index = Object.keys(req.query)[0] or 0
  filename = "#{keyword}-#{index}.#{extension}"
  params = {Key: filename}
  failed = false

  client = googleImages settings.google.engine_id, settings.google.api_key

  client.search("'#{keyword.replace(/_/g, ' ')}'")
    .then((results) ->
      result = results[index or 0]
      imageUrl = result.url
      ext = mime.extension 'image/jpeg'
      filename = "#{keyword}-#{index}.#{ext}"
      request(imageUrl).pipe(res)
    ).catch( (error) -> # no image found
      console.log error
      res.writeHead(404, 'Content-Type': 'image/jpeg')
      fs.createReadStream('public/404.jpeg').pipe res
    )

connect()
  .use(connect.favicon())
  .use(connect.query())
  .use(connect.static 'public')
  .use(connect.logger 'dev')
  .use(handleRequest)
.listen(8080)