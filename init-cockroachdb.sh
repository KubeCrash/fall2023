kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- /cockroach/cockroach init \
      --certs-dir=/cockroach/cockroach-certs

kubectl cp \
   --context eu-central \
   -n cockroachdb -c cockroachdb\
   the-world/server/create-free.sql cockroachdb-0:/tmp/create-free.sql

CDSQL='cockroach sql --url "postgres://root@localhost:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-certs/ca.crt&sslcert=/cockroach/cockroach-certs/client.root.crt&sslkey=/cockroach/cockroach-certs/client.root.key"'

kubectl exec \
   --context eu-central \
   -it cockroachdb-0 -c cockroachdb \
   --namespace cockroachdb \
   -- bash -c "$CDSQL < /tmp/create-free.sql"
