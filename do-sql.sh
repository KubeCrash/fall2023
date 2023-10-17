if [ -z "$CONTEXT" ]; then
    CONTEXT=eu-central  # Why eu-central? Meh, whatever.
fi

CDSQL='cockroach sql --url "postgres://root@localhost:26257/defaultdb?sslmode=verify-full&sslrootcert=/cockroach/cockroach-certs/ca.crt&sslcert=/cockroach/cockroach-certs/client.root.crt&sslkey=/cockroach/cockroach-certs/client.root.key"'

if [ -n "$SCRIPT" ]; then
    remote="/tmp/script-$$.sql"

    kubectl cp \
       --context $CONTEXT \
       -n cockroachdb -c cockroachdb\
       "$SCRIPT" cockroachdb-0:$remote

    kubectl exec \
       --context $CONTEXT \
       -it cockroachdb-0 -c cockroachdb \
       --namespace cockroachdb \
       -- bash -c "$CDSQL < $remote"
else
    kubectl exec \
       --context $CONTEXT \
       -it cockroachdb-0 -c cockroachdb \
       --namespace cockroachdb \
       -- bash -c "$CDSQL"
fi
