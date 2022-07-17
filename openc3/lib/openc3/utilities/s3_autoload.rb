require 'aws-sdk-s3'

Aws.config.update(
  endpoint: ENV['OPENC3_S3_URL'] || (ENV['OPENC3_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://openc3-minio:9000'),
  access_key_id: ENV['OPENC3_MINIO_USERNAME'],
  secret_access_key: ENV['OPENC3_MINIO_PASSWORD'],
  force_path_style: true,
  region: 'us-east-1'
)
