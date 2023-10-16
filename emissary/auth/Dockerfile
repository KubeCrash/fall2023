FROM node:18.15.0-alpine3.16

MAINTAINER Ambassador Labs <dev@getambassador.io>
LABEL PROJECT_REPO_URL         = "git@github.com:kubecrash/fall2023.git" \
      PROJECT_REPO_BROWSER_URL = "https://github.com/kubecrash/fall2023" \
      DESCRIPTION              = "Example auth service for Emissary-Ingress" \
      VENDOR                   = "Ambassador Labs" \
      VENDOR_URL               = "https://getambassador.io/"

WORKDIR /src
ADD . .
RUN npm install

EXPOSE 3000
CMD ["npm", "start"]