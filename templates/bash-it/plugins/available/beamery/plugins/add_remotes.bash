#!/usr/bin/env bash

# Load the main plugins "interface"
source "${HOME}/.bash_it/plugins/available/beamery/pluginsInterface.bash"

# Add the appropriate environment remotes for appropriate repos
#
#   preview:dokku@preview.beamery.com:{CONTAINER}
#   deis:ssh://git@deis.beamery.com:2222/{CONTAINER}
#
# This will be done for the following (where the name is [repository name]:[docker container name]):
#
#   app_portal:portal_app
#   api_mail:mail
#   api_portal:portal
#   app_admin:admin
#   app_application:app
#   app_site:site
#   api_notifications:notify
#   service_queue:queue
#   api_core:api

add_remotes() {

    for app in "${applications[@]}"; do
        set -- "${app}"
        IFS=":"; declare -a Array=($*)
        printf "Remote will be: ${magenta}ssh://git@deis.beamery.com:2222/${Array[1]}.git${NC}";
        echo "";
        if [ "${Array[0]}" == "app-site" ]; then
            (cd "${Array}" ; git remote add deis "ssh://git@deis.beamery.com:2222/${Array[1]}.git" ; git remote add preview "dokku@preview.beamery.com:preview.beamery.com");
        else
            (cd "${Array}" ; git remote add deis "ssh://git@deis.beamery.com:2222/${Array[1]}.git"; git remote add preview "dokku@preview.beamery.com:"${Array[1]});
        fi
        echo "";
    done

    applications=(
      app-portal:portal-app
      api-mail:mail
      api-portal:portal
      app-admin:admin
      app-application:app
      app-site:site
      api-notifications:notify
      service-queue:queue
      api-core:api
    )
}