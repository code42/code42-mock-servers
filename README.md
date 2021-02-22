# Mock Microservice Endpoints

***Warning: This repo is for internal Code42 use and may change or cease to exist at any time.***

To start the servers:

```bash
make
```

To stop the servers:
```bash
make stop
```

## Adding a new service

Since we are currently controlling the OpenAPI documentation that powers the mock server,
the format we are using is OpenAPI version 3 as yml.

You can convert existing JSON Swagger v2 swagger using https://editor.swagger.io/.

Some minor editing might be required to get the conversion to work. For example, warnings may appears on the left
margin of the Swagger editor. Address all the warnings before re-attempting the conversion.
A common problem from our docs is that the conversion tool does not like having `descriptions`
(or any additional properties) next a `ref`.

For example, replace:

```yml
            description: Indicates setting of how to interact with user list.
            $ref: '#/definitions/UsersToAlertOn-alert-rules'
```

with just:

```yml
            $ref: '#/definitions/UsersToAlertOn-alert-rules'
```

You may also have issues with enum values. See the section below.

## Endpoint Enums

Another common problem is that our Code42 docs often declare enums as having a type of `integer`.
This will cause failures in Prism. Change the enum type to `string`. This is also needed for the conversion
to OpenAPI 3 to work properly.

Prism is case-sensitive when it comes to enum values whereas typically Code42 servers are not.
To allow case-insensitivity, convert the request enum to use a Pattern.

Let's say you have an OpenAPI yml file containing this enum:

```yml
      enum:
      - HIGH
      - MEDIUM
      - LOW
      x-enumNames:
      - Low
      - Medium
      - High
```

To use a Pattern instead, replace it with:

```yml
        pattern: '^(?i)LOW|MEDIUM|HIGH$'
```

Now, all casings are supported in the mock.  `Low`, `low`, `LOW`, etc, are all valid.

## Examples

We have to often control the output of the mocked endpoints. To do this, set examples.

Convert

```yml
              archiveBytes:
                type: integer
                format: int64
```

to


```yml
              archiveBytes:
                type: integer
                format: int64
                example: 10000
```

It is not necessary to do this for every response property. Here are reasons you may need to:

* Prism complains about the type returned.  If ths happens, setting the example will control the output so Prism can't generate faulty
  examples by mistake.
* You are expecting a specific response value in a test.  This is how the Key-Value mock endpoints work: they return localhost with
  different ports (see section below).
* You want to constrain the response value. Prism likes to use negative integers when the type is an integer, but you might not want that,
  especially for IDs like the `userId`.

## docker-compose and the Mock Key-Value Store

Each microservice gets its own port that gets returned from the mock Key-Value Store found in `core.yml`. To add a new service, include
the mocked endpoint for getting your microservice's URL.

Example:

```yml
  /v1/KEY_VALUE_FOR_SERVICE_URL:
    get:
      tags:
      - keyvaluestore
      summary: Get the microservice URL
      operationId: ServiceNameUrl_Get
      responses:
        200:
          description: A successful response
          content:
            '*/*':
              schema:
               type: string
               example: http://127.0.0.1:4220
```

Then, in the `docker-compose.yml` file, add another entry using your service's mock `.yml` file and an incremented port (the same one you used in
the mock key-value store endpoint).

```yml
  service:
    image: c42/mock-microservice-endpoints:1.0
    build:
      context: .
      dockerfile: Dockerfile
    container_name: mock_service
    restart: always
    ports:
      - "4220:4220"
    command: mock docs/service.yml -p 4220 -h 0.0.0.0
```

Notice the port number appears in three places in the `yml` for the docker-compose file.

## Integration Tests and CI/CD

To successfully execute integration tests against the mock server in a CI/CD context, you must ensure that the `docker-compose up` command does not return before your mock microservice container is fully instantiated and ready to receive requests.

First, add a healthcheck endpoint to your OpenAPI yml file:
```yml
  /:
    get:
      summary: Check the health of the mock microservice container
      responses:
        200:
          description: A successful response
          content:
            text/plain:
              example: healthcheck-success
```

Then, in `docker-compose.yml`, add a `healthcheck` configuration section to your service definition. Be sure to modify the port to match the port exposed by your mock microservice container.
```yml
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:4200 || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
```

Finally, add a service dependency to the `health_checker` service at the bottom of `docker-compose.yml` so that the `docker-compose up` command will not return until your container is fully instantiated and responding to HTTP requests:
```yml
    depends_on:
      core:
        condition: service_healthy
```

## Returning empty JSON responses

If your endpoint claims to return application/json but you are returning an empty response,
you might have your service's yml (after conversion from JSON) looking like this:

```yml
        200:
          description: 'Success: Given alerts are updated to the indicated status.'
          content: {}
```

Instead, to return an empty response in a way that Prism understands, do this:

```yml
        200:
          description: 'Success: Given alerts are updated to the indicated status.'
          content:
            application/json:
              schema:
                type: object
```

## Optional Request Parameters

If you don't explitly mark your required request parameters, Prism assumes they are all required.
