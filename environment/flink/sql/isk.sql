-- Streambased ISK (directstream) catalog (same as Spark's "isk" catalog), exposing the hotset/merged namespaces.
-- Credentials come from AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY (sbpk_/sbsk_ keys) in the container env.
CREATE CATALOG isk WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'http://directstream:11001',
  'warehouse' = 's3://',
  'rest.sigv4-enabled' = 'true',
  'rest.signing-region' = 'us-east-1',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://directstream:11000',
  's3.path-style-access' = 'true',
  'client.region' = 'us-east-1',
  'cache.expiration-interval-ms' = '10000'
);
