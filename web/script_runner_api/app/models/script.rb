require 'aws-sdk-s3'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos-minio:9000',
  access_key_id: 'minioadmin',
  secret_access_key: 'minioadmin',
  force_path_style: true,
  region: 'us-east-1'
)

class Script
  DEFAULT_BUCKET_NAME = 'config'

  def self.all(scope)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.list_objects_v2(bucket: DEFAULT_BUCKET_NAME)
    result = []
    contents = resp.to_h[:contents]
    if contents
      contents.each do |object|
        next unless object[:key].include?("#{scope}/targets")
        if object[:key].include?("procedures") || object[:key].include?("lib")
          result << object[:key].split('/')[2..-1].join('/')
        end
      end
    end
    result.sort
  end

  # def self.find(scope, name)
  #   rubys3_client = Aws::S3::Client.new
  #   resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: name)
  #   return {"name" => "test.rb"}
  # end

  def self.body(scope, name)
    rubys3_client = Aws::S3::Client.new
    resp = rubys3_client.get_object(bucket: DEFAULT_BUCKET_NAME, key: "#{scope}/targets/#{name}")
    resp.body.read
  end

  def self.create(scope, name, text = nil)
    return false unless text
    rubys3_client = Aws::S3::Client.new
    rubys3_client.put_object(
      key: "#{scope}/targets/#{name}",
      body: text,
      bucket: DEFAULT_BUCKET_NAME,
      content_type: 'text/plain')
    true
  end

  def self.destroy(scope, name)
    rubys3_client = Aws::S3::Client.new
    rubys3_client.delete_object(key: "#{scope}/targets/#{name}", bucket: DEFAULT_BUCKET_NAME)
    true
  end

  def self.run(scope, name, disconnect = false)
    RunningScript.spawn(scope, name, disconnect)
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
