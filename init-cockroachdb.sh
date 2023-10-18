kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- /cockroach/cockroach init \
      --certs-dir=/cockroach/cockroach-certs

SCRIPT=$(pwd)/the-world/server/create-free.sql $SHELL do-sql.sh
