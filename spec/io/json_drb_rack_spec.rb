  # encoding: ascii-8bit

  # Copyright 2014 Ball Aerospace & Technologies Corp.
  # All Rights Reserved.
  #
  # This program is free software; you can modify and/or redistribute it
  # under the terms of the GNU General Public License
  # as published by the Free Software Foundation; version 3 with
  # attribution addendums as found in the LICENSE.txt

  require 'spec_helper'
  require 'cosmos/io/json_drb_rack'

  module Cosmos

    describe JsonDrbRack do
      before(:each) do
        @env = {
          "GATEWAY_INTERFACE" => "CGI/1.1",
          "PATH_INFO" => "/index.html",
          "QUERY_STRING" => "",
          "REMOTE_ADDR" => "::1",
          "REMOTE_HOST" => "localhost",
          "REQUEST_METHOD" => "POST",
          "REQUEST_URI" => "http://localhost:3000/index.html",
          "SCRIPT_NAME" => "",
          "SERVER_NAME" => "localhost",
          "SERVER_PORT" => "3000",
          "SERVER_PROTOCOL" => "HTTP/1.1",
          "SERVER_SOFTWARE" => "WEBrick/1.3.1 (Ruby/2.0.0/2013-11-22)",
          "HTTP_HOST" => "127.0.0.1:7777",
          "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:26.0) Gecko/20100101 Firefox/26.0",
          "HTTP_ACCEPT" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "HTTP_ACCEPT_LANGUAGE" => "zh-tw,zh;q=0.8,en-us;q=0.5,en;q=0.3",
          "HTTP_ACCEPT_ENCODING" => "gzip, deflate",
          "HTTP_COOKIE" => "jsonrpc.session=3iqp3ydRwFyqjcfO0GT2bzUh.bacc2786c7a81df0d0e950bec8fa1a9b1ba0bb61",
          "HTTP_CONNECTION" => "keep-alive",
          "HTTP_CACHE_CONTROL" => "max-age=0",
          "rack.version" => [1, 2],
          "rack.input" => StringIO.new(""),
          "rack.errors" => nil,
          "rack.multithread" => true,
          "rack.multiprocess" => false,
          "rack.run_once" => false,
          "rack.url_scheme" => "http",
          "HTTP_VERSION" => "HTTP/1.1",
          "REQUEST_PATH" => "/index.html"
        }
      end

      class MockDRb
        class MockDRbAcl
          def initialize(val = true)
            @val = val
          end
          def allow_addr?(val)
            return @val
          end
        end

        def initialize(val, response_data = "response", error_code = nil)
          @acl = MockDRbAcl.new(val)
          @response_data = response_data
          @error_code = error_code
        end

        def acl
          @acl
        end

        def process_request(request_data, start_time)
          return @response_data, @error_code
        end
      end

      class MockSystem
        def initialize(token = 'SuperSecret', hosts = ['127.0.0.1:7777'], origins = [])
          @token = token
          @hosts = hosts
          @origins = origins
        end
        def x_csrf_token
          @token
        end
        def allowed_hosts
          @hosts
        end
        def allowed_origins
          @origins
        end
      end

      describe "call" do
        it "supports the drb acl" do
          json_drb_rack = JsonDrbRack.new(MockDRb.new(false), MockSystem.new)
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 403
          expect(type).to eql({'Content-Type' => "text/plain"})
          expect(body_array).to eql ["Forbidden"]
        end

        it "handles X-Csrf-Token" do
          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess'))
          @env['HTTP_X_CSRF_TOKEN'] = 'TryToGuess'
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 403
          expect(type).to eql({'Content-Type' => "text/plain"})
          expect(body_array).to eql ["Forbidden: Bad X-Csrf-Token: #{@env['HTTP_X_CSRF_TOKEN']}"]

          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess'))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 200
          expect(type).to eql({'Content-Type' => "application/json-rpc"})
          expect(body_array).to eql ["response"]
        end

        it "Handles Allowed Hosts" do
          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess'))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          @env['HTTP_HOST'] = "5.6.7.8:7777"
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 403
          expect(type).to eql({'Content-Type' => "text/plain"})
          expect(body_array).to eql ["Forbidden: #{@env['HTTP_HOST']} not in allowed hosts"]

          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess', ['5.6.7.8:7777']))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          @env['HTTP_HOST'] = "5.6.7.8:7777"
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 200
          expect(type).to eql({'Content-Type' => "application/json-rpc"})
          expect(body_array).to eql ["response"]
        end

        it "Handles Allowed Origins" do
          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess'))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          @env['HTTP_ORIGIN'] = "5.6.7.8:7777"
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 403
          expect(type).to eql({'Content-Type' => "text/plain"})
          expect(body_array).to eql ["Forbidden: #{@env['HTTP_ORIGIN']} not in allowed origins"]

          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess', ['127.0.0.1:7777'], ['3.6.7.8:7777']))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          @env['HTTP_ORIGIN'] = "3.6.7.8:7777"
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 200
          expect(type).to eql({'Content-Type' => "application/json-rpc"})
          expect(body_array).to eql ["response"]
        end

        it "Only accepts posts" do
          json_drb_rack = JsonDrbRack.new(MockDRb.new(true), MockSystem.new('NeverGuess'))
          @env['HTTP_X_CSRF_TOKEN'] = 'NeverGuess'
          @env["REQUEST_METHOD"] = "GET"
          status, type, body_array = json_drb_rack.call(@env)
          expect(status).to eql 405
          expect(type).to eql({'Content-Type' => "text/plain"})
          expect(body_array).to eql ["Request not allowed"]
        end

      end
    end
  end
