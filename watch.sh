wanted="$1"

all_ready=

while [ -z "$all_ready" ]; do
   sleep 2
   all_ready=yes

   for ctx in us-east us-west eu-central; do
      count=$(kubectl --context $ctx get pods -n cockroachdb | egrep -c " [^${wanted}]/2")

      echo "$ctx: $count"

      if [ $count -ne 0 ]; then
         all_ready=
         break
      fi
   done
done
