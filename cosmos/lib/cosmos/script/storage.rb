# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'net/http'

module Cosmos
  module Script
    private

    # Get a handle to access a target file
    #
    # @param path [String] Path to a file in a target directory
    # @param binary [Boolean] Whether the file is binary or not
    # @return [Hash|nil]
    def get_target_file(path, original: false, scope: $cosmos_scope)
      # Create Tempfile to store data
      file = Tempfile.new('target', binmode: true)

      # Get presigned url
      if original
        part = "targets"
      else
        part = "targets_modified"
      end
      # Loop to allow redo
      loop do
        endpoint = "/cosmos-api/storage/download/#{scope}/#{part}/#{path}"
        Cosmos::Logger.info "Reading #{scope}/#{part}/#{path}"
        if $cosmos_in_cluster
          response = $api_server.request('get', endpoint, query: {bucket: 'config', internal: true})
        else
          response = $api_server.request('get', endpoint, query: {bucket: 'config'})
        end
        if response.nil? || response.code != 201
          Cosmos::Logger.error "Failed Get Presigned URL for #{scope}/#{part}/#{path}"
          if part == "targets_modified"
            part = "targets"
            redo
          else
            raise "#{path} not found"
          end
        end
        result = JSON.parse(response.body)

        # Try to get the file
        begin
          if $cosmos_in_cluster
            uri = URI.parse("http://cosmos-minio:9000" + result['url'])
          else
            uri = URI.parse($api_server.generate_url + result['url'])
          end
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Get.new uri

            http.request request do |response|
              response.read_body do |chunk|
                puts chunk.length
                file.write chunk
              end
            end
            file.rewind
          end
          return file
        rescue => error
          Cosmos::Logger.info("#{scope}/#{part}/#{path} not found")
          if part == "targets_modified"
            part = "targets"
            redo
          else
            raise "#{path} not found"
          end
        end
        break
      end
    end

    # Get a handle to write a target file
    #
    # @param path [String] Path to a file in a target directory
    # @param io_or_string [Io or String] IO object
    def put_target_file(path, io_or_string, scope: $cosmos_scope)
      # Get presigned url
      part = "targets_modified"
      begin
        endpoint = "/cosmos-api/storage/upload/#{scope}/#{part}/#{path}"
        Cosmos::Logger.info "Writing #{scope}/#{part}/#{path}"
        if $cosmos_in_cluster
          response = $api_server.request('get', endpoint, query: {bucket: 'config', internal: true})
        else
          response = $api_server.request('get', endpoint, query: {bucket: 'config'})
        end
        if response.nil? || response.code != 201
          Cosmos::Logger.error "Failed Get Presigned URL for #{scope}/#{part}/#{path}"
          return nil
        end
        result = JSON.parse(response.body)

        # Try to put the file
        success = false
        begin
          if $cosmos_in_cluster
            uri = URI.parse("http://cosmos-minio:9000" + result['url'])
          else
            uri = URI.parse($api_server.generate_url + result['url'])
          end
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Put.new(uri, {'Content-Length' => io_or_string.length.to_s})
            if String === io_or_string
              request.body = io_or_string
            else
              request.body_stream = io_or_string
            end
            result = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
              http.request(request)
            end
            return result
          end
        rescue => error
          raise "Failed to write #{scope}/#{part}/#{path}"
        end
      end
      nil
    end

    # Delete a file on a target
    #
    # @param [String] Path to a file in a target directory
    def delete_target_file(path, scope: $cosmos_scope)
      begin
        # Only delete from the targets_modified
        endpoint = "/cosmos-api/storage/delete/#{scope}/targets_modified/#{path}"
        Cosmos::Logger.info "Deleting #{scope}/targets_modified/#{path}"
        response = $api_server.request('delete', endpoint, query: {bucket: 'config'})
        if response.nil? || response.code != 200
          raise "Failed to delete #{scope}/targets_modified/#{path}"
        end
      rescue => error
        raise "Failed deleting #{path} due to #{error.message}"
      end
      nil
    end
  end
end
