#!/bin/bash
#
# Use it like so:
# for zipfile in complete_whois_database_*.zip; do echo "Processing $zipfile"; ./import_whois.sh "$zipfile"; done

if [ $# -eq 0 ]; then
    echo "Usage: $0 <zipfile>"
    echo "Example: $0 complete_whois_database_10_soi6w0o0ne.zip"
    exit 1
fi

zipfile="$1"

if [ ! -f "$zipfile" ]; then
    echo "Error: File $zipfile not found"
    exit 1
fi

# Function to import a single CSV file into staging
import_csv_to_staging() {
    local csv_file=$1
    echo "Importing $csv_file to staging table..."
    dokku postgres:connect whois << EOF
\copy domain_records_staging FROM '/tmp/$csv_file' WITH (FORMAT csv, HEADER true);
EOF
}

# Function to cast staging data to final table
cast_staging_to_final() {
    echo "Casting staging data to final table..."
    dokku postgres:connect whois << EOF
INSERT INTO domain_records
SELECT
    NULLIF(num, '')::integer as num,
    domain_name,
    NULLIF(query_time, '')::timestamp as query_time,
    CASE
        WHEN NULLIF(create_date, '') ~ '^0000-' THEN NULL
        WHEN NULLIF(create_date, '') ~ '^([0-9]{4})-00-00$'
        THEN (substring(create_date from 1 for 4) || '-01-01')::date
        WHEN NULLIF(create_date, '') ~ '^([0-9]{4})-00-([0-9]{2})$'
        THEN (substring(create_date from 1 for 4) || '-01-' || substring(create_date from 9 for 2))::date
        WHEN NULLIF(create_date, '') ~ '^([0-9]{4})-([0-9]{2})-00$'
        THEN (substring(create_date from 1 for 7) || '-01')::date
        WHEN NULLIF(create_date, '') IS NOT NULL
        THEN NULLIF(create_date, '')::date
        ELSE NULL
    END as create_date,
    CASE
        WHEN NULLIF(update_date, '') ~ '^0000-' THEN NULL
        WHEN NULLIF(update_date, '') ~ '^([0-9]{4})-00-00$'
        THEN (substring(update_date from 1 for 4) || '-01-01')::date
        WHEN NULLIF(update_date, '') ~ '^([0-9]{4})-00-([0-9]{2})$'
        THEN (substring(update_date from 1 for 4) || '-01-' || substring(update_date from 9 for 2))::date
        WHEN NULLIF(update_date, '') ~ '^([0-9]{4})-([0-9]{2})-00$'
        THEN (substring(update_date from 1 for 7) || '-01')::date
        WHEN NULLIF(update_date, '') IS NOT NULL
        THEN NULLIF(update_date, '')::date
        ELSE NULL
    END as update_date,
    CASE
        WHEN NULLIF(expiry_date, '') ~ '^0000-' THEN NULL
        WHEN NULLIF(expiry_date, '') ~ '^([0-9]{4})-00-00$'
        THEN (substring(expiry_date from 1 for 4) || '-01-01')::date
        WHEN NULLIF(expiry_date, '') ~ '^([0-9]{4})-00-([0-9]{2})$'
        THEN (substring(expiry_date from 1 for 4) || '-01-' || substring(expiry_date from 9 for 2))::date
        WHEN NULLIF(expiry_date, '') ~ '^([0-9]{4})-([0-9]{2})-00$'
        THEN (substring(expiry_date from 1 for 7) || '-01')::date
        WHEN NULLIF(expiry_date, '') IS NOT NULL
        THEN NULLIF(expiry_date, '')::date
        ELSE NULL
    END as expiry_date,
    NULLIF(domain_registrar_id, '')::integer as domain_registrar_id,
    domain_registrar_name,
    domain_registrar_whois,
    domain_registrar_url,
    registrant_name,
    registrant_company,
    registrant_address,
    registrant_city,
    registrant_state,
    registrant_zip,
    registrant_country,
    registrant_email,
    registrant_phone,
    registrant_fax,
    administrative_name,
    administrative_company,
    administrative_address,
    administrative_city,
    administrative_state,
    administrative_zip,
    administrative_country,
    administrative_email,
    administrative_phone,
    administrative_fax,
    technical_name,
    technical_company,
    technical_address,
    technical_city,
    technical_state,
    technical_zip,
    technical_country,
    technical_email,
    technical_phone,
    technical_fax,
    billing_name,
    billing_company,
    billing_address,
    billing_city,
    billing_state,
    billing_zip,
    billing_country,
    billing_email,
    billing_phone,
    billing_fax,
    name_server_1,
    name_server_2,
    name_server_3,
    name_server_4,
    domain_status_1,
    domain_status_2,
    domain_status_3,
    domain_status_4
FROM domain_records_staging;

TRUNCATE domain_records_staging;
EOF
}

echo "Processing $zipfile..."

# Create temporary directory
temp_dir=$(mktemp -d)
echo "Created temporary directory: $temp_dir"

# Unzip file into temporary directory
unzip "$zipfile" -d "$temp_dir"

# Clean up existing CSV files in Docker container
docker exec dokku.postgres.whois rm -f /tmp/*.csv

# Copy each CSV to Docker container
for csv_file in "$temp_dir"/*.csv; do
    filename=$(basename "$csv_file")
    echo "Copying $filename to Docker container..."
    docker cp "$csv_file" dokku.postgres.whois:/tmp/"$filename"
done

# Clear staging table
echo "Clearing staging table..."
dokku postgres:connect whois << EOF
TRUNCATE domain_records_staging;
EOF

# Import each CSV to staging table
for csv_file in "$temp_dir"/*.csv; do
    filename=$(basename "$csv_file")
    import_csv_to_staging "$filename"
done

# Cast staging data to final table
cast_staging_to_final

# Clean up temporary directory
echo "Cleaning up temporary directory..."
rm -rf "$temp_dir"

echo "Finished processing $zipfile"
echo "----------------------------"
