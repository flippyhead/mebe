(function() {
  var amazonS3, connect, fs, handleRequest, http, http_get, https, mime, qs, s3, settings, url;

  http = require('http');

  https = require('https');

  http_get = require('http-get');

  url = require('url');

  qs = require('querystring');

  fs = require('fs');

  amazonS3 = require('awssum-amazon-s3');

  mime = require('mime');

  connect = require('connect');

  settings = require('./settings');

  mime.define({
    'image/jpg': ['jpeg']
  });

  s3 = new amazonS3.S3({
    'accessKeyId': settings.amazon.access_key_id,
    'secretAccessKey': settings.amazon.secret_access_key,
    'region': amazonS3.US_WEST_2
  });

  handleRequest = function(req, res) {
    var azure_options, extension, filename, index, keyword, params, s3_options, search, uri;
    uri = url.parse(req.url);
    search = uri.pathname.replace(/^\//, '').split('.');
    keyword = search[0];
    extension = search[search.length - 1];
    index = Object.keys(req.query)[0] || 0;
    filename = "" + keyword + "-" + index + "." + extension;
    params = {
      $format: 'json',
      Query: "'" + (keyword.replace(/_/g, ' ')) + "'",
      Adult: "'Strict'"
    };
    azure_options = {
      host: settings.azure.host,
      port: settings.azure.ssl ? 443 : 80,
      path: "" + settings.azure.base_path + "?" + (qs.stringify(params)),
      headers: {
        "Authorization": "Basic " + new Buffer("" + settings.azure.api_key + ":" + settings.azure.api_key).toString("base64")
      }
    };
    s3_options = {
      BucketName: settings.amazon.bucket,
      ObjectName: filename
    };
    return s3.GetObject(s3_options, {
      stream: true
    }, function(error, data) {
      if (error) {
        return https.request(azure_options, function(api_res) {
          var str;
          str = '';
          api_res.on('data', function(chunk) {
            return str += chunk;
          });
          return api_res.on('end', function() {
            var ext, image_url, result;
            result = JSON.parse(str).d.results[index];
            if (!result) {
              res.writeHead(404, {
                'Content-Type': 'image/jpeg'
              });
              fs.createReadStream('public/404.jpeg').pipe(res);
              return;
            }
            image_url = result.Thumbnail.MediaUrl;
            ext = mime.extension(result.Thumbnail.ContentType);
            filename = "" + keyword + "-" + index + "." + ext;
            return http_get.get({
              url: image_url,
              stream: true
            }, function(error, image_res) {
              var length, s3_put_options;
              if (error) return console.error(error);
              length = image_res.headers['content-length'];
              s3_put_options = {
                BucketName: settings.amazon.bucket,
                ObjectName: filename,
                ContentLength: length,
                Body: image_res.stream
              };
              s3.PutObject(s3_put_options, function(err, data) {
                if (err) return console.log('** error putting S3 object:', err);
              });
              res.writeHead(200, {
                'Content-Type': 'image/jpeg'
              });
              image_res.stream.pipe(res);
              image_res.stream.on('end', function() {
                return res.end();
              });
              image_res.stream.on('close', function() {
                return res.end();
              });
              image_res.stream.on('error', function(error) {
                return console.log('** error getting image data:', error);
              });
              return image_res.stream.resume();
            });
          });
        }).end();
      } else {
        res.writeHead(200, {
          'Content-Type': 'image/jpeg'
        });
        data.Stream.pipe(res);
        return data.Stream.on('end', function() {
          return res.end;
        });
      }
    });
  };

  connect().use(connect.favicon()).use(connect.query()).use(connect.static('public')).use(connect.logger('dev')).use(handleRequest).listen(3000);

}).call(this);
