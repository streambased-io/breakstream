-- Iceberg REST catalog backed by MinIO (same as Spark's "direct" catalog), coldset lives in namespace "coldset"
CREATE CATALOG direct WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'http://rest:8181',
  'warehouse' = 's3://warehouse/wh/',
  'rest.sigv4-enabled' = 'true',
  'rest.signing-region' = 'us-east-1',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://minio:9000',
  's3.path-style-access' = 'true',
  's3.access-key-id' = 'admin',
  's3.secret-access-key' = 'password',
  'client.region' = 'us-east-1'
);
