require 'aws-sdk-s3'

Aws.config.update(
  endpoint: ENV['COSMOS_S3_URL'] || (ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9000' : 'http://cosmos-minio:9000'),
  access_key_id: ENV['COSMOS_MINIO_USERNAME'],
  secret_access_key: ENV['COSMOS_MINIO_PASSWORD'],
  force_path_style: true,
  region: 'us-east-1'
)
