if [ -z "$REGION" ]; then
    REGION=NYC1
fi

echo "Creating us-east"...
civo k8s create us-east \
     -y --region=$REGION --save --merge \
     --remove-applications Traefik-v2-nodeport --wait

echo "Creating us-west"...
civo k8s create us-west \
     -y --region=$REGION --save --merge \
     --remove-applications Traefik-v2-nodeport --wait

echo "Creating eu-central"...
civo k8s create eu-central \
     -y --region=$REGION --save --merge \
     --remove-applications Traefik-v2-nodeport --wait
