require 'net/http'

HTTP_TIMEOUT = 408

module HTTP_METHODS
  def post(url, request_headers, post_body = "")
    Timeout::timeout(HTTP_TIMEOUT) {
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri.request_uri)
      request_headers.each do |k, v|
        req.add_field(k, v)
      end
      req.body = post_body
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.request(req)
      headers = {}
      response.each { |key, val|
        headers[key] = val
      }
      [response.code, headers, response.body]
    }
  end

  def put(url, request_headers, post_body = "")
    Timeout::timeout(HTTP_TIMEOUT) {
      uri = URI.parse(url)
      req = Net::HTTP::Put.new(uri.request_uri)
      request_headers.each do |k, v|
        req.add_field(k, v)
      end
      req.body = post_body
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.request(req)
      headers = {}
      response.each { |key, val|
        headers[key] = val
      }
      [response.code, headers, response.body]
    }
  end

  def delete(url, request_headers, post_body = "")
    Timeout::timeout(HTTP_TIMEOUT) {
      uri = URI.parse(url)
      req = Net::HTTP::Delete.new(uri.request_uri)
      request_headers.each do |k, v|
        req.add_field(k, v)
      end
      req.body = post_body
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.request(req)
      headers = {}
      response.each { |key, val|
        headers[key] = val
      }
      [response.code, headers, response.body]
    }
  end

  def get(url, request_headers = {})
    Timeout::timeout(HTTP_TIMEOUT) {
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri.request_uri)
      request_headers.each do |k, v|
        req.add_field(k, v)
      end
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.request(req)
      headers = {}
      response.each { |key, val|
        headers[key] = val
      }
      [response.code, headers, response.body]
    }
  end
end