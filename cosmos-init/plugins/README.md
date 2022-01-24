# Developing COSMOS Frontend Applications

NOTE: All commands are assumed to be executed from this (cosmos-init) directory

1.  Bootstrap the frontend with yarn

        cosmos-init> yarn

1.  Start cosmos

        cosmos-init> cd ..
        COSMOS> cosmos_control.bat dev

1.  Serve a local COSMOS application (CmdTlmServer, ScriptRunner, etc)

        cosmos-init> cd plugins/packages/cosmosc2-tool-scriptrunner
        cosmosc2-tool-scriptrunner> yarn serve

1.  Set the single SPA override for the application

    Visit localhost:2900 and Right-click 'Inspect'<br>
    In the console paste:

        localStorage.setItem('devtools', true)

    Refresh and you should see {...} in the bottom right<br>
    Click the Default button next to the application (@cosmosc2/tool-scriptrunner)<br>
    Paste in the development path which is dependent on the port returned by the local yarn serve and the tool name (scriptrunner)

        http://localhost:2914/tools/scriptrunner/js/app.js

# Developing COSMOS Base Application

1.  Run a development version of traefik

        cosmos-init> cd ../cosmos-traefik
        traefik> docker ps
        # Look for the container with name including traefik
        traefik> docker stop cosmos_cosmos-traefik_1
        traefik> docker build -f Dockerfile-dev-base -t cosmos-traefik-dev-base .
        traefik> docker run --network=cosmos_default -p 2900:80 -it --rm cosmos-traefik-dev-base

1.  Serve a local base application (App, Auth, AppBar, AppFooter, etc)

        cosmos-init> cd plugins/cosmosc2-tool-base
        cosmosc2-tool-base> yarn serve

# API development

1.  Run a development version of traefik

        cosmos-init> cd ../cosmos-traefik
        traefik> docker ps
        # Look for the container with name including traefik
        traefik> docker stop cosmos_cosmos-traefik_1
        traefik> docker build -f Dockerfile-dev -t cosmos-traefik-dev .
        traefik> docker run --network=cosmos_default -p 2900:80 -it --rm cosmos-traefik-dev

1.  Run a local copy of the CmdTlm API or Script API

        cosmos-init> cd ../cosmos-cmd-tlm-api
        cosmos-cmd-tlm-api> docker ps
        # Look for the container with name including cmd-tlm-api
        cosmos-cmd-tlm-api> docker stop cosmos_cosmos-cmd-tlm-api_1
        # Set all the environment variables in the .env file
        # except set COSMOS_REDIS_HOSTNAME=127.0.0.1
        # Set RUBYGEMS_URL=https://rubygems.org
        cosmos-cmd-tlm-api> bundle install
        cosmos-cmd-tlm-api> bundle exec rails s

# MINIO development

Note running COSMOS in development mode (cosmos-control.bat dev) already does this step. This is only necessary to debug a minio container running in production mode.

1.  Run a development version of minio

        > docker ps
        # Look for the container with name including minio
        > docker stop cosmos_cosmos-minio_1
        > docker run --name cosmos_cosmos-minio_1 --network=cosmos_default -v cosmos_cosmos-minio-v:/data -p 9000:9000 -e "MINIO_ROOT_USER=cosmosminio" -e "MINIO_ROOT_PASSWORD=cosmosminiopassword" minio/minio:RELEASE.2021-06-17T00-10-46Z server /data

