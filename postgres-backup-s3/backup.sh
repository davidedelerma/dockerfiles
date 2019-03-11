#! /bin/sh

set -e
set -o pipefail

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
fi


if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION

export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER $POSTGRES_EXTRA_OPTS"
echo $POSTGRES_HOST_OPTS

echo "Creating dump of geogig_dev database from ${POSTGRES_HOST}..."

pg_dump $POSTGRES_HOST_OPTS geogig_dev | gzip > geogig_dev.sql.gz

echo "Creating dump of geogig_rooms_test database from ${POSTGRES_HOST}..."

pg_dump $POSTGRES_HOST_OPTS geogig_rooms_test | gzip > geogig_rooms_test.sql.gz

echo "Creating dump of room_validation database from ${POSTGRES_HOST}..."

pg_dump $POSTGRES_HOST_OPTS room_validation | gzip > room_validation.sql.gz

echo "Creating dump of test_db database from ${POSTGRES_HOST}..."

pg_dump $POSTGRES_HOST_OPTS test_db | gzip > test_db.sql.gz

echo "Creating dump of venue_maps_data from ${POSTGRES_HOST}..."

pg_dump $POSTGRES_HOST_OPTS venue_maps_data | gzip > venue_maps_data.sql.gz

echo "copy all database in backup folder"
mkdir backup
cp *.sql.gz ./backup
rm -rf *.sql.gz
tar -cvf postgis_backup.tar backup
rm -rf backup

echo "Uploading dump to $S3_BUCKET"
old=$(aws s3 ls s3://geoserver-postgis-stage | wc -l)
aws $AWS_ARGS s3 cp postgis_backup.tar s3://$S3_BUCKET/postgis_backup_$(date +"%Y-%m-%dT%H:%M:%SZ").tar || exit 2
new=$(aws s3 ls s3://geoserver-postgis-stage | wc -l)
rm -rf postgis_backup.tar

if [ $(($old+1)) == $new ]
then
  echo "postgis backup uploaded successfully"
else
  echo "failed to upload postgis backup"
fi