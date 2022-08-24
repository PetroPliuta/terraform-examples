[
    {
        "name": "ghost_container",
        "image": "${ECR_IMAGE}",
        "essential": true,
        "environment": [
            { "name" : "database__client", "value" : "mysql"},
            { "name" : "database__connection__host", "value" : "${DB_URL}"},
            { "name" : "database__connection__user", "value" : "${DB_USER}"},
            { "name" : "database__connection__password", "value" : "${DB_PASS}"},
            { "name" : "database__connection__database", "value" : "${DB_NAME}"}
        ],
        "mountPoints": [
            {
                "containerPath": "${CONTAINER_PATH}",
                "sourceVolume": "ghost_volume"
            }
        ],
        "portMappings": [
            {
            "containerPort": 2368,
            "hostPort": 2368
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options":{
                "awslogs-create-group": "true",
                "awslogs-group": "${awslogs_group}",
                "awslogs-region": "${awslogs_region}",
                "awslogs-stream-prefix" : "prefix"
            }
        }
    }
] 
