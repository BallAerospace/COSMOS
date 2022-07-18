# Developing OpenC3 Frontend Applications

NOTE: All commands are assumed to be executed from this (openc3-init) directory

1.  Bootstrap the frontend with yarn

        openc3-init> yarn

1.  Start openc3

        openc3-init> cd ..
        openc3> openc3.bat dev

1.  Serve a local OpenC3 application (CmdTlmServer, ScriptRunner, etc)

        openc3-init> cd plugins/packages/openc3-tool-scriptrunner
        openc3-tool-scriptrunner> yarn
        ...
        openc3-tool-scriptrunner> yarn serve

1.  Set the single SPA override for the application

    Visit localhost:2900 and Right-click 'Inspect'<br>
    In the console paste:

        localStorage.setItem('devtools', true)

    Refresh and you should see {...} in the bottom right<br>
    Click the Default button next to the application (@openc3/tool-scriptrunner)<br>
    Paste in the development path which is dependent on the port returned by the local yarn serve and the tool name (scriptrunner)

        http://localhost:2914/tools/scriptrunner/js/app.js

# Developing OpenC3 Base Application

1.  Run a development version of traefik

        openc3-init> cd ../openc3-traefik
        traefik> docker ps
        # Look for the container with name including traefik
        traefik> docker stop openc3_openc3-traefik_1
        traefik> docker build -f Dockerfile-dev-base -t openc3-traefik-dev-base .
        traefik> docker run --network=openc3_default -p 2900:80 -it --rm openc3-traefik-dev-base

1.  Serve a local base application (App, Auth, AppBar, AppFooter, etc)

        openc3-init> cd plugins/openc3-tool-base
        openc3-tool-base> yarn serve

# API development

1.  Run a development version of traefik

        openc3-init> cd ../openc3-traefik
        traefik> docker ps
        # Look for the container with name including traefik
        traefik> docker stop openc3_openc3-traefik_1
        traefik> docker build -f Dockerfile-dev -t openc3-traefik-dev .
        traefik> docker run --network=openc3_default -p 2900:80 -it --rm openc3-traefik-dev

1.  Run a local copy of the CmdTlm API or Script API

        openc3-init> cd ../openc3-cmd-tlm-api
        openc3-cmd-tlm-api> docker ps
        # Look for the container with name including cmd-tlm-api
        openc3-cmd-tlm-api> docker stop openc3_openc3-cmd-tlm-api_1
        openc3-cmd-tlm-api> dev_server.bat

# MINIO development

Note running OpenC3 in development mode (openc3.bat dev) already does this step. This is only necessary to debug a minio container running in production mode.

1.  Run a development version of minio

        > docker ps
        # Look for the container with name including minio
        > docker stop openc3_openc3-minio_1
        > docker run --name openc3_openc3-minio_1 --network=openc3_default -v openc3_openc3-minio-v:/data -p 9000:9000 -e "MINIO_ROOT_USER=openc3minio" -e "MINIO_ROOT_PASSWORD=openc3miniopassword" minio/minio:RELEASE.2021-06-17T00-10-46Z server /data

