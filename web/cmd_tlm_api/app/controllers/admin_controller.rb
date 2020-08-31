class AdminController < ApplicationController
  Aws.config.update(
    endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos_minio:9000',
    access_key_id: 'minioadmin',
    secret_access_key: 'minioadmin',
    force_path_style: true,
    region: 'us-east-1'
  )

  def upload
    if params[:config] || params[:target]
      data = params[:config] ? params[:config] : params[:target]
      if data.content_type.include?("zip")
        rubys3_client = Aws::S3::Client.new
        # Data is an ActionDispatch::Http:UploadedFile which basically acts like a file
        # so we can pass it directly to Zip::File.open to read the zip contents
        Zip::File.open(data) do |zipfile|
          zipfile.each do |entry|
            next if entry.directory?
            path = entry.name
            # Check for a full config upload
            if path.include?("config/targets/")
              path = path.split("config/targets/")[-1]
            end
            rubys3_client.put_object(bucket: 'targets', key: path, body: entry.get_input_stream.read)
          end
        end
      else
        head :unsupported_media_type # 415
      end
    else
      head :not_found # 404
    end
  end
end
