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

class StorageController < ApplicationController
  BUCKET_NAME = 'userdata'

  def get_download_presigned_request
    begin
      authorize(permission: 'system', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end

    render :json => get_presigned_request(:get_object), :status => 201
  end

  def get_upload_presigned_request
    begin
      authorize(permission: 'system_set', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end

    result = get_presigned_request(:put_object)
    Cosmos::Logger.info("S3 upload presigned request generated: #{params[:bucket] || BUCKET_NAME}/#{params[:object_id]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
    render :json => result, :status => 201
  end

  def delete
    begin
      authorize(permission: 'system_set', scope: params[:scope], token: request.headers['HTTP_AUTHORIZATION'])
    rescue Cosmos::AuthError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 401) and return
    rescue Cosmos::ForbiddenError => e
      render(:json => { :status => 'error', :message => e.message }, :status => 403) and return
    end

    rubys3_client = Aws::S3::Client.new
    result = rubys3_client.delete_object(bucket: params[:bucket], key: params[:object_id])

    Cosmos::Logger.info("Deleted: #{params[:bucket] || BUCKET_NAME}/#{params[:object_id]}", scope: params[:scope], user: user_info(request.headers['HTTP_AUTHORIZATION']))
    render :json => result, :status => 200
  end

  # private
  def get_presigned_request(method)
    bucket = params[:bucket]
    bucket ||= BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    begin
      rubys3_client.head_bucket(bucket: bucket)
    rescue Aws::S3::Errors::NotFound
      rubys3_client.create_bucket(bucket: bucket)
    end
    s3_presigner = Aws::S3::Presigner.new

    url, headers = s3_presigner.presigned_request(
      method, bucket: bucket, key: params[:object_id]
    )
    {
      :url => '/files/' + url.split('/')[3..-1].join('/'),
      :headers => headers,
      :method => method.to_s.split('_')[0],
    }
  end
end
