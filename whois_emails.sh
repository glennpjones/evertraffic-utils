# iterate over *.zip, store *NAME
# unzip into *DIR
# collect all emails within the zip
# 	csv to json
# 	select domain_name,registrant_name,registrant_email,name_server_1 fields
# 	skip row if registrant_email is blank
# 	skip row if domain is not parked
# 	output to csv
# mv found emails into parked_emails/zip_name.csv
# rm all files in the *DIR

mkdir parked_emails
for zip in *.zip ; do
		mkdir csv/;
		echo "unzipping $zip";
		unzip $zip -d csv/;
		outfile="parked_emails/${zip/.zip/.csv}";
		#echo $outfile
		for f in csv/*.csv ; do mlr --c2j --jlistwrap cut -f domain_name,registrant_name,registrant_email,name_server_1 $f | jq '.[] | select(.registrant_email != "") | select(.name_server_1 | IN("dns1.parking-page.net", "ns.above.net", "ns01.cashparking.com", "ns1.above.com", "ns1.bodis.com", "ns1.fastpark.net", "ns1.parked.com", "ns1.parkeddns.com", "ns1.parkingcrew.com", "ns1.parkingcrew.net", "ns1.parklogic.com", "ns1.rookdns.com", "ns1.sedoparking.com", "ns1.voodoo.com", "ns15.above.com", "ns3.above.com"))' | mlr --j2c unsparsify >> $outfile; done;
		echo "emails extracted from $zip, removing unzipped directory";
		rm -rf csv/;
done


