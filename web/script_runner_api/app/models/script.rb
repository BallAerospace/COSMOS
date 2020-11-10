require 'aws-sdk-s3'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos-minio:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

class Script
  DEFAULT_BUCKET_NAME = 'targets'

  def self.all(bucket = nil)
    bucket ||= DEFAULT_BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: bucket)
    result = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        result << object[:key] if object[:key].include?("procedures") || object[:key].include?("lib")
      end
    end
    result.sort
  end

  def self.find(name, bucket = nil)
    bucket ||= DEFAULT_BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.get_object(bucket: bucket, key: name)
    return {"name" => "test.rb"}
  end

  def self.body(name, bucket = nil)
    bucket ||= DEFAULT_BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.get_object(bucket: bucket, key: name)
    resp.body.read
  end

  def self.create(name, bucket = nil, text = nil)
    return false unless text
    bucket ||= DEFAULT_BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    rubys3_client.put_object(
      key: name,
      body: text,
      bucket: bucket,
      content_type: 'text/plain')
    true
  end

  def self.destroy(name, bucket = nil)
    bucket ||= DEFAULT_BUCKET_NAME
    rubys3_client = Aws::S3::Client.new
    rubys3_client.delete_object(key: name, bucket: bucket)
    true
  end

  def self.run(name, bucket = nil, disconnect = false)
    bucket ||= DEFAULT_BUCKET_NAME
    RunningScript.spawn(name, bucket, disconnect)
  end

  def self.syntax(text)
    check_process = IO.popen("ruby -c -rubygems 2>&1", 'r+')
    check_process.write("require 'cosmos'; require 'cosmos/script'; " + text)
    check_process.close_write
    results = check_process.readlines
    check_process.close
    if results
      if results.any?(/Syntax OK/)
        return { "title" => "Syntax Check Successful", "description" => results.to_json }
      else
        # Results is an array of strings like this: ":2: syntax error ..."
        # Normally the procedure comes before the first colon but since we
        # are writing to the process this is blank so we throw it away
        results.map! {|result| result.split(':')[1..-1].join(':')}
        return { "title" => "Syntax Check Failed", "description" => results.to_json }
      end
    else
      return { "title" => "Syntax Check Exception", "description" => "Ruby syntax check unexpectedly returned nil" }
    end
  end
end
